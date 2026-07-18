# Production Deployment Notes — LRS Conveyance Claim Tracker

Status: **Production-ready.** This document is the single reference for what
was built, how it's secured, and how to maintain it going forward.

## What this is

A private, browser-based tool for logging local conveyance claims and
exporting them as an Excel file matching the original LRS paper-form layout
exactly — including embedded evidence photos, correct formatting, and
cross-linked sheets. All data lives in a private Supabase project (database +
file storage); the app itself is a single static HTML file with no server of
its own.

## Files

| File | Purpose |
|---|---|
| `index.html` | The application. Deploy this. |
| `manifest.json`, `icon-192.png`, `icon-512.png` | Enable "Add to Home Screen" on mobile |
| `supabase-setup.sql` | Full schema + security setup — the single file to run in the Supabase SQL Editor, safe to re-run |
| `SETUP.md` | Full step-by-step guide for standing up a fresh copy of this app |
| `.github/workflows/backup.yml`, `scripts/backup.sh` | Scheduled encrypted backup — see "Backups" below |

## Before this is safe to run in production

This repo is currently **public**. The encrypted-backup setup below stores backup files inside this repo, which means anyone can download the ciphertext and attempt unlimited offline decryption attempts — there's no login rate-limiting like there is for the app itself. **Make the repo private first:** GitHub → this repo → Settings → General → Danger Zone → Change repository visibility → Private. GitHub Pages continues to work on private repos on the free plan. Do this before enabling the backup workflow below.

## Hardening applied (all in `supabase-setup.sql` + `index.html`)

- **`index.html`:** all user-supplied text (customer name, from/to, tags, filenames, profile fields) is HTML-escaped before being rendered, closing an XSS gap where a crafted value could have run arbitrary JS in an authenticated session. The Evidence Vault "Open" button no longer builds its click handler by interpolating a URL into a string (a JS-string-breakout risk) — it's wired up directly in JS instead.
- **`index.html`:** the two CDN scripts (`supabase-js`, `exceljs`) are pinned to exact versions with Subresource Integrity hashes, so a compromised or tampered CDN file would fail to load instead of silently executing. This does mean `supabase-js` no longer auto-updates on every page load — bump the version + hash in `index.html` deliberately when you want to upgrade it.
- **`index.html`:** you're auto-signed-out after 5 minutes of inactivity, and changing your password requires re-entering the current one first.
- **`supabase-setup.sql`:** grants table access to the `authenticated` role only (RLS already blocked `anon` in practice; this removes the redundant grant as defense-in-depth) and creates a `client_errors` table so unexpected JS errors are logged somewhere durable instead of only the browser console.
- **Not changed:** the evidence storage bucket stays public (by your call — it only holds receipts/travel evidence). Per-row data ownership (`user_id` column) wasn't added since there's exactly one login account today; add it before ever creating a second account, not after.

## Backups

A GitHub Actions workflow (`.github/workflows/backup.yml`) runs twice a week (Mon/Thu 03:17 UTC, plus on-demand via the Actions tab → "Encrypted backup" → Run workflow). It pulls `entries`, `evidence`, and `profile` as JSON, downloads every evidence file from Storage, bundles it all into a `.tar.gz`, encrypts it with AES-256 (PBKDF2, 300,000 iterations), and commits the encrypted file to `backups/` in this repo. It keeps the last 12 backups and prunes older ones automatically. As a side effect, this also keeps the Supabase project from auto-pausing, since it queries the database directly every few days.

**One-time setup — two repository secrets, added by you in GitHub, never committed to any file:**

GitHub → this repo → Settings → Secrets and variables → Actions → New repository secret:

1. `SUPABASE_SERVICE_ROLE_KEY` — from Supabase Dashboard → Settings → API → `service_role` key (**not** the publishable key). This bypasses RLS so the scheduled job can read all tables without a login session — treat it as highly sensitive; it only ever lives inside this GitHub secret, never in a file.
2. `BACKUP_PASSPHRASE` — your backup encryption passphrase. Also never written to any file in this repo — the workflow reads it only from this secret at run time.

**Restoring a backup:**

```
openssl enc -d -aes-256-cbc -pbkdf2 -iter 300000 -salt \
  -in backups/backup-2026-07-18.tar.gz.enc -out backup.tar.gz \
  -pass pass:'your-passphrase-here'
tar -xzf backup.tar.gz
```

This extracts a `data/` folder (`entries.json`, `evidence.json`, `profile.json`) and a `files/` folder mirroring the evidence bucket's storage paths.

## Access model

- Sign-in is a real account (Supabase Auth, email + password) — not a shared
  passcode. There is exactly one account and no public sign-up path.
- Every database request is checked by Postgres itself (Row Level Security):
  requests without a valid signed-in session are rejected outright, even if
  someone calls the API directly with the app's public key.
- Evidence files are served from a public Storage bucket for simplicity —
  reachable by anyone with the *exact* file URL, though URLs are unlisted and
  not guessable. Uploading and deleting files still requires sign-in.

## Current configuration

- Live URL: your GitHub Pages URL (`https://rohittrimukhe.github.io/<repo>/`)
- Backend project: configured in the `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY`
  constants near the top of `index.html`'s `<script>` block
- Login: the one account created in Supabase → Authentication → Users

## Routine maintenance

- **Monthly**: log entries as they happen, attach evidence photos/PDFs, then
  use Export to Excel once the month is complete.
- **After reimbursement**: use Dashboard → month row → "Delete month" to clear
  that month's data and free up space.
- **If the site goes idle for 7+ days**: the free database tier pauses
  automatically. The twice-weekly backup workflow (see "Backups" above)
  already prevents this as a side effect. If you also want alerting when the
  *site itself* is down (a different concern from DB idling), point an uptime
  monitor at the app's GitHub Pages URL — that's a separate, unrelated check
  and doesn't need any Supabase credentials.
- **Automated backups now exist** — see "Backups" above. They cover
  `entries`/`evidence`/`profile` plus every evidence file, twice weekly,
  encrypted, retained for the last 12 runs.

## Possible future upgrades (not currently implemented)

- Two-factor authentication (TOTP) on the login account
- Fully private evidence files via signed, expiring URLs instead of a public
  bucket (currently public by deliberate choice — receipts only, no other PII)
- Multiple user accounts with individual permissions — needs a `user_id`
  ownership column + updated RLS policies added *before* a second account is
  created, not after
- More visible handling of partial-failure saves (an entry can save
  successfully while one of its evidence uploads fails, with only a toast
  notification) — not changed in this pass since it alters the save flow's
  error-handling behavior

None of these are required for current use — they're listed here so future
decisions about them are informed choices, not oversights.
