import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "omega-6c05a";
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
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(sigInput));
  const jwt = `${sigInput}.${b64url(new Uint8Array(sig))}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  if (!data.access_token) throw new Error("no access_token: " + JSON.stringify(data));
  return data.access_token;
}

Deno.serve(async (req: Request) => {
  try {
    const payload = await req.json();
    const record = payload.record;
    if (!record || record.status !== "ringing") {
      return new Response("ok", { status: 200 });
    }

    const ct = record.call_type ?? "voice";
    const isLivestream = ct === "livestream";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    let recipientIds: string[] = [];
    if (record.callee_id) {
      recipientIds = [record.callee_id];
    } else {
      const { data: members } = await supabase
        .from("conversation_members")
        .select("user_id")
        .eq("conversation_id", record.conversation_id)
        .neq("user_id", record.caller_id);
      recipientIds = (members ?? []).map((m: { user_id: string }) => m.user_id);
    }
    if (recipientIds.length === 0) return new Response("ok", { status: 200 });

    const { data: caller } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", record.caller_id)
      .single();
    const callerName = caller?.display_name ?? "有人";

    // 直播:标题=群名,正文=谁发起了直播;通话:标题=来电人
    let title = callerName;
    let body = ct === "video" ? "邀请你视频通话" : "邀请你语音通话";
    if (isLivestream) {
      const { data: conv } = await supabase
        .from("conversations")
        .select("name")
        .eq("id", record.conversation_id)
        .single();
      title = conv?.name ?? "群直播";
      body = `📺 ${callerName} 发起了直播，点击进入观看`;
    }

    const { data: tokens } = await supabase
      .from("push_tokens")
      .select("token")
      .in("user_id", recipientIds);
    if (!tokens || tokens.length === 0) return new Response("ok", { status: 200 });

    if (!firebaseServiceAccount.client_email) {
      return new Response(JSON.stringify({ skipped: "no service account" }), { status: 200 });
    }

    const accessToken = await getAccessToken();

    // 直播用 type=chat:点击通知直达群聊页(群内有直播横幅入口),
    // 无需客户端改动;通话保持 type=call 触发全屏来电页
    const dataPayload = isLivestream
      ? {
          type: "chat",
          conversation_id: String(record.conversation_id),
          sender_id: String(record.caller_id),
          conversation_type: "group",
        }
      : {
          type: "call",
          call_id: String(record.id),
          conversation_id: String(record.conversation_id),
          caller_id: String(record.caller_id),
          call_type: String(ct),
          livekit_room: String(record.livekit_room ?? ""),
        };

    const results = await Promise.allSettled(
      tokens.map(({ token }: { token: string }) =>
        fetch(
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
                notification: { title, body },
                data: dataPayload,
                apns: { payload: { aps: { sound: "default" } } },
                android: {
                  priority: "high",
                  notification: {
                    sound: "default",
                    channel_id: isLivestream ? "default" : "calls",
                  },
                },
              },
            }),
          },
        ).then(async (r) => {
          if (!r.ok) console.error("fcm fail", r.status, await r.text());
          return r;
        })
      ),
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
