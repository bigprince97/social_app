-- A direct voice/video call must be rejected when either participant has
-- blocked the other. This restrictive policy is combined with the existing
-- permissive "caller can insert call" policy.
drop policy if exists calls_blocked_insert_guard on public.calls;
create policy calls_blocked_insert_guard
on public.calls
as restrictive
for insert
to authenticated
with check (
  call_type = 'livestream'
  or (
    callee_id is not null
    and not exists (
      select 1
      from public.blocks b
      where (b.blocker_id = caller_id and b.blocked_id = callee_id)
         or (b.blocker_id = callee_id and b.blocked_id = caller_id)
    )
  )
);

-- Once a block is created, prevent a stale ringing call from being accepted
-- and terminate an already connected direct call immediately.
drop policy if exists calls_blocked_update_guard on public.calls;
create policy calls_blocked_update_guard
on public.calls
as restrictive
for update
to authenticated
using (
  call_type = 'livestream'
  or not exists (
    select 1
    from public.blocks b
    where (b.blocker_id = caller_id and b.blocked_id = callee_id)
       or (b.blocker_id = callee_id and b.blocked_id = caller_id)
  )
)
with check (
  call_type = 'livestream'
  or not exists (
    select 1
    from public.blocks b
    where (b.blocker_id = caller_id and b.blocked_id = callee_id)
       or (b.blocker_id = callee_id and b.blocked_id = caller_id)
  )
);

create or replace function public.end_active_calls_on_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  update public.calls
  set status = case when status = 'ringing' then 'declined' else 'ended' end,
      ended_at = coalesce(ended_at, now())
  where call_type in ('voice', 'video')
    and status in ('ringing', 'accepted')
    and (
      (caller_id = new.blocker_id and callee_id = new.blocked_id)
      or (caller_id = new.blocked_id and callee_id = new.blocker_id)
    );
  return new;
end;
$function$;

revoke all on function public.end_active_calls_on_block() from public;
revoke all on function public.end_active_calls_on_block() from anon;
revoke all on function public.end_active_calls_on_block() from authenticated;

drop trigger if exists end_active_calls_after_block on public.blocks;
create trigger end_active_calls_after_block
after insert on public.blocks
for each row
execute function public.end_active_calls_on_block();
