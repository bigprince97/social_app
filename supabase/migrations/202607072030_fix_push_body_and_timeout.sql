-- 修复两个使社交推送(like/comment/follow/new_post)静默失败的问题:
-- 1) trigger_push_notification 的 body 误作 ::text 传给 net.http_post(需 jsonb),
--    函数解析失败被 exception 吞掉 —— 社交推送自上线起从未发出。
-- 2) pg_net 默认 5s 超时,edge function 冷启动(boot + Google OAuth)可能超过,
--    三个通知触发器统一 timeout_milliseconds := 10000。

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
    body := jsonb_build_object('notification_id', new.id),
    timeout_milliseconds := 10000
  );
  return new;
exception when others then
  return new;
end;
$$;

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
      ),
      timeout_milliseconds := 10000
    );
  end if;
  return new;
exception when others then
  return new;
end;
$$;

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
      ),
      timeout_milliseconds := 10000
    );
  end if;
  return new;
exception when others then
  return new;
end;
$$;
