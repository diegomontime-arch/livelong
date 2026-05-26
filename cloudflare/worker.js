// Cloudflare Worker — proxy para a Anthropic Messages API consumida pela
// "Ana" (assistente educacional do HitLook).
//
// Segurança (planning/SECURITY.md S8 e planning/FUNCTIONS_AUDIT.md §5):
//   - Origin allowlist (rejeita POST de origens desconhecidas).
//   - Timeout 30s para evitar pendurar conexões.
//   - Headers CORS coerentes com Vary: Origin.
//   - Logging mínimo (sem PII) para audit em caso de incidente.
//
// Próximo passo (semana 2): validar header X-Firebase-AppCheck quando o
// App Check estiver em modo enforced. Documentação:
// https://firebase.google.com/docs/app-check/custom-resource-backend

const ALLOWED_ORIGINS = new Set([
  'https://hitlook-app.web.app',
  'https://hitlook-app.firebaseapp.com',
  // Dev / local — remover quando não for mais necessário.
  'http://localhost:8080',
  'http://localhost:3000',
]);

const UPSTREAM = 'https://api.anthropic.com/v1/messages';
const UPSTREAM_TIMEOUT_MS = 30_000;

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const corsOrigin = ALLOWED_ORIGINS.has(origin) ? origin : 'null';

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders(corsOrigin) });
    }

    if (request.method !== 'POST') {
      return new Response('Method not allowed', {
        status: 405,
        headers: corsHeaders(corsOrigin),
      });
    }

    if (!ALLOWED_ORIGINS.has(origin)) {
      console.log(JSON.stringify({ event: 'origin_rejected', origin }));
      return jsonError('Forbidden', 403, corsOrigin);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return jsonError('Invalid JSON body', 400, corsOrigin);
    }

    if (!env.ANTHROPIC_API_KEY) {
      console.log(JSON.stringify({ event: 'not_configured' }));
      return jsonError('Service not configured', 500, corsOrigin);
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

    try {
      const upstream = await fetch(UPSTREAM, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      const text = await upstream.text();
      return new Response(text, {
        status: upstream.status,
        headers: corsHeaders(corsOrigin),
      });
    } catch (err) {
      const aborted = err && err.name === 'AbortError';
      console.log(
        JSON.stringify({
          event: aborted ? 'upstream_timeout' : 'upstream_error',
          message: err && err.message,
        }),
      );
      return jsonError(
        aborted ? 'Upstream timeout' : 'Upstream error',
        aborted ? 504 : 502,
        corsOrigin,
      );
    } finally {
      clearTimeout(timer);
    }
  },
};

function corsHeaders(origin) {
  return {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Firebase-AppCheck',
    Vary: 'Origin',
  };
}

function jsonError(message, status, origin) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: corsHeaders(origin),
  });
}
