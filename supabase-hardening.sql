-- Run this once in Supabase SQL Editor after supabase-auth-upgrade.sql.
-- Two independent changes, neither affects the app's behavior for a signed-in user:
--
-- 1) Narrow table-level GRANTs to "authenticated" only. RLS already blocks the
--    "anon" role from reading/writing any row (auth.uid() is null for anon), so
--    this doesn't change what's actually accessible today — it removes a second,
--    unnecessary grant so that if an RLS policy is ever misconfigured later,
--    anonymous requests are still blocked at the table-privilege level too.
-- 2) Add a client_errors table so the app can log unexpected JS errors somewhere
--    durable instead of only to the browser console. Insert-only from the app;
--    still requires a signed-in session, same as every other table here.

revoke all on entries from anon;
revoke all on evidence from anon;
revoke all on profile from anon;

grant all on entries to authenticated;
grant all on evidence to authenticated;
grant all on profile to authenticated;

create table if not exists client_errors (
  id bigint generated always as identity primary key,
  message text,
  source text,
  url text,
  user_agent text,
  created_at timestamptz default now()
);

alter table client_errors enable row level security;

drop policy if exists "auth only insert - client_errors" on client_errors;
drop policy if exists "auth only select - client_errors" on client_errors;

create policy "auth only insert - client_errors" on client_errors
  for insert with check (auth.uid() is not null);
create policy "auth only select - client_errors" on client_errors
  for select using (auth.uid() is not null);

grant select, insert on client_errors to authenticated;
