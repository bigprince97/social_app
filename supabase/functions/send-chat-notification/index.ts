import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const firebaseProjectId =
  Deno.env.get("FIREBASE_PROJECT_ID") ?? "omega-6c05a";
const firebaseServiceAccount = JSON.parse(
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY") ?? "{}",
);

const b64url = (data: Uint8Array): string =>
  btoa(String.fromCharCode(...data))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

async function getAccessToken(): Promise<string> {
  const enc = new TextEncoder();
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(enc.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claim = b64url(
    enc.encode(
      JSON.stringify({
        iss: firebaseServiceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      }),
    ),
  );
  const sigInput = `${header}.${claim}`;
  const pem = (firebaseServiceAccount.private_key as string)
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    enc.encode(sigInput),
  );
  const jwt = `${sigInput}.${b64url(new Uint8Array(sig))}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  if (!data.access_token) throw new Error("no access_token: " + JSON.stringify(data));
  return data.access_token;
}

Deno.serve(async (req: Request) => {
  try {
    const payload = await req.json();
    const record = payload.record;
    if (!record || record.is_deleted) return new Response("ok", { status: 200 });

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: members } = await supabase
      .from("conversation_members")
      .select("user_id")
      .eq("conversation_id", record.conversation_id)
      .neq("user_id", record.sender_id);
    if (!members || members.length === 0) return new Response("ok", { status: 200 });

    const memberIds = members.map((m: { user_id: string }) => m.user_id);
    const { data: blocks } = await supabase
      .from("blocks")
      .select("blocker_id, blocked_id")
      .or(
        `and(blocker_id.eq.${record.sender_id},blocked_id.in.(${memberIds.join(",")})),` +
          `and(blocker_id.in.(${memberIds.join(",")}),blocked_id.eq.${record.sender_id})`,
      );
    const blockedRecipientIds = new Set<string>();
    for (const block of blocks ?? []) {
      if (block.blocker_id === record.sender_id) blockedRecipientIds.add(block.blocked_id);
      if (block.blocked_id === record.sender_id) blockedRecipientIds.add(block.blocker_id);
    }

    const { data: sender } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", record.sender_id)
      .single();
    const senderName = sender?.display_name ?? "有人";

    let body = record.content ?? "";
    if (record.message_type === "image") body = "[图片]";
    else if (record.message_type === "audio") body = "[语音]";
    else if (record.message_type === "video") body = "[视频]";
    else if (record.message_type === "file") body = "[文件]";
    else if (record.message_type === "scripture") body = "[经文引用]";
    if (!body) body = "发来一条消息";

    // 区分私聊/群聊：群聊标题显示群名，正文带上发送者名
    const { data: conv } = await supabase
      .from("conversations")
      .select("type, name")
      .eq("id", record.conversation_id)
      .single();
    const isGroup = conv?.type === "group";
    const title = isGroup ? (conv?.name ?? "群聊") : senderName;
    if (isGroup) body = `${senderName}：${body}`;

    const recipientIds = memberIds.filter((id) => !blockedRecipientIds.has(id));
    if (recipientIds.length === 0) return new Response("ok", { status: 200 });
    const { data: tokens } = await supabase
      .from("push_tokens")
      .select("token, user_id")
      .in("user_id", recipientIds);
    if (!tokens || tokens.length === 0) return new Response("ok", { status: 200 });

    // 各接收者的未读数:折叠通知带「[N条]」前缀,微信风格,
    // 弥补同会话通知互相覆盖后看不出积压数量的问题
    const { data: memberRows } = await supabase
      .from("conversation_members")
      .select("user_id, last_read_at")
      .eq("conversation_id", record.conversation_id)
      .in("user_id", recipientIds);
    const lastReadMap = new Map(
      (memberRows ?? []).map((r: { user_id: string; last_read_at: string | null }) => [
        r.user_id,
        r.last_read_at,
      ]),
    );
    const unreadCounts = new Map<string, number>();
    await Promise.all(
      recipientIds.map(async (uid: string) => {
        try {
          let q = supabase
            .from("messages")
            .select("id", { count: "exact", head: true })
            .eq("conversation_id", record.conversation_id)
            .neq("sender_id", uid)
            .or("is_deleted.is.null,is_deleted.eq.false");
          const lr = lastReadMap.get(uid);
          if (lr) q = q.gt("created_at", lr);
          const { count } = await q;
          unreadCounts.set(uid, count ?? 1);
        } catch (_) {
          unreadCounts.set(uid, 1);
        }
      }),
    );

    if (!firebaseServiceAccount.client_email) {
      console.warn("FIREBASE_SERVICE_ACCOUNT_KEY not set");
      return new Response(JSON.stringify({ skipped: "no service account" }), { status: 200 });
    }

    const accessToken = await getAccessToken();

    const results = await Promise.allSettled(
      tokens.map(({ token, user_id }: { token: string; user_id: string }) => {
        const n = unreadCounts.get(user_id) ?? 1;
        const finalBody = n > 1 ? `[${n}条] ${body}` : body;
        return fetch(
          `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title, body: finalBody },
                data: {
                  type: "chat",
                  conversation_id: String(record.conversation_id),
                  sender_id: String(record.sender_id),
                  conversation_type: String(conv?.type ?? "direct"),
                },
                apns: {
                  // iOS 主流 IM 做法(微信/WhatsApp):逐条通知不覆盖,
                  // 用 thread-id 让系统按会话自动堆叠成一组,既不轰炸也不丢提示
                  payload: {
                    aps: {
                      sound: "default",
                      "thread-id": String(record.conversation_id),
                    },
                  },
                },
                android: {
                  priority: "high",
                  notification: {
                    sound: "default",
                    channel_id: "default",
                    // 同一会话的通知同 tag 互相覆盖,只保留最新一条
                    tag: String(record.conversation_id),
                  },
                },
              },
            }),
          },
        ).then(async (r) => {
          if (!r.ok) console.error("fcm fail", r.status, await r.text());
          return r;
        });
      }),
    );
    const sent = results.filter((r) => r.status === "fulfilled").length;
    return new Response(JSON.stringify({ sent, total: tokens.length }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
