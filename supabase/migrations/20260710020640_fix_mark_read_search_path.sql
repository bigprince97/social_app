-- conversation_members 的现有 UPDATE 触发器会调用 public 下的辅助函数；
-- 使用固定且最小的受信任搜索路径，兼顾安全与触发器兼容性。
alter function public.mark_conversation_read(uuid)
  set search_path = public, auth;
