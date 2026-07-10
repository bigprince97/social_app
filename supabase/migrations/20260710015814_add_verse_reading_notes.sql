-- 圣经笔记由“整章一条”扩展为“每节一条”。旧版整章笔记保留为
-- verse_number is null，不误归到任何一节，也不丢失历史数据。
alter table public.reading_notes
  add column if not exists verse_number integer;

alter table public.reading_notes
  drop constraint if exists reading_notes_verse_number_positive;

alter table public.reading_notes
  add constraint reading_notes_verse_number_positive
  check (verse_number is null or verse_number > 0);

create unique index if not exists reading_notes_user_chapter_verse_unique
  on public.reading_notes (user_id, chapter_id, verse_number)
  where verse_number is not null;

create index if not exists reading_notes_chapter_verse_lookup
  on public.reading_notes (chapter_id, verse_number)
  where verse_number is not null;

grant select, insert, update, delete
  on table public.reading_notes
  to authenticated;
