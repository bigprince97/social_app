-- Restore the first policy form from secure_chat_private_broadcast.
drop policy if exists conversation_members_receive_message_events
  on realtime.messages;

create policy conversation_members_receive_message_events
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and realtime.messages.private is true
  and exists (
    select 1
    from public.conversation_members cm
    where cm.user_id = (select auth.uid())
      and (select realtime.topic()) =
          'conversation:' || cm.conversation_id::text || ':messages'
  )
);
