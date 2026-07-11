-- Optimize the hot chat reads used by installed clients without changing the
-- REST/RPC contract. The helper resolves the caller's memberships once per
-- statement instead of recursively checking conversation_members per row.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.my_conversation_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $function$
  select cm.conversation_id
  from public.conversation_members cm
  where cm.user_id = (select auth.uid());
$function$;

revoke all on function private.my_conversation_ids() from public, anon;
grant execute on function private.my_conversation_ids() to authenticated;

create index if not exists idx_messages_conversation_created_at
  on public.messages (conversation_id, created_at desc);

create index if not exists idx_conversation_members_user_conversation
  on public.conversation_members (user_id, conversation_id)
  include (last_read_at, hidden, role);

alter policy conv_members_select
on public.conversation_members
to authenticated
using (
  conversation_id in (select private.my_conversation_ids())
);

alter policy conversations_select
on public.conversations
to authenticated
using (
  created_by = (select auth.uid())
  or id in (select private.my_conversation_ids())
);

alter policy messages_select
on public.messages
to authenticated
using (
  conversation_id in (select private.my_conversation_ids())
);

create or replace function public.get_unread_counts()
returns table(conversation_id uuid, cnt bigint)
language sql
stable
security definer
set search_path = ''
as $function$
  with me as materialized (
    select auth.uid() as uid
  )
  select m.conversation_id, count(*)::bigint
  from me
  join public.conversation_members cm
    on cm.user_id = me.uid
  join public.messages m
    on m.conversation_id = cm.conversation_id
  where me.uid is not null
    and m.sender_id <> me.uid
    and coalesce(m.is_deleted, false) = false
    and (cm.last_read_at is null or m.created_at > cm.last_read_at)
    and coalesce(cm.hidden, false) = false
  group by m.conversation_id;
$function$;

revoke all on function public.get_unread_counts() from public, anon;
grant execute on function public.get_unread_counts() to authenticated;

comment on function private.my_conversation_ids() is
  'Returns only the current authenticated user membership ids for RLS init plans.';
