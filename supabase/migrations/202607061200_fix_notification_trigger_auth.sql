-- 修复推送通知失效：触发器调用 Edge Function 时未带 Authorization 头，
-- 而 send-chat-notification / send-push-notification 部署为 verify_jwt=true，
-- 导致所有调用被 401 拒绝（send-call-notification 因 verify_jwt=false 幸免）。
-- 修复：http_post 带上 anon JWT（与 App 内置 key 相同，本就是公开的）。
-- 触发器仍保留 exception 兜底，通知失败不影响业务写入。

create or replace function public.notify_chat_message()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'INSERT' and not coalesce(new.is_deleted, false) then
    perform net.http_post(
      url := 'https://xywcjkxqgrrbwfcknetc.supabase.co/functions/v1/send-chat-notification',
      body := jsonb_build_object('record', row_to_json(new)),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5d2Nqa3hxZ3JyYndmY2tuZXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3NzIwMzcsImV4cCI6MjA5NjM0ODAzN30.l6IJq_T0p2KB_EUlIZhF_l_e6MA8LpvXUSVAPS_Fcxk'
      )
    );
  end if;
  return new;
exception when others then
  return new;
end;
$$;

create or replace function public.trigger_push_notification()
returns trigger
language plpgsql
security definer
as $$
begin
  perform net.http_post(
    url := 'https://xywcjkxqgrrbwfcknetc.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5d2Nqa3hxZ3JyYndmY2tuZXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3NzIwMzcsImV4cCI6MjA5NjM0ODAzN30.l6IJq_T0p2KB_EUlIZhF_l_e6MA8LpvXUSVAPS_Fcxk'
    ),
    body := jsonb_build_object('notification_id', new.id)::text
  );
  return new;
exception when others then
  return new;
end;
$$;

-- notify_incoming_call 对应的 send-call-notification 是 verify_jwt=false，
-- 本就能通，这里同样补上头以保持一致（未来若改回 verify_jwt=true 也不会坏）。
create or replace function public.notify_incoming_call()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'INSERT' and new.status = 'ringing' then
    perform net.http_post(
      url := 'https://xywcjkxqgrrbwfcknetc.supabase.co/functions/v1/send-call-notification',
      body := jsonb_build_object('record', row_to_json(new)),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5d2Nqa3hxZ3JyYndmY2tuZXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3NzIwMzcsImV4cCI6MjA5NjM0ODAzN30.l6IJq_T0p2KB_EUlIZhF_l_e6MA8LpvXUSVAPS_Fcxk'
      )
    );
  end if;
  return new;
exception when others then
  return new;
end;
$$;
