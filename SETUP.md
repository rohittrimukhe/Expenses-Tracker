# Setup Guide — LRS Conveyance Claim Tracker

This is a single static HTML file (`index.html`) with no build step, backed by
a Supabase project (Postgres database + file storage + auth). This guide gets
a fresh copy of the app running from zero.

## 1. Create a Supabase project

Go to [supabase.com](https://supabase.com), create a free account and a new
project. Note the project's URL and API keys — you'll need them in step 4.

## 2. Create your admin login

Supabase Dashboard → **Authentication** → **Users** → **Add user** → enter an
email and password. This is real Supabase Auth (not a shared passcode) —
there's no public sign-up in the app, so only accounts created this way can
ever sign in. After creating it, click into the user and copy its **UUID** —
you'll need it in the next step.

## 3. Run the database setup script

Open [`supabase-setup.sql`](supabase-setup.sql) and replace every occurrence
of the UUID in the "admin account" comment near the top (search for it — it
appears inside `is_admin()` and in the one-time backfill block) with the
UUID you copied in step 2. Then: Supabase Dashboard → **SQL Editor** → paste
the full contents → **Run**.

This one file creates everything: the `entries`, `evidence`, `profile`, and
`client_errors` tables (each scoped to its owning user), Row Level Security
policies (every request requires a signed-in session, and non-admin users
only ever see their own rows), table grants, and the Storage access policies
for the evidence bucket. It's safe to re-run if you're not sure whether it
already ran (just make sure the UUID is still correct before you do).

## 4. Create the evidence Storage bucket

Supabase Dashboard → **Storage** → **New bucket** → name it exactly
`evidence` → mark it **Public**.

The bucket being public means anyone with the *exact* file URL can view a
file (URLs are unguessable, not indexed anywhere) — uploading, listing, and
deleting still require a signed-in session scoped to the file's owner (or
the admin). This is a deliberate tradeoff for simplicity; see `DEPLOYMENT.md`
if you want to revisit it later.

## 4b. Deploy the admin-create-user Edge Function (optional)

Only needed if you want the in-app Settings → Users → "Create user" button
(auto-generated temporary password, forced password reset on first
sign-in). Requires the [Supabase CLI](https://supabase.com/docs/guides/cli):

```
supabase functions deploy admin-create-user --project-ref YOUR-PROJECT-REF
```

No secrets to configure — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` are injected automatically into every Edge
Function. If you skip this step, the button in Settings will fail; you can
still add users the next way instead.

## 4c. Adding users without the Edge Function (always works)

Supabase Dashboard → **Authentication** → **Users** → **Add user**, same as
step 2, with their own email + password — no SQL changes needed, since the
schema already supports any number of accounts. They'll appear in the app's
Settings → Users card (visible to the admin only) right away, and get a
completely empty dashboard scoped to just their own data the moment they
sign in — but without the forced-password-reset flow, since that only
triggers for users created through the Edge Function. See "Multi-user
accounts" in `DEPLOYMENT.md` for details.

## 5. Point the app at your Supabase project

Open `index.html`, find this block near the top of the `<script>` section,
and fill in your project's values (Supabase Dashboard → **Settings → API**):

```js
const SUPABASE_URL = 'https://YOUR-PROJECT-REF.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_...';
```

Use the **publishable** key — never the `service_role` secret key here. The
publishable key is safe to expose in client code by design; real protection
comes from the Row Level Security policies set up in step 2.

## 6. Deploy it somewhere you can reach it

Pick whichever is easiest — all are free:

- **GitHub Pages** (this repo): Settings → Pages → Deploy from branch → `main` → Save. You get a URL like `https://yourusername.github.io/repo-name`.
- **Netlify drag-and-drop**: go to netlify.com, drag this folder onto the page — instant live URL, no GitHub needed.
- **Vercel**: connect this GitHub repo at vercel.com for automatic deploys on every push.

## 7. First sign-in

Open the deployed URL, sign in with the email/password from step 4, then go
to **Employee Details** and fill in your name, employee code, grade,
location, and default project — these populate the header of every exported
claim form.

## Optional: automated encrypted backups

`.github/workflows/backup.yml` runs twice a week, exports your data + every
evidence file, encrypts it, and commits it into this repo's `backups/`
folder. It's off by default until you add two GitHub repository secrets
(Settings → Secrets and variables → Actions):

- `SUPABASE_SERVICE_ROLE_KEY` — Supabase Dashboard → Settings → API → `service_role` key (bypasses RLS for the scheduled job; never put this in a file)
- `BACKUP_PASSPHRASE` — your own encryption passphrase (also never written to a file)

**Before turning this on, make sure the repo is private** (Settings →
General → Danger Zone → Change visibility) — an encrypted backup committed to
a *public* repo can be downloaded and attacked offline indefinitely. See
`DEPLOYMENT.md` → "Backups" for restore instructions.

## What's next

Day-to-day usage and the full security/maintenance picture are covered in
`README.md` and `DEPLOYMENT.md` respectively.
