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
| `supabase-setup.sql` | Full schema + security setup, for a fresh project |
| `supabase-auth-upgrade.sql` | Already applied to the live project — kept for reference |

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
  automatically. Resume it from the Supabase dashboard, or set up a free
  uptime monitor (e.g. UptimeRobot) pinging the project periodically to avoid
  this.
- **No automated backups exist on the free tier.** There isn't a scheduled
  backup job configured. If this data becomes important enough to protect
  against accidental loss, that's worth setting up before it's needed, not
  after.

## Possible future upgrades (not currently implemented)

- Two-factor authentication (TOTP) on the login account
- Fully private evidence files via signed, expiring URLs instead of a public
  bucket
- Automated database backups
- Multiple user accounts with individual permissions

None of these are required for current use — they're listed here so future
decisions about them are informed choices, not oversights.
