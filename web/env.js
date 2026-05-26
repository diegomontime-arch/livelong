// DEPRECATED — DO NOT add secrets here.
//
// This file used to expose `window.ENV.ANTHROPIC_API_KEY` to the web
// build. That pattern is unsafe because anything in `web/` is publicly
// served by Firebase Hosting — pasting a real key here would leak it
// to every visitor of https://hitlook-app.web.app.
//
// The active path for the educational AI ("Ana") is:
//   chat_screen.dart → AnaProxyConfig → Cloudflare Worker (hitlook-ana-proxy)
// where the Anthropic key lives as a Worker Secret.
//
// Backend fallback: Cloud Function `anthropicProxy` (functions/index.js)
// reads `ANTHROPIC_API_KEY` from Firebase Secret Manager.
//
// See planning/SECURITY.md S13 and planning/FUNCTIONS_AUDIT.md §2.
window.ENV = Object.freeze({});
