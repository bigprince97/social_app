import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const firebaseProjectId = Deno.env.get('FIREBASE_PROJECT_ID')!
const firebaseServiceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')!)

const b64url = (data: Uint8Array): string =>
  btoa(String.fromCharCode(...data))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')

async function getAccessToken(): Promise<string> {
  const enc = new TextEncoder()
  const now = Math.floor(Date.now() / 1000)

  const header = b64url(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })))
  const claim = b64url(
    enc.encode(
      JSON.stringify({
        iss: firebaseServiceAccount.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
      })
    )
  )
  const sigInput = `${header}.${claim}`

  const pem = firebaseServiceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0))

  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(sigInput))
  const jwt = `${sigInput}.${b64url(new Uint8Array(sig))}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  const data = await res.json()
  return data.access_token
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  try {
    const { notification_id } = await req.json()
    if (!notification_id) {
      return new Response('Missing notification_id', { status: 400 })
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { data: notif, error: notifErr } = await supabase
      .from('notifications')
      .select('*, profiles!actor_id(display_name)')
      .eq('id', notification_id)
      .single()

    if (notifErr || !notif) {
      return new Response('Notification not found', { status: 404 })
    }

    const { data: blockRows } = await supabase
      .from('blocks')
      .select('blocker_id, blocked_id')
      .or(
        `and(blocker_id.eq.${notif.user_id},blocked_id.eq.${notif.actor_id}),` +
          `and(blocker_id.eq.${notif.actor_id},blocked_id.eq.${notif.user_id})`
      )

    if ((blockRows ?? []).length > 0) {
      return new Response(JSON.stringify({ skipped: 'blocked' }), { status: 200 })
    }

    const { data: tokens } = await supabase
      .from('push_tokens')
      .select('token')
      .eq('user_id', notif.user_id)

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ skipped: 'no tokens' }), { status: 200 })
    }

    const accessToken = await getAccessToken()
    const actorName: string = (notif.profiles as any)?.display_name ?? '有人'

    const notifMessages: Record<string, string> = {
      like: `${actorName} 点赞了你的帖子`,
      comment: `${actorName} 评论了你的帖子`,
      follow: `${actorName} 关注了你`,
      friend_request: `${actorName} 请求加你为好友`,
      friend_accept: `${actorName} 通过了你的好友申请`,
    }
    const body = notifMessages[notif.type] ?? '你有一条新通知'

    const results = await Promise.allSettled(
      tokens.map(({ token }: { token: string }) =>
        fetch(
          `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title: '新通知', body },
                data: {
                  notification_id: notif.id,
                  type: notif.type,
                  post_id: notif.post_id ?? '',
                  actor_id: notif.actor_id,
                },
                apns: {
                  payload: { aps: { sound: 'default' } },
                },
                android: {
                  notification: { sound: 'default', channel_id: 'default' },
                },
              },
            }),
          }
        )
      )
    )

    const sent = results.filter((r) => r.status === 'fulfilled').length
    return new Response(JSON.stringify({ sent, total: tokens.length }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error(e)
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 })
  }
})
