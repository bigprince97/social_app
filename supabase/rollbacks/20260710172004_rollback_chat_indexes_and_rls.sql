-- Manual rollback for 20260710172004_optimize_chat_indexes_and_rls.sql.
-- This file intentionally lives outside supabase/migrations so db push never
-- applies it automatically.

begin;

create or replace function public.get_unread_counts()
returns table(conversation_id uuid, cnt bigint)
language sql
stable
security definer
set search_path = public
as $function$
  select m.conversation_id, count(*)::bigint
  from messages m
  join conversation_members cm
    on cm.conversation_id = m.conversation_id
   and cm.user_id = auth.uid()
  where m.sender_id <> auth.uid()
    and coalesce(m.is_deleted, false) = false
    and (cm.last_read_at is null or m.created_at > cm.last_read_at)
    and coalesce(cm.hidden, false) = false
  group by m.conversation_id;
$function$;

revoke all on function public.get_unread_counts() from public, anon;
grant execute on function public.get_unread_counts() to authenticated;

alter policy conv_members_select
on public.conversation_members
to public
using (
  is_conversation_member(conversation_id)
);

alter policy conversations_select
on public.conversations
to public
using (
  created_by = auth.uid()
  or exists (
    select 1
    from public.conversation_members
    where conversation_members.conversation_id = conversations.id
      and conversation_members.user_id = auth.uid()
  )
);

alter policy messages_select
on public.messages
to public
using (
  exists (
    select 1
    from public.conversation_members
    where conversation_members.conversation_id = messages.conversation_id
      and conversation_members.user_id = auth.uid()
  )
);

drop index if exists public.idx_messages_conversation_created_at;
drop index if exists public.idx_conversation_members_user_conversation;

drop function if exists private.my_conversation_ids();
revoke usage on schema private from authenticated;
drop schema if exists private;

commit;
