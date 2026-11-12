-- Change Log table (Bulk Edit / Excel import history). Safe to re-run.
-- Already applied to the live project on 2026-11-12.
create table if not exists change_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  action text not null,
  source text,
  batch_id text,
  entry_id text,
  entry_date text,
  field text,
  old_value text,
  new_value text,
  user_id uuid references auth.users(id)
);
create index if not exists change_log_user_at_idx on change_log (user_id, at desc);
alter table change_log enable row level security;
drop policy if exists "own rows or admin - change_log" on change_log;
create policy "own rows or admin - change_log" on change_log
  for all using (user_id = (select auth.uid()) or (select is_admin()))
  with check (user_id = (select auth.uid()) or (select is_admin()));
grant all on change_log to authenticated;
