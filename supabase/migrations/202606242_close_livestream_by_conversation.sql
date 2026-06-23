create or replace function public.close_livestream_call(p_call_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation_id uuid;
  v_uid uuid := auth.uid();
  v_allowed boolean := false;
begin
  select conversation_id into v_conversation_id
  from public.calls
  where id = p_call_id
    and call_type = 'livestream';

  if v_conversation_id is null or v_uid is null then
    return;
  end if;

  select exists (
    select 1
    from public.conversations c
    left join public.conversation_members cm
      on cm.conversation_id = c.id
     and cm.user_id = v_uid
    where c.id = v_conversation_id
      and (c.created_by = v_uid or cm.role = 'admin')
  ) into v_allowed;

  if not v_allowed then
    raise exception 'not allowed to close livestream';
  end if;

  update public.calls
  set status = 'ended', ended_at = now()
  where conversation_id = v_conversation_id
    and call_type = 'livestream'
    and status in ('ringing', 'accepted');
end;
$$;

revoke all on function public.close_livestream_call(uuid) from public;
grant execute on function public.close_livestream_call(uuid) to authenticated;
