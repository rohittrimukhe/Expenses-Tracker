-- LRS Conveyance Claim Tracker — full Supabase setup.
-- Run this whole file once in the Supabase SQL Editor (fresh project, or an
-- existing project you want brought to the current schema — every statement
-- is safe to re-run).

-- ---------------- tables ----------------

create table if not exists entries (
  id text primary key,
  date date not null,
  customer_name text,
  so_number text,
  project text,
  legs jsonb not null,
  created_at timestamptz default now()
);
alter table entries add column if not exists so_number text;

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

-- Customer/route directory backing the New Entry autocomplete (Settings ->
-- Conveyance modes-style manager). Deliberately separate from "entries" —
-- deleting a month's entries never touches this table, and vice versa.
create table if not exists customers (
  id text primary key,
  name text not null,
  so_number text,
  created_at timestamptz default now()
);
create unique index if not exists customers_name_lower_idx on customers (lower(name));

create table if not exists customer_routes (
  id text primary key,
  customer_id text references customers(id) on delete cascade,
  from_location text,
  to_location text,
  mode text,
  distance text,
  rate text,
  amount text,
  created_at timestamptz default now()
);

-- A customer can have several SO Numbers (different projects/POs), each
-- with its own reference label (e.g. "Network Refresh", "AMC", "FMS").
-- Routes stay on "customers" above, not here — a route is the same
-- physical trip regardless of which SO Number it gets billed against.
create table if not exists customer_so_numbers (
  id text primary key,
  customer_id text references customers(id) on delete cascade,
  so_number text not null,
  reference text,
  created_at timestamptz default now()
);

-- One-time backfill: move any SO Number already sitting on "customers"
-- (from before this table existed) into it. Guarded so re-running this
-- file never creates a duplicate.
insert into customer_so_numbers (id, customer_id, so_number, reference)
select 'so_' || c.id, c.id, c.so_number, null
from customers c
where c.so_number is not null and c.so_number <> ''
  and not exists (
    select 1 from customer_so_numbers s where s.customer_id = c.id and s.so_number = c.so_number
  );

-- ---------------- row level security ----------------
-- auth.uid() is only non-null for a signed-in session, and Postgres checks
-- this on every request — it can't be bypassed by calling the API directly
-- with just the publishable key.

alter table entries enable row level security;
alter table evidence enable row level security;
alter table profile enable row level security;
alter table client_errors enable row level security;
alter table customers enable row level security;
alter table customer_routes enable row level security;
alter table customer_so_numbers enable row level security;

drop policy if exists "auth only - entries" on entries;
drop policy if exists "auth only - evidence" on evidence;
drop policy if exists "auth only - profile" on profile;
drop policy if exists "auth only insert - client_errors" on client_errors;
drop policy if exists "auth only select - client_errors" on client_errors;
drop policy if exists "auth only - customers" on customers;
drop policy if exists "auth only - customer_routes" on customer_routes;
drop policy if exists "auth only - customer_so_numbers" on customer_so_numbers;

create policy "auth only - entries" on entries
  for all using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy "auth only - evidence" on evidence
  for all using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy "auth only - profile" on profile
  for all using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy "auth only insert - client_errors" on client_errors
  for insert with check ((select auth.uid()) is not null);
create policy "auth only select - client_errors" on client_errors
  for select using ((select auth.uid()) is not null);
create policy "auth only - customers" on customers
  for all using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy "auth only - customer_routes" on customer_routes
  for all using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy "auth only - customer_so_numbers" on customer_so_numbers
  for all using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);

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
grant all on customers to authenticated;
grant all on customer_routes to authenticated;
grant all on customer_so_numbers to authenticated;

-- ---------------- storage policies for the "evidence" bucket ----------------
-- Fetching a file you already have the URL for works regardless of this
-- policy, because the bucket itself is marked "Public" (a separate setting
-- — see README) — that's the direct-object-download path. This SELECT
-- policy instead governs *listing* the bucket's contents (Storage's list()
-- API), which is a different operation and was previously open to anyone,
-- letting an anonymous client enumerate every file's name and path. The app
-- never calls list() itself (it tracks files via the "evidence" table
-- instead), so this is scoped to signed-in sessions only.

drop policy if exists "evidence read" on storage.objects;
drop policy if exists "evidence insert" on storage.objects;
drop policy if exists "evidence delete" on storage.objects;

create policy "evidence read" on storage.objects
  for select using (bucket_id = 'evidence' and auth.uid() is not null);
create policy "evidence insert" on storage.objects
  for insert with check (bucket_id = 'evidence' and auth.uid() is not null);
create policy "evidence delete" on storage.objects
  for delete using (bucket_id = 'evidence' and auth.uid() is not null);

-- ---------------- usage stats (DB / Storage size shown in the app header) ----------------
-- Neither figure is reachable through the normal table API, so these are
-- exposed as RPC functions instead. security invoker (not definer): each
-- runs with the CALLING role's own privileges, so an anonymous caller hits
-- the same RLS wall as everywhere else in the app rather than relying on
-- the internal auth.uid() check as the only safety net. Supabase's
-- Security Advisor flags security definer functions reachable by "anon" —
-- this removes that flag at the root instead of just gating around it.
-- Execute is granted to "authenticated" only; the authenticated-can-call
-- warning the Advisor also raises is expected here — the app needs a
-- signed-in session to read these, matching the rest of the app.

create or replace function get_db_size_bytes()
returns bigint
language sql
security invoker
set search_path = public
as $$
  select case when auth.uid() is not null then pg_database_size(current_database()) else null end;
$$;

create or replace function get_storage_size_bytes()
returns bigint
language sql
security invoker
set search_path = public
as $$
  select case when auth.uid() is not null
    then coalesce((select sum((metadata->>'size')::bigint) from storage.objects where bucket_id = 'evidence'), 0)
    else null end;
$$;

revoke all on function get_db_size_bytes() from public;
revoke all on function get_storage_size_bytes() from public;
revoke all on function get_db_size_bytes() from anon;
revoke all on function get_storage_size_bytes() from anon;
grant execute on function get_db_size_bytes() to authenticated;
grant execute on function get_storage_size_bytes() to authenticated;

-- ---------------- your login ----------------
-- After running this: Dashboard → Authentication → Users → Add user —
-- create your one login (email + password). There's no public sign-up in the
-- app, so this is the only account that can ever sign in.
