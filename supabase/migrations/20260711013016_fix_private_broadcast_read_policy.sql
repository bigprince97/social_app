-- Realtime's authorization probe supplies extension/topic, but the synthetic
-- SELECT row does not guarantee a value for realtime.messages.private.
-- Private mode is already enforced by the client channel join itself.
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
