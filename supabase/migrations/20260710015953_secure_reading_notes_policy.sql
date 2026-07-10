drop policy if exists notes_own on public.reading_notes;

create policy notes_own
on public.reading_notes
as permissive
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
