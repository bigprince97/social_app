-- Keep the existing RPC contract for installed clients, but only let the
-- livestream host persist heartbeats. Viewer calls become successful no-ops.
create or replace function public.mark_livestream_heartbeat(p_call_id uuid)
returns void
language sql
set search_path = public, auth
as $function$
  update public.calls
  set last_heartbeat_at = now()
  where id = p_call_id
    and caller_id = (select auth.uid())
    and call_type = 'livestream'
    and status in ('ringing', 'accepted')
    and (
      last_heartbeat_at is null
      or last_heartbeat_at < now() - interval '10 seconds'
    );
$function$;

revoke all on function public.mark_livestream_heartbeat(uuid) from public;
revoke all on function public.mark_livestream_heartbeat(uuid) from anon;
grant execute on function public.mark_livestream_heartbeat(uuid) to authenticated;

-- The previous permissive guard allowed any authenticated user to update a
-- livestream call row. Preserve participant behavior while closing that path.
alter policy "calls_blocked_update_guard"
on public.calls
to authenticated
using (
  (
    caller_id = (select auth.uid())
    or callee_id = (select auth.uid())
  )
  and (
    call_type = 'livestream'
    or not exists (
      select 1
      from public.blocks b
      where
        (b.blocker_id = calls.caller_id and b.blocked_id = calls.callee_id)
        or
        (b.blocker_id = calls.callee_id and b.blocked_id = calls.caller_id)
    )
  )
)
with check (
  (
    caller_id = (select auth.uid())
    or callee_id = (select auth.uid())
  )
  and (
    call_type = 'livestream'
    or not exists (
      select 1
      from public.blocks b
      where
        (b.blocker_id = calls.caller_id and b.blocked_id = calls.callee_id)
        or
        (b.blocker_id = calls.callee_id and b.blocked_id = calls.caller_id)
    )
  )
);

comment on function public.mark_livestream_heartbeat(uuid) is
  'Refreshes an active livestream heartbeat only for its caller/host; viewer calls are compatible no-ops and rapid repeats are ignored.';
