-- Run this whole file once in Supabase SQL Editor (fresh project setup).
-- If you already ran an earlier version of this file, use supabase-auth-upgrade.sql
-- instead to upgrade in place without losing data.

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

-- Real login-enforced access: auth.uid() is only non-null for a signed-in session,
-- and Postgres checks this on every request — it can't be bypassed by calling the
-- API directly with just the publishable key.
drop policy if exists "auth only - entries" on entries;
drop policy if exists "auth only - evidence" on evidence;
drop policy if exists "auth only - profile" on profile;

create policy "auth only - entries" on entries
  for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "auth only - evidence" on evidence
  for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "auth only - profile" on profile
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

-- Required on newer Supabase projects for the browser API to reach these tables
grant usage on schema public to anon, authenticated;
grant all on entries to anon, authenticated;
grant all on evidence to anon, authenticated;
grant all on profile to anon, authenticated;

-- Storage policies for the "evidence" bucket.
-- Reading files works via direct public URL regardless of these policies, because the
-- bucket itself is marked "Public" (a separate setting) — see README for this tradeoff.
-- Uploading/deleting still requires a signed-in session.
drop policy if exists "evidence read" on storage.objects;
drop policy if exists "evidence insert" on storage.objects;
drop policy if exists "evidence delete" on storage.objects;

create policy "evidence read" on storage.objects
  for select using (bucket_id = 'evidence');
create policy "evidence insert" on storage.objects
  for insert with check (bucket_id = 'evidence' and auth.uid() is not null);
create policy "evidence delete" on storage.objects
  for delete using (bucket_id = 'evidence' and auth.uid() is not null);

-- After running this: Dashboard → Authentication → Users → Add user —
-- create your one login (email + password). There's no public sign-up in the app,
-- so this is the only account that can ever sign in.
