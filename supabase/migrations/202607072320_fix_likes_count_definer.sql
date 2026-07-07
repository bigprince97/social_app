-- 修复点赞计数永远不准的根因:
-- update_post_likes_count 缺 SECURITY DEFINER,以点赞者身份 UPDATE posts
-- 被 RLS(仅作者可改)静默拦截 → 给别人点赞从不计数;特权路径删赞却能 -1 → 负数。
create or replace function public.update_post_likes_count()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'INSERT' then
    update posts set likes_count = coalesce(likes_count, 0) + 1
    where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update posts set likes_count = greatest(coalesce(likes_count, 0) - 1, 0)
    where id = old.post_id;
  end if;
  return null;
end;
$$;

-- 全库重算,对齐真实行数
update posts p set
  likes_count = (select count(*) from post_likes l where l.post_id = p.id),
  comments_count = (select count(*) from post_comments c where c.post_id = p.id);
