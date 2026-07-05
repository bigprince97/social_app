-- 好友系统：friendships 表 + RLS + 通知触发器（加法迁移，不动现有广场表）
-- 已于 2026-07-06 通过 Supabase MCP 应用到线上项目 xywcjkxqgrrbwfcknetc

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint friendships_no_self check (requester_id <> addressee_id)
);

-- 同一对用户只允许一条关系（含反向重复）
create unique index friendships_pair_uniq
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index friendships_addressee_idx on public.friendships (addressee_id, status);
create index friendships_requester_idx on public.friendships (requester_id, status);

alter table public.friendships enable row level security;

-- 只看得到与自己相关的关系
create policy friendships_select on public.friendships
  for select to authenticated
  using (auth.uid() in (requester_id, addressee_id));

-- 只能以自己名义发起申请；被拉黑/拉黑对方都不允许（仿 block_enforcement 模式）
create policy friendships_insert on public.friendships
  for insert to authenticated
  with check (
    auth.uid() = requester_id
    and status = 'pending'
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = requester_id and b.blocked_id = addressee_id)
         or (b.blocker_id = addressee_id and b.blocked_id = requester_id)
    )
  );

-- 只有被申请方能改状态（接受）
create policy friendships_update on public.friendships
  for update to authenticated
  using (auth.uid() = addressee_id and status = 'pending')
  with check (status = 'accepted');

-- 双方都可删（拒绝/取消申请/解除好友）
create policy friendships_delete on public.friendships
  for delete to authenticated
  using (auth.uid() in (requester_id, addressee_id));

-- 通知类型扩容（保留旧类型，等旧版下线后再收窄）
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('like','comment','follow','mention','friend_request','friend_accept'));

-- 好友申请 → 通知被申请方
create or replace function public.notify_friend_request()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.status = 'pending' and not exists (
    select 1 from public.blocks b
    where (b.blocker_id = new.requester_id and b.blocked_id = new.addressee_id)
       or (b.blocker_id = new.addressee_id and b.blocked_id = new.requester_id)
  ) then
    insert into public.notifications (user_id, actor_id, type)
    values (new.addressee_id, new.requester_id, 'friend_request');
  end if;
  return new;
end;
$$;
create trigger trg_notify_friend_request
  after insert on public.friendships
  for each row execute function public.notify_friend_request();

-- 接受申请 → 通知原申请方
create or replace function public.notify_friend_accept()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if old.status = 'pending' and new.status = 'accepted' then
    insert into public.notifications (user_id, actor_id, type)
    values (new.requester_id, new.addressee_id, 'friend_accept');
  end if;
  return new;
end;
$$;
create trigger trg_notify_friend_accept
  after update on public.friendships
  for each row execute function public.notify_friend_accept();

-- 接受时自动记录响应时间
create or replace function public.stamp_friendship_response()
returns trigger
language plpgsql
as $$
begin
  if old.status = 'pending' and new.status = 'accepted' and new.responded_at is null then
    new.responded_at := now();
  end if;
  return new;
end;
$$;
create trigger trg_stamp_friendship_response
  before update on public.friendships
  for each row execute function public.stamp_friendship_response();

-- 实时：通知与好友关系入 publication（站内红点/列表实时刷新）
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.friendships;
