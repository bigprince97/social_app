create or replace function public.mark_conversation_read(
  p_conversation_id uuid
)
returns void
language sql
security invoker
set search_path = ''
as $$
  update public.conversation_members
  set last_read_at = now()
  where conversation_id = p_conversation_id
    and user_id = (select auth.uid());
$$;

revoke all on function public.mark_conversation_read(uuid) from public;
revoke all on function public.mark_conversation_read(uuid) from anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- 未读统计是 SECURITY DEFINER RPC，只允许已登录用户调用。
revoke all on function public.get_unread_counts() from public;
revoke all on function public.get_unread_counts() from anon;
grant execute on function public.get_unread_counts() to authenticated;
