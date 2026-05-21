#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== HitLook Ana proxy — Cloudflare Worker ==="
echo "Requires: wrangler login (once)"
echo ""

if ! command -v wrangler >/dev/null 2>&1; then
  echo "Installing wrangler..."
  npm install -g wrangler
fi

wrangler deploy

echo ""
echo "Set the API key secret (paste when prompted — never commit it):"
echo "  wrangler secret put ANTHROPIC_API_KEY"
echo ""
echo "Then update lib/core/config/ana_proxy_config.dart with:"
echo "  https://hitlook-ana-proxy.<your-subdomain>.workers.dev/v1/messages"
echo ""
echo "Finally: cd .. && ./save.sh \"chore: update ana proxy URL\""
