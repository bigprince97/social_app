-- Add an authorized private Broadcast path for chat message changes while
-- keeping public.messages in the supabase_realtime publication for installed
-- clients that still use Postgres Changes.

begin;

-- Snapshot every schema object touched by this migration before changing it.
-- The schema is not exposed by PostgREST and has no grants or RLS policies, so
-- only database administrators can read it.
create schema if not exists backup_20260711_chat_sync;
revoke all on schema backup_20260711_chat_sync
  from public, anon, authenticated;

create table if not exists backup_20260711_chat_sync.object_definitions (
  category text not null,
  object_key text not null,
  definition jsonb not null,
  captured_at timestamptz not null default clock_timestamp(),
  primary key (category, object_key)
);
alter table backup_20260711_chat_sync.object_definitions enable row level security;
revoke all on backup_20260711_chat_sync.object_definitions
  from public, anon, authenticated;

insert into backup_20260711_chat_sync.object_definitions (
  category,
  object_key,
  definition
)
select
  'policy',
  schemaname || '.' || tablename || '.' || policyname,
  to_jsonb(p)
from pg_policies p
where (schemaname = 'public' and tablename = 'messages')
   or (schemaname = 'realtime' and tablename = 'messages')
on conflict (category, object_key) do update
set definition = excluded.definition,
    captured_at = clock_timestamp();

insert into backup_20260711_chat_sync.object_definitions (
  category,
  object_key,
  definition
)
select
  'trigger',
  n.nspname || '.' || c.relname || '.' || t.tgname,
  jsonb_build_object(
    'trigger', pg_get_triggerdef(t.oid, true),
    'function', pg_get_functiondef(t.tgfoid)
  )
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where not t.tgisinternal
  and n.nspname = 'public'
  and c.relname = 'messages'
on conflict (category, object_key) do update
set definition = excluded.definition,
    captured_at = clock_timestamp();

insert into backup_20260711_chat_sync.object_definitions (
  category,
  object_key,
  definition
)
select
  'index',
  schemaname || '.' || tablename || '.' || indexname,
  jsonb_build_object('definition', indexdef)
from pg_indexes
where schemaname = 'public'
  and tablename in ('messages', 'conversation_members', 'blocks')
on conflict (category, object_key) do update
set definition = excluded.definition,
    captured_at = clock_timestamp();

insert into backup_20260711_chat_sync.object_definitions (
  category,
  object_key,
  definition
)
select
  'publication',
  pubname || '.' || schemaname || '.' || tablename,
  to_jsonb(p)
from pg_publication_tables p
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename = 'messages'
on conflict (category, object_key) do update
set definition = excluded.definition,
    captured_at = clock_timestamp();

-- The inverse lookup supports the second half of the two-way block check.
create index if not exists idx_blocks_blocked_blocker
  on public.blocks (blocked_id, blocker_id);

-- Blocking only suppresses messages in direct conversations. Group members
-- continue to see the full group discussion even if two members block each
-- other elsewhere in the app.
drop policy if exists messages_hide_blocked_select on public.messages;
create policy messages_hide_blocked_select
on public.messages
as restrictive
for select
to authenticated
using (
  exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and c.type = 'group'
  )
  or sender_id = (select auth.uid())
  or not exists (
    select 1
    from public.blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = messages.sender_id)
       or (b.blocker_id = messages.sender_id and b.blocked_id = (select auth.uid()))
  )
);

-- A message may be edited or recalled, but its identity, destination, sender,
-- original timestamp, and media kind/location are immutable after insertion.
create or replace function private.guard_message_immutable_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.id is distinct from old.id
     or new.conversation_id is distinct from old.conversation_id
     or new.sender_id is distinct from old.sender_id
     or new.created_at is distinct from old.created_at
     or new.message_type is distinct from old.message_type
     or new.media_url is distinct from old.media_url
     or new.image_url is distinct from old.image_url then
    raise exception using
      errcode = '22023',
      message = 'Immutable message fields cannot be changed';
  end if;

  return new;
end;
$function$;

alter function private.guard_message_immutable_fields() owner to postgres;
revoke all on function private.guard_message_immutable_fields()
  from public, anon, authenticated;

drop trigger if exists messages_guard_immutable_fields on public.messages;
create trigger messages_guard_immutable_fields
before update on public.messages
for each row
execute function private.guard_message_immutable_fields();

-- Private-channel authorization is evaluated when a user joins. Exact topic
-- equality prevents a caller-controlled topic from broadening membership.
-- There is intentionally no INSERT policy: clients may receive database
-- events but cannot forge them with sendBroadcastMessage/httpSend.
drop policy if exists conversation_members_receive_message_events
  on realtime.messages;
create policy conversation_members_receive_message_events
on realtime.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.conversation_members cm
    where cm.user_id = (select auth.uid())
      and (select realtime.topic()) =
          'conversation:' || cm.conversation_id::text || ':messages'
      and realtime.messages.extension in ('broadcast')
  )
);

-- Broadcast only an identifier envelope. The receiving client must fetch the
-- row through public.messages so membership and direct-chat block RLS remain
-- authoritative. realtime.send adds its own transport id internally; the
-- application payload below contains only the three documented fields.
create or replace function private.broadcast_message_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if coalesce(new.payload ->> 'files_only', 'false') = 'true' then
    return new;
  end if;

  perform realtime.send(
    jsonb_build_object(
      'message_id', new.id,
      'conversation_id', new.conversation_id,
      'operation', tg_op
    ),
    'message_changed',
    'conversation:' || new.conversation_id::text || ':messages',
    true
  );

  return new;
exception
  when others then
    -- A temporary Realtime failure must not roll back the canonical message.
    raise warning 'message broadcast failed: %', sqlerrm;
    return new;
end;
$function$;

alter function private.broadcast_message_event() owner to postgres;
revoke all on function private.broadcast_message_event()
  from public, anon, authenticated;

drop trigger if exists messages_broadcast_event on public.messages;
create trigger messages_broadcast_event
after insert or update of content, payload, mentions, is_deleted
on public.messages
for each row
execute function private.broadcast_message_event();

comment on function private.broadcast_message_event() is
  'Broadcasts only message_id, conversation_id, and operation to an authorized private conversation topic.';

commit;
