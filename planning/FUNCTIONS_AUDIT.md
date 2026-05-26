# Live Long / HitLook — Auditoria de Cloud Functions

Arquivos auditados em **2026-05-23**:

- [`functions/index.js`](../functions/index.js) (~185 linhas)
- [`functions/package.json`](../functions/package.json)
- [`cloudflare/worker.js`](../cloudflare/worker.js) (Cloudflare Worker, não
  Firebase Function — mas tem o mesmo papel da Ana)

---

## 1. Funções existentes

| Nome | Tipo | Região | Status | Comentário |
|------|------|--------|--------|------------|
| `anthropicProxy` | `https.onRequest` | default | ⚠️ não utilizada pelo app | Em uso? Confirmar com Diego |
| `createSellerAccount` | `onCall` v2 | `us-central1` | ✅ Em uso pelo admin (Renan/Diego) | Cria Firebase Auth user via Admin SDK |
| `notifyAgentOnNewLead` | `onDocumentCreated` v2 | `us-central1` | ✅ Em uso | Trigger sobre `leads/{leadId}` raiz |

E no Cloudflare:

- `worker.js` — proxy Anthropic (em uso real para Ana via
  `AnaProxyConfig.workerBase`).

---

## 2. `anthropicProxy` — Cloud Function

[`functions/index.js:14-58`](../functions/index.js)

### 2.1 Problemas

| # | Problema | Severidade |
|---|----------|-----------|
| F1 | Endpoint público, **sem autenticação**, `Access-Control-Allow-Origin: *` | 🔴 Crítico |
| F2 | `functions.config().anthropic?.key` — Functions Config **deprecado** | 🟠 Alto |
| F3 | Sem rate limit | 🟠 Alto |
| F4 | Sem App Check | 🔴 Crítico |
| F5 | Sem logging estruturado (não loga origem, IP, modelo solicitado) | 🟡 Médio |
| F6 | Sem validação do body (`req.body` direto passado para Anthropic) | 🟡 Médio |

### 2.2 Status real

Existem **três caminhos** declarados para chamar Anthropic — apenas **um**
está ativo:

| Caminho | Arquivo | Status |
|---------|---------|--------|
| Cloudflare Worker `hitlook-ana-proxy` | [`lib/legacy/screens/chat_screen.dart`](../lib/legacy/screens/chat_screen.dart) → [`AnaProxyConfig`](../lib/core/config/ana_proxy_config.dart) | ✅ **ATIVO** (em produção) |
| Firebase Hosting rewrite `/api/anthropic/**` | [`firebase.json:11-13`](../firebase.json) → consumido por [`HttpAiCompletionService`](../lib/services/ai/ai_completion_service.dart) via [`AppConfig.anthropicProxyUrl`](../lib/core/config/app_config.dart) | ⚠️ **DEAD CODE** — `HttpAiCompletionService` só é referenciado pelo `FirebaseAiRecommendationRepository` que **não é instanciado em lugar algum**. O rewrite Hosting para URL externa provavelmente nem funciona (Firebase Hosting `destination` é para mesma origem; proxy externo precisa de `function` ou `run`) |
| Cloud Function `anthropicProxy` | [`functions/index.js:14-58`](../functions/index.js) | ⚠️ **DEPLOYADA mas órfã** — nenhum caminho do client a invoca |

Verificação executada em 2026-05-23:

```bash
grep -rn "anthropicProxy" /Users/yurilima/Downloads/projects/livelong/lib/
# lib/core/config/app_config.dart:10  → AppConfig.anthropicProxyUrl (dead)
# lib/services/ai/ai_completion_service.dart:21 → usa AppConfig.anthropicProxyUrl (dead)
```

E `HttpAiCompletionService` só aparece em
`firebase_ai_recommendation_repository.dart:15` como default param —
repositório que **não é instanciado** em nenhuma feature, controller ou
route guard.

### 2.3 Decisão necessária

🟡 **DECISÃO PENDENTE — Diego:**

- [ ] **Opção A:** Remover `anthropicProxy` de `functions/index.js`. Diminui
      superfície de ataque. Custo: 1 commit.
- [ ] **Opção B:** Manter, mas transformar em `onCall` + `enforceAppCheck`
      + Secret Manager + rate limit. Mantém redundância caso Cloudflare
      Worker falhe.

Recomendação: **Opção A**. Se Cloudflare Worker falhar, é mais rápido
re-deploy do worker do que reativar a função.

---

## 3. `createSellerAccount` — Cloud Function

[`functions/index.js:65-95`](../functions/index.js)

### 3.1 ✅ O que está bom

- Verifica `request.auth` antes de qualquer ação.
- Lê `users/{caller.uid}` e checa `role === 'admin'` — **defense in depth**
  (mesmo se rules falharem, function bloqueia).
- Usa Admin SDK `admin.auth().createUser` — única forma legítima de criar
  conta sem pedir senha do usuário final.
- Trata erros e loga via `logger`.

### 3.2 ⚠️ Problemas

| # | Problema | Severidade |
|---|----------|-----------|
| F7 | Sem `enforceAppCheck: true` | 🟠 Alto |
| F8 | `password` recebido no payload — atacante autenticado como admin pode criar contas com senhas fracas (não há `password.length >= 8` check) | 🟡 Médio |
| F9 | Sem rate limit — admin comprometido pode criar 1000 contas em segundos | 🟡 Médio |
| F10 | Não cria documento `users/{newUid}` nem `companies/{cid}/sellers/{sid}` — fica para o client (`create_seller_service.dart`) fazer | 🟡 Médio — race condition entre create user e create profile |
| F11 | Resposta inclui `uid` em texto puro nos logs (`logger.info("createSellerAccount OK", { uid })`) — ok, mas registrar UID de admin pode dificultar auditoria | 🟢 Baixo |

### 3.3 Recomendações

```js
exports.createSellerAccount = onCall(
  {
    region: "us-central1",
    enforceAppCheck: true,                   // F7
    consumeAppCheckToken: true,
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

    const callerDoc = await db.collection("users").doc(request.auth.uid).get();
    if (!callerDoc.exists || callerDoc.data().role !== "admin") {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const { email, password, displayName, companyId } = request.data || {};
    if (!email || !password || !displayName || !companyId) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    if (String(password).length < 12) {                                // F8
      throw new HttpsError("invalid-argument", "Password too short");
    }

    // F10 — transação: cria auth + documento users em uma operação atômica
    let createdUid = null;
    try {
      const user = await admin.auth().createUser({
        email: String(email).trim(),
        password: String(password),
        displayName: String(displayName).trim(),
      });
      createdUid = user.uid;

      await db.collection("users").doc(user.uid).set({
        email: String(email).trim(),
        displayName: String(displayName).trim(),
        companyId,
        role: "seller",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("createSellerAccount OK", { uid: user.uid, companyId });
      return { uid: user.uid };
    } catch (e) {
      // F10 — se Firestore falhar, deletar o user Auth para evitar órfão
      if (createdUid) {
        await admin.auth().deleteUser(createdUid).catch(() => {});
      }
      logger.error("createSellerAccount failed", e);
      throw new HttpsError("internal", e.message || "Failed to create user");
    }
  },
);
```

Trade-off do snippet acima: a transação Auth+Firestore **não é atômica**
nativamente (Auth é fora do Firestore). Compensação: rollback manual via
`deleteUser` em catch.

---

## 4. `notifyAgentOnNewLead` — Trigger Firestore

[`functions/index.js:100-148`](../functions/index.js)

### 4.1 ✅ O que está bom

- Trigger no schema legado (`leads/{leadId}` raiz) — sempre dispara, pois o
  duplo write garante que **todo** lead grava aqui ([ARCHITECTURE.md §2.1](ARCHITECTURE.md)).
- `resolveAgentEmail(agentId)` tenta 3 caminhos (users, agents, Firebase Auth).
- HTML escapado via `escapeHtml`.
- Enfileira no `mail/{mailId}` (Trigger Email extension) — não envia direto.

### 4.2 ⚠️ Problemas

| # | Problema | Severidade |
|---|----------|-----------|
| F12 | `resolveAgentEmail` faz **3 reads** para cada lead — em volume alto, custo significativo | 🟢 Baixo (ok para 1k leads/mês) |
| F13 | Se Trigger Email extension não estiver instalada/configurada, lead é criado mas email **silenciosamente** falha | 🟠 Alto |
| F14 | Conteúdo do email tem `https://hitlook-app.web.app/dashboard` hardcoded | 🟢 Baixo |
| F15 | Não traduz para idioma do agente (sempre PT) — agente latino que prefere ES recebe email em PT | 🟡 Médio |
| F16 | Quando schema duplo for deprecado e `/leads` raiz sumir, trigger **para de funcionar** | 🟠 Alto — planejar com [ARCHITECTURE.md §2.1](ARCHITECTURE.md) |

### 4.3 Recomendações

#### F13 — Validar Trigger Email instalado

No console Firebase → Extensions → confirmar que **`firestore-send-email`**
está instalado, configurado com SMTP (SendGrid, Google Workspace, etc.), e
apontando para coleção `mail`.

Whenote migrou para **Google Workspace SMTP Relay**
([`OpenWhen/planning/PRODUCTION.md`](../../OpenWhen/planning/PRODUCTION.md)
seção "Email de autenticação"). Limite: ~2000 emails/dia. Suficiente para
o piloto Live Long (esperado < 100 emails/dia v1).

#### F16 — Plano de migração

Quando deprecar `/leads` raiz:

1. Criar nova trigger `notifyAgentOnNewLeadV2` em
   `companies/{companyId}/leads/{leadId}`.
2. Manter **as duas** triggers durante a transição (não envia email
   duplicado se duplo write parar).
3. Após confirmar V2 funciona, deletar V1.

#### F15 — Localização do email

Estado atual (PT only). Mas o app já é PT/ES/EN — incoerente. Sugestão:

```js
const lang = lead.lang || 'pt';
const SUBJECT_BY_LANG = {
  pt: `Novo lead HitLook: ${nome}`,
  es: `Nuevo lead HitLook: ${nome}`,
  en: `New HitLook lead: ${nome}`,
};
const subject = SUBJECT_BY_LANG[lang] || SUBJECT_BY_LANG.pt;
```

Olhar nos próprios dados do lead (`lang`) ou no doc do agente
(`sellers.idioma`).

---

## 5. Cloudflare Worker — `worker.js`

[`cloudflare/worker.js`](../cloudflare/worker.js)

### 5.1 Estado

- ~40 linhas.
- Recebe POST → encaminha para `https://api.anthropic.com/v1/messages` com
  header `x-api-key: env.ANTHROPIC_API_KEY`.
- CORS `*`.

### 5.2 Problemas

| # | Problema | Severidade |
|---|----------|-----------|
| F17 | CORS `*` + sem auth = público | 🔴 Crítico (ver [SECURITY.md §S8](SECURITY.md)) |
| F18 | Sem rate limit por IP | 🔴 Crítico |
| F19 | Sem timeout configurado — espera Anthropic indefinidamente | 🟡 Médio |
| F20 | `wrangler.toml` — só 80 bytes de config; provavelmente faltando ambiente production vs dev | 🟢 Baixo |

### 5.3 Fix mínimo (≤ 1 hora)

```js
// cloudflare/worker.js
const ALLOWED_ORIGINS = new Set([
  'https://hitlook-app.web.app',
  'https://livelong.com',          // se aplicar
  'http://localhost:8080',
]);

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const corsOrigin = ALLOWED_ORIGINS.has(origin) ? origin : 'null';

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders(corsOrigin) });
    }

    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405, headers: corsHeaders(corsOrigin) });
    }

    // Rate limit simples via Cloudflare KV (ou Durable Object para 1 req/s/IP).
    // V1: bloquear se origin não estiver na allowlist
    if (!ALLOWED_ORIGINS.has(origin)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: corsHeaders('null'),
      });
    }

    let body;
    try { body = await request.json(); }
    catch { return jsonError('Invalid JSON body', 400, corsOrigin); }

    if (!env.ANTHROPIC_API_KEY) return jsonError('Not configured', 500, corsOrigin);

    // Timeout 30s
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 30_000);

    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      const text = await response.text();
      return new Response(text, { status: response.status, headers: corsHeaders(corsOrigin) });
    } finally {
      clearTimeout(t);
    }
  },
};

function corsHeaders(origin) {
  return {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Firebase-AppCheck',
    'Vary': 'Origin',
  };
}

function jsonError(message, status, origin) {
  return new Response(JSON.stringify({ error: message }), {
    status, headers: corsHeaders(origin),
  });
}
```

**Próximo passo (semana 2):** validar `X-Firebase-AppCheck` header — exige
ler `https://firebaseappcheck.googleapis.com/v1/projects/hitlook-app/...`.
Documentação:
https://firebase.google.com/docs/app-check/custom-resource-backend#cloudflare-worker

---

## 6. Custos estimados (Cloud Functions)

Free tier mensal (Blaze):

- 2M invocations
- 400k GB-seconds
- 200k CPU-seconds

Para 1k leads/mês:

- `notifyAgentOnNewLead` × 1k = 1k invocations.
- `createSellerAccount` × ~10 = ~10 invocations.
- `anthropicProxy` × 0 (não usada).

**Total:** muito abaixo do free tier. **$0.00** previsto.

Cloudflare Worker free tier: 100k requests/dia. Com 1k leads/mês e 5
mensagens médias por lead → 5k requests/mês. **$0.00**.

---

## 7. Checklist antes do release

- [ ] **F1/F4 — Decidir destino de `anthropicProxy`** (remover ou
      proteger). 🟡 Diego.
- [ ] **F17 — Worker Cloudflare com Origin allowlist deployada.**
- [ ] **F7 — Adicionar `enforceAppCheck: true` em `createSellerAccount`**
      quando App Check estiver ativo.
- [ ] **F13 — Confirmar Trigger Email extension instalada e funcionando.**
      Teste: criar lead → esperar < 1 min → email no inbox do agente.
- [ ] **F2/F9 — Migrar `functions.config()` para Secret Manager.**
- [ ] **F15 — Localizar emails (PT/ES/EN).**
- [ ] **F16 — Plano de migração V1 → V2 da trigger documentado** quando
      deprecar `/leads` raiz.

---

*Última atualização: 2026-05-23.*
