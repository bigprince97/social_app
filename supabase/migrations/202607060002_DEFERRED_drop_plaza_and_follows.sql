-- ⚠️⚠️ 延后执行（DEFERRED）：破坏性清理——删除广场与关注体系 ⚠️⚠️
--
-- 【何时执行】新版本（无广场、带好友系统）提交 App Store / Google Play 审核、
-- 且旧 build 1.0.2(8) 的审核提交已取消之后，才在线上执行本文件。
-- 原因：旧 build 仍在审核队列，若现在删表，审核员打开旧版广场会报错/白屏，
-- 可能招致 2.1 崩溃拒审。在那之前线上必须保留这些表。
--
-- 【执行方式】Supabase MCP apply_migration 或 SQL Editor 原样执行。

-- 1) 清理旧类型通知（点赞/评论/关注/未实现的 mention）
delete from public.notifications where type in ('like','comment','mention','follow');

-- 2) 收窄通知类型约束到新体系
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('friend_request','friend_accept'));

-- 3) 通知表去掉广场外键列（随广场一起退役）
alter table public.notifications drop column if exists post_id;
alter table public.notifications drop column if exists comment_id;

-- 4) 删除广场全部表（触发器/RLS 随表消失）
drop table if exists public.post_bookmarks cascade;
drop table if exists public.post_likes cascade;
drop table if exists public.post_comments cascade;
drop table if exists public.post_topics cascade;
drop table if exists public.reposts cascade;
drop table if exists public.posts cascade;

-- 5) 删除单向关注（已由 friendships 取代；trg_notify_follow 随表消失）
drop table if exists public.follows cascade;

-- 6) profiles 冗余计数列退役
alter table public.profiles drop column if exists posts_count;
alter table public.profiles drop column if exists followers_count;
alter table public.profiles drop column if exists following_count;

-- 7) Storage：media 桶中 posts/ 前缀的历史对象可在控制台手动清理（可选）

-- ═══════════════════════════════════════════════════════════════
-- 8) 重新启用「非好友不能私信」的服务端强制（2026-07-06 曾应用后临时还原）
--    执行时机与上面相同：新版提审、旧 build 取消之后。
--    a. 给 create_direct_conversation 函数开头加回好友校验块：
--       if not exists (
--         select 1 from friendships f
--         where f.status = 'accepted'
--           and ((f.requester_id = current_user_id and f.addressee_id = other_user_id)
--             or (f.requester_id = other_user_id and f.addressee_id = current_user_id))
--       ) then
--         raise exception 'NOT_FRIENDS';
--       end if;
--    （完整函数体见 202607060003_friends_only_direct_messaging.sql）
--    b. 恢复 messages 兜底 RLS：
create policy messages_direct_friends_only_insert_guard on public.messages
  as restrictive for insert to authenticated
  with check (
    coalesce(message_type, 'text') = 'call'
    or not exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id and c.type = 'direct'
    )
    or exists (
      select 1
      from public.conversation_members cm
      where cm.conversation_id = messages.conversation_id
        and cm.user_id <> auth.uid()
        and exists (
          select 1 from public.friendships f
          where f.status = 'accepted'
            and ((f.requester_id = auth.uid() and f.addressee_id = cm.user_id)
              or (f.requester_id = cm.user_id and f.addressee_id = auth.uid()))
        )
    )
  );
