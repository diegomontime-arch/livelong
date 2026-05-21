# HitLook Ana — Cloudflare Worker (Anthropic proxy)

Proxies `POST /v1/messages` to Anthropic with CORS headers for the Flutter web app.

## Setup

```bash
npm install -g wrangler
cd cloudflare
wrangler login
wrangler deploy
wrangler secret put ANTHROPIC_API_KEY   # paste key when prompted — never commit it
```

Worker URL: `https://hitlook-ana-proxy.<your-subdomain>.workers.dev`

Update `lib/legacy/screens/chat_screen.dart` with that URL (no `x-api-key` in Flutter).
