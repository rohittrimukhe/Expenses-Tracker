# LRS Conveyance Claim Tracker

A self-contained web app for logging daily local-conveyance claims and exporting
them as an Excel file matching the original LRS tracker format exactly — with
embedded evidence photos, correct borders/fonts/merges, and cross-linked sheets.
Runs entirely in the browser; all data is stored in Supabase (Postgres + Storage).

## Files in this repo

| File | Purpose |
|---|---|
| `index.html` | The entire app — data entry, dashboard, evidence vault, Excel export |
| `manifest.json` | PWA manifest so the app can be installed to a phone home screen |
| `icon-192.png`, `icon-512.png` | App icons used by the manifest |
| `supabase-setup.sql` | One-time SQL to run in your Supabase project (tables, security policies, storage policies) |
| `SETUP.md` | Full step-by-step setup guide for a fresh copy of this app |
| `DEPLOYMENT.md` | Current configuration, security model, and maintenance notes |

## One-time setup

See [SETUP.md](SETUP.md) for the full walkthrough — create a Supabase
project, run `supabase-setup.sql`, create the evidence Storage bucket, create
your login, point `index.html` at your project, and deploy it.

## Deploying so you can access it from anywhere

Pick whichever is easiest for you — all are free:

- **GitHub Pages** (this repo): Settings → Pages → Deploy from branch → `main` → Save.
  You'll get a URL like `https://yourusername.github.io/repo-name`.
- **Netlify drag-and-drop**: go to netlify.com, drag this folder onto the page — instant live URL, no GitHub needed.
- **Vercel**: connect this GitHub repo at vercel.com for automatic deploys on every push.

The deployed URL is public (anyone with the link can open the page), but your
data itself is gated by sign-in (real Supabase Auth — email + password) and
by Supabase's row-level security rules.

## Using it day to day

- **New Entry**: log a day's travel. Multiple legs of the *same* claim (e.g.
  morning + evening return) → use "+ Add journey leg" so they merge into one
  claim block. A genuinely different trip that day → save as a separate entry.
- **This Month's Claim**: review the month, then **Export to Excel** — builds
  the fully formatted file client-side, including embedded evidence photos.
- **Evidence Vault**: browse/search all uploaded receipts and photos.
- **Dashboard**: totals, entry counts, and a month-by-month breakdown with a
  **Delete month** option — use this once you've been reimbursed for a month,
  to keep well within Supabase's free-tier storage limits.

## Security notes

- The publishable key is safe to expose in client code by design — real
  protection comes from Supabase's Row Level Security rules (already set up
  by `supabase-setup.sql`) and from real Supabase Auth sign-in.
- You're auto-signed-out after 5 minutes of inactivity.
- See `DEPLOYMENT.md` for the full security model, current hardening, and
  backup setup.
