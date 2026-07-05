-- 非好友不能私信：RPC 校验 + messages 兜底 RLS
-- 已于 2026-07-06 通过 Supabase MCP 应用到线上项目 xywcjkxqgrrbwfcknetc
-- ⚠️ 注意：此变更对旧版 build 1.0.2(8) 同样生效（旧版陌生人私信会报错）——
-- 旧版即将被取消提审并由 v1.1.0 取代，属预期行为。

-- 1) create_direct_conversation 加好友校验（非好友 → RAISE 'NOT_FRIENDS'）
--    完整函数体见线上（与原版唯一差异 = 函数开头的好友校验块）：
--    if not exists (
--      select 1 from friendships f
--      where f.status = 'accepted'
--        and ((f.requester_id = current_user_id and f.addressee_id = other_user_id)
--          or (f.requester_id = other_user_id and f.addressee_id = current_user_id))
--    ) then
--      raise exception 'NOT_FRIENDS';
--    end if;

-- 2) 兜底 RLS：direct 会话发消息必须已互为好友（message_type='call' 豁免，仿拉黑守卫）
create policy messages_direct_friends_only_insert_guard on public.messages
  as restrictive for insert to authenticated
  with check (
    coalesce(message_type, 'text') = 'call'
    or not exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id and c.type = 'direct'
    )
    or exists (
      select 1
      from public.conversation_members cm
      where cm.conversation_id = messages.conversation_id
        and cm.user_id <> auth.uid()
        and exists (
          select 1 from public.friendships f
          where f.status = 'accepted'
            and ((f.requester_id = auth.uid() and f.addressee_id = cm.user_id)
              or (f.requester_id = cm.user_id and f.addressee_id = auth.uid()))
        )
    )
  );
