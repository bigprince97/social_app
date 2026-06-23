create or replace function public.get_active_livestream(p_conversation_id uuid)
returns setof public.calls
language sql
stable
as $$
  select *
  from public.calls
  where conversation_id = p_conversation_id
    and call_type = 'livestream'
    and status in ('ringing', 'accepted')
    and last_heartbeat_at >= now() - interval '45 seconds'
  order by created_at desc
  limit 1;
$$;

create or replace function public.mark_livestream_heartbeat(p_call_id uuid)
returns void
language sql
volatile
as $$
  update public.calls
  set last_heartbeat_at = now()
  where id = p_call_id
    and call_type = 'livestream'
    and status in ('ringing', 'accepted');
$$;

grant execute on function public.get_active_livestream(uuid) to authenticated;
grant execute on function public.mark_livestream_heartbeat(uuid) to authenticated;
