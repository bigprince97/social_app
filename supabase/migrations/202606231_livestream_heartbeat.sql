alter table public.calls
  add column if not exists last_heartbeat_at timestamptz;

create index if not exists calls_active_livestream_heartbeat_idx
  on public.calls (conversation_id, last_heartbeat_at desc, created_at desc)
  where call_type = 'livestream' and status in ('ringing', 'accepted');

update public.calls
set last_heartbeat_at = coalesce(last_heartbeat_at, started_at, created_at)
where call_type = 'livestream'
  and status in ('ringing', 'accepted');
