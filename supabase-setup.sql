-- Run this whole file once in Supabase SQL Editor

create table if not exists entries (
  id text primary key,
  date date not null,
  customer_name text,
  project text,
  legs jsonb not null,
  created_at timestamptz default now()
);

create table if not exists evidence (
  id text primary key,
  entry_id text references entries(id) on delete cascade,
  file_name text,
  mime_type text,
  tag text,
  storage_path text,
  uploaded_at timestamptz default now()
);

create table if not exists profile (
  id int primary key default 1,
  name text, code text, grade text, location text, project text, address text
);

alter table entries enable row level security;
alter table evidence enable row level security;
alter table profile enable row level security;

drop policy if exists "allow all - entries" on entries;
drop policy if exists "allow all - evidence" on evidence;
drop policy if exists "allow all - profile" on profile;

create policy "allow all - entries" on entries for all using (true) with check (true);
create policy "allow all - evidence" on evidence for all using (true) with check (true);
create policy "allow all - profile" on profile for all using (true) with check (true);

-- Required on newer Supabase projects for the browser API to reach these tables
grant usage on schema public to anon, authenticated;
grant all on entries to anon, authenticated;
grant all on evidence to anon, authenticated;
grant all on profile to anon, authenticated;

-- Storage policies for the "evidence" bucket (needed in addition to marking it Public,
-- since Public only controls read access — uploads/deletes need their own policies)
drop policy if exists "evidence read" on storage.objects;
drop policy if exists "evidence insert" on storage.objects;
drop policy if exists "evidence delete" on storage.objects;

create policy "evidence read" on storage.objects
  for select using (bucket_id = 'evidence');

create policy "evidence insert" on storage.objects
  for insert with check (bucket_id = 'evidence');

create policy "evidence delete" on storage.objects
  for delete using (bucket_id = 'evidence');

-- For in-app passcode changing (added later): store a SHA-256 hash, never the plain passcode
alter table profile add column if not exists passcode_hash text;
