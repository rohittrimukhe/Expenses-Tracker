#!/usr/bin/env bash
# Weekly encrypted backup: entries + evidence metadata + profile (as JSON) plus
# every evidence file, packaged into one archive and encrypted before it ever
# touches the git working tree. Run by .github/workflows/backup.yml.
set -euo pipefail

SUPABASE_URL="https://vrooofaraqancenuzuzz.supabase.co"
EVIDENCE_BUCKET="evidence"
RETAIN=12

: "${SUPABASE_SERVICE_ROLE_KEY:?Missing SUPABASE_SERVICE_ROLE_KEY secret}"
: "${BACKUP_PASSPHRASE:?Missing BACKUP_PASSPHRASE secret}"

STAMP=$(date -u +%Y-%m-%d)
WORKDIR=$(mktemp -d)
DATADIR="$WORKDIR/data"
FILESDIR="$WORKDIR/files"
mkdir -p "$DATADIR" "$FILESDIR"

echo "Fetching tables..."
for TABLE in entries evidence profile; do
  curl -sf "$SUPABASE_URL/rest/v1/$TABLE?select=*" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -o "$DATADIR/$TABLE.json"
done

echo "Downloading evidence files..."
jq -r '.[].storage_path // empty' "$DATADIR/evidence.json" | while read -r STORAGE_PATH; do
  [ -z "$STORAGE_PATH" ] && continue
  DEST="$FILESDIR/$STORAGE_PATH"
  mkdir -p "$(dirname "$DEST")"
  curl -sf "$SUPABASE_URL/storage/v1/object/public/$EVIDENCE_BUCKET/$STORAGE_PATH" -o "$DEST" \
    || echo "warn: failed to fetch $STORAGE_PATH"
done

echo "Archiving..."
ARCHIVE="$WORKDIR/backup-$STAMP.tar.gz"
tar -czf "$ARCHIVE" -C "$WORKDIR" data files

echo "Encrypting (AES-256, PBKDF2, 300000 iterations)..."
mkdir -p backups
ENC_OUT="backups/backup-$STAMP.tar.gz.enc"
openssl enc -aes-256-cbc -pbkdf2 -iter 300000 -salt \
  -in "$ARCHIVE" -out "$ENC_OUT" -pass env:BACKUP_PASSPHRASE

rm -rf "$WORKDIR"

echo "Pruning old backups (keeping last $RETAIN)..."
ls -1t backups/backup-*.tar.gz.enc | tail -n +"$((RETAIN + 1))" | xargs -r rm -f

echo "Done: $ENC_OUT"
