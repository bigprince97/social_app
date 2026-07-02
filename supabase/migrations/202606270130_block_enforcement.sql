-- Enforce block effects at the database layer:
-- - blocked users' posts/comments/messages are hidden from each other
-- - likes, comments, follows, and direct messages are blocked both ways

drop policy if exists posts_hide_blocked_select on public.posts;
create policy posts_hide_blocked_select
on public.posts
as restrictive
for select
to authenticated
using (
  user_id = (select auth.uid())
  or not exists (
    select 1
    from public.blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = posts.user_id)
       or (b.blocker_id = posts.user_id and b.blocked_id = (select auth.uid()))
  )
);

drop policy if exists post_comments_hide_blocked_select on public.post_comments;
create policy post_comments_hide_blocked_select
on public.post_comments
as restrictive
for select
to authenticated
using (
  user_id = (select auth.uid())
  or not exists (
    select 1
    from public.blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = post_comments.user_id)
       or (b.blocker_id = post_comments.user_id and b.blocked_id = (select auth.uid()))
  )
);

drop policy if exists messages_hide_blocked_select on public.messages;
create policy messages_hide_blocked_select
on public.messages
as restrictive
for select
to authenticated
using (
  sender_id = (select auth.uid())
  or not exists (
    select 1
    from public.blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = messages.sender_id)
       or (b.blocker_id = messages.sender_id and b.blocked_id = (select auth.uid()))
  )
);

drop policy if exists follows_blocked_insert_guard on public.follows;
create policy follows_blocked_insert_guard
on public.follows
as restrictive
for insert
to authenticated
with check (
  not exists (
    select 1
    from public.blocks b
    where (b.blocker_id = follows.follower_id and b.blocked_id = follows.following_id)
       or (b.blocker_id = follows.following_id and b.blocked_id = follows.follower_id)
  )
);

drop policy if exists post_likes_blocked_insert_guard on public.post_likes;
create policy post_likes_blocked_insert_guard
on public.post_likes
as restrictive
for insert
to authenticated
with check (
  not exists (
    select 1
    from public.posts p
    join public.blocks b
      on (b.blocker_id = post_likes.user_id and b.blocked_id = p.user_id)
      or (b.blocker_id = p.user_id and b.blocked_id = post_likes.user_id)
    where p.id = post_likes.post_id
  )
);

drop policy if exists post_comments_blocked_insert_guard on public.post_comments;
create policy post_comments_blocked_insert_guard
on public.post_comments
as restrictive
for insert
to authenticated
with check (
  not exists (
    select 1
    from public.posts p
    join public.blocks b
      on (b.blocker_id = post_comments.user_id and b.blocked_id = p.user_id)
      or (b.blocker_id = p.user_id and b.blocked_id = post_comments.user_id)
    where p.id = post_comments.post_id
  )
);

drop policy if exists messages_blocked_direct_insert_guard on public.messages;
create policy messages_blocked_direct_insert_guard
on public.messages
as restrictive
for insert
to authenticated
with check (
  message_type = 'call'
  or not exists (
    select 1
    from public.conversations c
    join public.conversation_members cm
      on cm.conversation_id = c.id
     and cm.user_id <> messages.sender_id
    join public.blocks b
      on (b.blocker_id = messages.sender_id and b.blocked_id = cm.user_id)
      or (b.blocker_id = cm.user_id and b.blocked_id = messages.sender_id)
    where c.id = messages.conversation_id
      and c.type = 'direct'
  )
);
