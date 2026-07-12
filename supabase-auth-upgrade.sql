-- Run this once in Supabase SQL Editor to upgrade from the old "anyone with the
-- key can read/write" policies to real login-enforced security.

-- 1) Replace the wide-open table policies with ones that require a signed-in session.
--    auth.uid() is only non-null when the request carries a valid logged-in user's token —
--    Postgres itself checks this, so it can't be bypassed by calling the API directly.
drop policy if exists "allow all - entries" on entries;
drop policy if exists "allow all - evidence" on evidence;
drop policy if exists "allow all - profile" on profile;

create policy "auth only - entries" on entries
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

create policy "auth only - evidence" on evidence
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

create policy "auth only - profile" on profile
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

-- 2) Require login for uploading/deleting evidence files too.
--    Note: reading files still works via direct public URL regardless of this policy,
--    because the bucket itself is marked "Public" — that's a separate setting from RLS.
--    (See note in README about this tradeoff.)
drop policy if exists "evidence insert" on storage.objects;
drop policy if exists "evidence delete" on storage.objects;

create policy "evidence insert" on storage.objects
  for insert with check (bucket_id = 'evidence' and auth.uid() is not null);

create policy "evidence delete" on storage.objects
  for delete using (bucket_id = 'evidence' and auth.uid() is not null);

-- 3) The old passcode_hash column is no longer used (replaced by real Supabase Auth).
--    Safe to leave in place, or drop it:
-- alter table profile drop column if exists passcode_hash;

-- 4) Create your login user (do this in the UI instead — see README "Create your login" step) —
--    Dashboard → Authentication → Users → Add user → enter your email + a password.
--    That's the only account able to sign in; there's no public sign-up in this app.
