-- 关注的人发新帖 → 通知所有粉丝
-- 1) notifications.type 约束扩充 'new_post'
-- 2) posts INSERT 触发器给每个粉丝写入一条 notification,
--    复用现有 on_notification_insert → send-push-notification 推送链路。

alter table public.notifications drop constraint notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type = any (array[
    'like'::text, 'comment'::text, 'follow'::text, 'mention'::text,
    'friend_request'::text, 'friend_accept'::text, 'new_post'::text
  ]));

create or replace function public.notify_followers_new_post()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.notifications (user_id, actor_id, type, post_id)
  select f.follower_id, new.user_id, 'new_post', new.id
  from public.follows f
  where f.following_id = new.user_id
    and f.follower_id <> new.user_id;
  return new;
exception when others then
  -- 通知失败不阻断发帖
  return new;
end;
$$;

drop trigger if exists trg_notify_followers_new_post on public.posts;
create trigger trg_notify_followers_new_post
after insert on public.posts
for each row execute function public.notify_followers_new_post();
