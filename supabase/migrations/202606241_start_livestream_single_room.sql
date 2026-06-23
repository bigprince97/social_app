create or replace function public.start_livestream_call(p_conversation_id uuid)
returns public.calls
language plpgsql
volatile
as $$
declare
  v_existing public.calls;
  v_call public.calls;
  v_room text;
begin
  perform pg_advisory_xact_lock(hashtext(p_conversation_id::text));

  select * into v_existing
  from public.calls
  where conversation_id = p_conversation_id
    and call_type = 'livestream'
    and status in ('ringing', 'accepted')
    and last_heartbeat_at >= now() - interval '45 seconds'
  order by created_at desc
  limit 1;

  if found then
    return v_existing;
  end if;

  update public.calls
  set status = 'ended', ended_at = now()
  where conversation_id = p_conversation_id
    and call_type = 'livestream'
    and status in ('ringing', 'accepted');

  v_room := 'call_' || (extract(epoch from clock_timestamp()) * 1000)::bigint::text;

  insert into public.calls (
    conversation_id,
    caller_id,
    call_type,
    status,
    livekit_room,
    last_heartbeat_at
  ) values (
    p_conversation_id,
    auth.uid(),
    'livestream',
    'ringing',
    v_room,
    now()
  ) returning * into v_call;

  return v_call;
end;
$$;

grant execute on function public.start_livestream_call(uuid) to authenticated;
