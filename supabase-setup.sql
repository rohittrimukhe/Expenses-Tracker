-- LRS Conveyance Claim Tracker — full Supabase setup.
-- Run this whole file once in the Supabase SQL Editor (fresh project, or an
-- existing project you want brought to the current schema — every statement
-- is safe to re-run).

-- ---------------- tables ----------------

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
  name text, code text, grade text, location text, project text, address text,
  custom_modes jsonb not null default '[]'::jsonb
);
alter table profile add column if not exists custom_modes jsonb not null default '[]'::jsonb;

-- Unexpected JS errors logged here instead of only the browser console.
create table if not exists client_errors (
  id bigint generated always as identity primary key,
  message text,
  source text,
  url text,
  user_agent text,
  created_at timestamptz default now()
);

-- ---------------- row level security ----------------
-- auth.uid() is only non-null for a signed-in session, and Postgres checks
-- this on every request — it can't be bypassed by calling the API directly
-- with just the publishable key.

alter table entries enable row level security;
alter table evidence enable row level security;
alter table profile enable row level security;
alter table client_errors enable row level security;

drop policy if exists "auth only - entries" on entries;
drop policy if exists "auth only - evidence" on evidence;
drop policy if exists "auth only - profile" on profile;
drop policy if exists "auth only insert - client_errors" on client_errors;
drop policy if exists "auth only select - client_errors" on client_errors;

create policy "auth only - entries" on entries
  for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "auth only - evidence" on evidence
  for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "auth only - profile" on profile
  for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "auth only insert - client_errors" on client_errors
  for insert with check (auth.uid() is not null);
create policy "auth only select - client_errors" on client_errors
  for select using (auth.uid() is not null);

-- Table grants: "authenticated" only. RLS above already blocks "anon" from
-- reading/writing any row, so this doesn't change what's reachable today —
-- it's a second, independent barrier in case a policy is ever misconfigured.
revoke all on entries from anon;
revoke all on evidence from anon;
revoke all on profile from anon;
grant usage on schema public to anon, authenticated;
grant all on entries to authenticated;
grant all on evidence to authenticated;
grant all on profile to authenticated;
grant select, insert on client_errors to authenticated;

-- ---------------- storage policies for the "evidence" bucket ----------------
-- Reading files works via direct public URL regardless of these policies,
-- because the bucket itself is marked "Public" (a separate setting — see
-- README). Uploading/deleting still requires a signed-in session.

drop policy if exists "evidence read" on storage.objects;
drop policy if exists "evidence insert" on storage.objects;
drop policy if exists "evidence delete" on storage.objects;

create policy "evidence read" on storage.objects
  for select using (bucket_id = 'evidence');
create policy "evidence insert" on storage.objects
  for insert with check (bucket_id = 'evidence' and auth.uid() is not null);
create policy "evidence delete" on storage.objects
  for delete using (bucket_id = 'evidence' and auth.uid() is not null);

-- ---------------- your login ----------------
-- After running this: Dashboard → Authentication → Users → Add user —
-- create your one login (email + password). There's no public sign-up in the
-- app, so this is the only account that can ever sign in.
