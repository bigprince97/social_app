-- Manual rollback for 20260711011246_secure_chat_private_broadcast.sql.
-- This file intentionally lives outside supabase/migrations so db push never
-- applies it automatically. public.messages remains in supabase_realtime.

begin;

drop trigger if exists messages_broadcast_event on public.messages;
drop function if exists private.broadcast_message_event();

drop policy if exists conversation_members_receive_message_events
  on realtime.messages;

drop trigger if exists messages_guard_immutable_fields on public.messages;
drop function if exists private.guard_message_immutable_fields();

-- Restore the previous behavior: blocks suppress the other user's messages in
-- both direct and group conversations.
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

drop index if exists public.idx_blocks_blocked_blocker;

commit;
