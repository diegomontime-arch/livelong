#!/bin/bash
# Firebase Storage CORS — required for Flutter Web upload + Image.network.
# Run once (needs Google Cloud SDK: gcloud or gsutil):
#   ./scripts/deploy_storage_cors.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUCKET="gs://hitlook-app.firebasestorage.app"
CORS_FILE="$ROOT/storage-cors.json"

BUCKET_NAME="${BUCKET#gs://}"

apply_via_api() {
  local token
  token=$(node -e "
    const fs = require('fs');
    const os = require('os');
    const p = os.homedir() + '/.config/configstore/firebase-tools.json';
    const j = JSON.parse(fs.readFileSync(p, 'utf8'));
    if (!j.tokens?.access_token) process.exit(1);
    process.stdout.write(j.tokens.access_token);
  " 2>/dev/null) || return 1
  local body
  body=$(node -e "
    const fs = require('fs');
    const cors = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    process.stdout.write(JSON.stringify({ cors }));
  " "$CORS_FILE")
  curl -sf -X PATCH \
    "https://storage.googleapis.com/storage/v1/b/${BUCKET_NAME}?fields=cors" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "$body" >/dev/null
}

if command -v gcloud >/dev/null 2>&1 && gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q .; then
  echo "Applying CORS via gcloud to $BUCKET ..."
  gcloud storage buckets update "$BUCKET" --cors-file="$CORS_FILE"
elif command -v gsutil >/dev/null 2>&1 && gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q .; then
  echo "Applying CORS via gsutil to $BUCKET ..."
  gsutil cors set "$CORS_FILE" "$BUCKET"
elif apply_via_api; then
  echo "Applied CORS via Storage API (Firebase CLI token)."
else
  echo "Run: gcloud auth login && gcloud config set project hitlook-app"
  echo "Or: firebase login --reauth"
  exit 1
fi

echo "Done. CORS applied to $BUCKET"
