# Live Long / HitLook — Segurança

Auditoria realizada em **2026-05-23** sobre:

- `firestore.rules` (369 linhas)
- `storage.rules`
- `functions/index.js`
- `cloudflare/worker.js`
- `lib/firebase_options.dart` e `pubspec.yaml`

Padrão de classificação: 🔴 crítico (corrigir antes do release) ·
🟠 alto (corrigir antes de marketing pago) · 🟡 médio · 🟢 baixo.

---

## 1. Sumário executivo

| Categoria | Status |
|-----------|--------|
| Firestore rules | 🟢 **Robustas.** Whitelist de chaves no create público, scoping por `userData()`, helpers de validação reutilizáveis |
| Storage rules | 🟠 **Minimalistas.** Só protegem `agents/{uid}/photo` |
| Cloud Functions auth | 🔴 `anthropicProxy` aberta com `Access-Control-Allow-Origin: *` |
| Anthropic API key | 🟢 Atrás do Cloudflare Worker, nunca no client |
| Cloudflare Worker auth | 🔴 Aceita qualquer POST de qualquer origem |
| App Check | 🔴 **Não habilitado** |
| Secrets management | 🟠 `functions.config()` (deprecado), migrar para Secret Manager |
| Crash & error reporting | 🟠 Crashlytics não inicializado — sem visibilidade em prod |
| Logs com PII | 🟢 Usa `debugPrint` (removido em release) |
| Hardcoded credentials | 🟢 Nenhuma encontrada no grep |
| OWASP MASVS L1 | ⚠️ Parcial — App Check é o gap principal |

---

## 2. Firestore rules — análise linha a linha

Arquivo `firestore.rules` (369 linhas).

### 2.1 ✅ O que está bom

**Helpers reutilizáveis (L10-89):** `isSignedIn`, `userExists`, `userData`,
`isCompanyMember`, `isCompanyAdmin`, `isHitLookMaster`, `isSellerInCompany`.
Modelo limpo, fácil de auditar.

**Whitelist no create público de lead (L95-131):**

```firestore
function publicLeadAllowedKeys() {
  return ['companyId', 'sellerId', 'status', 'locale', 'lang',
          'answers', 'score', 'prospectName', 'prospectPhone',
          'nome', 'telefone', 'nascimento', 'recommendedPlan',
          'createdAt', 'updatedAt', 'agentId'];
}

function isValidPublicLeadCreate(companyId) {
  ...
  && data.keys().hasOnly(publicLeadAllowedKeys())
  && !('userId' in data)
  && !('role' in data)
  ...
}
```

Excelente — bloqueia escalonamento de privilégio (prospect não pode setar
`role:admin`).

**Score validado:**

```firestore
function optionalScoreValid(data) {
  return !('score' in data)
    || (data.score is int && data.score >= 0 && data.score <= 100);
}
```

**`isHitLookMaster()`** identifica Diego (companyId=hitlook, role=admin)
sem hardcodar UID — bom.

### 2.2 🟠 Problemas

#### S1 — Read de `users/{userId}` para qualquer admin da mesma empresa

`firestore.rules:171-175`:
```
allow read: if isSignedIn() && (
  request.auth.uid == userId
  || (resource.data.companyId != null
      && isCompanyAdmin(resource.data.companyId))
);
```

Hoje só Renan e Diego são admins, então ok. Mas se um dia Renan tiver
sub-admins na M4LIFE, todos vão poder ler `users/{uid}` de **todos** os
agentes M4LIFE incluindo email. Pode ser intencional (admin gerencia
contas), mas vale **documentar** explicitamente.

#### S2 — `match /agents/{agentId}` permite leitura pública de tudo

`firestore.rules:322-323`:
```
match /agents/{agentId} {
  allow read: if true;
```

Hoje o doc `agents/{uid|slug}` tem `nome, bio, fotoUrl, whatsapp, slug`.
Tudo "público" pela natureza do produto.

**Mas:** se um dia um campo PII for adicionado (ex: `emailReal`, `nascimento`
do agente), vira leak público. **Recomendação:** mudar para read whitelist:

```firestore
match /agents/{agentId} {
  allow read: if true;  // qualquer campo
  // OU mais seguro:
  allow get: if true;
  allow list: if false;  // evita scan, força lookup direto por slug/uid
}
```

`list: false` impede que alguém faça `agents.where(...)` para enumerar
todos os agentes. Não há código no app fazendo essa query, então não quebra.

#### S3 — `leads/{leadId}` raiz (legado) permite create sem `sellerId`

`firestore.rules:342-354`:
```
allow create: if request.resource.data.keys().hasOnly([
    'agentId', 'nome', 'telefone', 'nascimento', 'lang',
    'answers', 'score', 'status', 'createdAt',
  ])
  && request.resource.data.status == 'novo'
  && isServerTimestamp('createdAt');
```

**Permite create anônimo** (sem `isSignedIn`). Necessário porque o prospect
não tem conta. Mas:

- Não valida `agentId` existe em `agents/{agentId}` → spam fácil.
- Não tem rate limit.

**Mitigação prática:**

- App Check enforced → bots não conseguem submeter.
- **Validar agentId no rule** (mais custoso, mas viável):
  ```firestore
  && exists(/databases/$(database)/documents/agents/$(request.resource.data.agentId))
  ```

#### S4 — `seller_slugs` create/update aberto a self-link

`firestore.rules:307-316`:
```
allow create, update: if slugWriteValid();
```

`slugWriteValid` exige que o caller seja admin OU seller na company. Mas
seller pode trocar **seu próprio** slug, e como `sellerId == userSellerId()`
isso permite squat de slugs alheios?

Re-leitura: `slugWriteValid` checa `data.companyId is string` e
`data.sellerId is string`, mas **não** valida que o `slug` do doc bate
com o `slug` no path. Vamos validar:

```firestore
function slugWriteValid() {
  let data = request.resource.data;
  return data.companyId is string
    && data.sellerId is string
    && data.slug is string
    && data.slug == slug  // 👈 ADICIONAR — slug variável vem do match path
    && sellerExists(data.companyId, data.sellerId)
    && (...);
}
```

Hoje a regra **não tem** `data.slug == slug`. Significa que um seller
pode criar `seller_slugs/diego-teste` com `slug: 'renan'` dentro do doc.
Não quebra o lookup público (que usa `slug` do path), mas **polui** o
índice. **Fix recomendado.**

#### S5 — `companies/{companyId}` create exige só `isSignedIn`

`firestore.rules:219-232`:
```
allow create: if isSignedIn()
  && request.resource.data.keys().hasOnly([...])
  && ...
```

**Qualquer usuário autenticado** pode criar uma `company`. Isso pode ser
intencional (self-service onboarding futuro), mas hoje:

- Não há UI no app que crie company sem ser admin.
- Significa que um agente com conta poderia criar `companies/foo` via
  ferramentas externas e ficar "isolado" — não dá pra escalar para admin
  de outra empresa, mas suja a coleção.

**Fix:**
```firestore
allow create: if isHitLookMaster();
```

Restringe a Diego. Quando Renan precisar de outro tenant, fala com Diego.

### 2.3 🟡 Médio — outros

- **`mail/{mailId}`** allow `read, write: false` ✅ correto, só Admin SDK.
- **`tenants/{tenantId}`** read público sem `list` controle. Tenants têm
  só branding (não-secreto). Aceitável.
- **`ai_recommendations`** dentro de leads — read só por admin ou seller dono
  via `isLeadSeller`. Bom.

---

## 3. Storage rules — análise

`storage.rules` (9 linhas):

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /agents/{agentId}/photo {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == agentId;
    }
  }
}
```

#### S6 — 🟠 Rules **só protegem `agents/{uid}/photo`**

Tudo fora desse path:

- Sem regra → **negado por padrão** ✅ (rules v2 fail-closed).
- Bom! Mas: se alguém adicionar feature de upload em outro path no app
  (ex: anexo no lead), vai precisar lembrar de atualizar storage.rules.

**Recomendação:** adicionar comentário explícito + bloco "catch-all"
explícito para documentação:

```
match /b/{bucket}/o {
  match /agents/{agentId}/photo {
    allow read: if true;
    allow write: if request.auth != null
      && request.auth.uid == agentId
      && request.resource.size < 5 * 1024 * 1024  // 5 MB max
      && request.resource.contentType.matches('image/.*');
  }

  // Catch-all explícito (mesmo efeito que omitir, mas documenta)
  match /{allPaths=**} {
    allow read, write: if false;
  }
}
```

**Adicionar limite de tamanho** (`request.resource.size`) e tipo
(`contentType.matches('image/.*')`) — hoje qualquer arquivo até 32 MB
default Firebase passa.

---

## 4. Cloud Functions — análise

### S7 — 🔴 `anthropicProxy` aceita qualquer POST anônimo

[`functions/index.js:14-58`](../functions/index.js):

```js
exports.anthropicProxy = functions.https.onRequest((req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  // ... sem auth, sem App Check, sem rate limit
});
```

**Risco:** qualquer pessoa que descobrir
`https://us-central1-hitlook-app.cloudfunctions.net/anthropicProxy` pode
queimar a chave Anthropic. Custo: **ilimitado**.

**Fix imediato (até App Check estar pronto):**

1. **Desativar a função** se já existe o Cloudflare Worker — o app não a usa
   ([`AnaProxyConfig.workerBase`](../lib/core/config/ana_proxy_config.dart)
   aponta para `hitlook-ana-proxy.hitlook.workers.dev`, não para a Cloud
   Function). Confirmar com Diego e **remover** ou comentar em `index.js`.
   🟡 **DECISÃO PENDENTE.**

2. Se a função for mantida, mudar para callable + App Check:
   ```js
   exports.anthropicProxy = onCall(
     { enforceAppCheck: true, region: 'us-central1', secrets: ['ANTHROPIC_API_KEY'] },
     async (request) => {
       if (!request.auth) throw new HttpsError('unauthenticated', 'login required');
       // ...
     }
   );
   ```

### S8 — 🔴 Cloudflare Worker `worker.js` aceita qualquer POST

[`cloudflare/worker.js`](../cloudflare/worker.js):

```js
export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, ...);
    if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    // ... sem validação de origem, sem token
    const response = await fetch('https://api.anthropic.com/v1/messages', { ... });
  }
};
```

**Mesmo risco do S7**, e este é o que está **em produção** ([`AnaProxyConfig`](../lib/core/config/ana_proxy_config.dart)).

**Fixes em ordem de esforço:**

| Esforço | Fix | Eficácia |
|---------|-----|----------|
| 5 min | Validar `request.headers.get('Origin')` contra allowlist (`hitlook-app.web.app`, `localhost:*`) | Bloqueia abuso casual; pode ser forjado por `curl --header "Origin: ..."` |
| 30 min | Exigir header `X-Firebase-AppCheck` válido — verificar com pública do Firebase | Bloqueia clientes não-Firebase |
| 1 dia | Cloudflare Worker chama `firebaseauth.googleapis.com` para validar Firebase ID token e só aceita usuários autenticados | Bloqueia tudo exceto agente logado. **Mas:** prospect não tem login → vai bloquear o público. |
| 1h | Rate limit por IP no Worker (`request.headers.get('CF-Connecting-IP')`) | Limita abuso, mas não bloqueia |

**Estratégia recomendada:** Origin allowlist (rápido) +
rate limit por IP (1 hora). App Check Firebase quando ligar (semana 2).

### S9 — 🟠 `functions.config()` deprecado

[`functions/index.js:29`](../functions/index.js):
```js
const apiKey = functions.config().anthropic?.key;
```

`functions.config()` é deprecado em favor de **Secret Manager** (`secrets`
em Functions v2). Plano em [PRODUCTION.md §F.1](PRODUCTION.md).

### S10 — 🟡 `createSellerAccount` sem App Check

[`functions/index.js:65-95`](../functions/index.js):

```js
exports.createSellerAccount = onCall(
  { region: "us-central1" },
  async (request) => { ... }
);
```

Tem auth check (`request.auth`) e role check (`callerDoc.data().role !== 'admin'`).
Boa primeira camada. Mas:

- Sem `enforceAppCheck: true`.
- Sem rate limit por IP.
- Resposta inclui `uid` do user criado — ok, callable é safe.

**Fix:** adicionar `enforceAppCheck: true` na mesma configuração quando
App Check estiver ativo.

### S11 — 🟢 `notifyAgentOnNewLead` é trigger Firestore

Não exposto externamente. Sem risco direto. Mas:

- `agentId` vem do payload do lead — atacante poderia tentar criar um lead
  com `agentId: 'admin-diego-uid'` para enviar email ao Diego com nome
  falso de prospect. **Mitigado** porque o lead public create já valida
  `sellerId` existir no Firestore (`isValidPublicLeadCreate`), mas o
  schema legado `/leads` não valida.

**Fix:** quando deprecar `/leads` raiz, validar `agentId` exists.

---

## 5. App Check (ausente)

🔴 **Não habilitado** no client nem no console.

Sem App Check:

- Cloud Functions vulneráveis (S7, S10).
- Firestore writes pelo client podem ser feitos por bots se conseguirem
  Auth (criar conta gratuita).
- Storage writes idem.

**Plano detalhado em [PRODUCTION.md §G.1](PRODUCTION.md).**

---

## 6. Secrets e credenciais

### S12 — 🟢 Nenhum secret hardcoded encontrado

Grep em `lib/`:

```bash
grep -rn -E "(sk-|api[_-]?key|password|secret).*=\s*['\"]" lib/
```

Resultado: zero matches relevantes. ✅

`lib/firebase_options.dart` contém apenas chaves Firebase que são **públicas
por design** (rules + App Check protegem o backend).

### S13 — 🟠 `chat_screen.dart` mencionado em docs como "fora do git" não é mais o caso

[`docs/02-CURRENT_STATUS.md`](../docs/02-CURRENT_STATUS.md) diz:
> "chat_screen.dart — API key local, fora do git"

Verificação 2026-05-23: o arquivo **está** no git, e **não contém** API key
(usa `AnaProxyConfig` → Cloudflare Worker). Estado correto. **Atualizar
docs** removendo o aviso desatualizado.

### S14 — 🟠 `.gitignore` e arquivos do Firebase

```bash
$ cat /Users/yurilima/Downloads/projects/livelong/.gitignore | head
```

Validar que `ios/Runner/GoogleService-Info.plist` está versionado (deve estar
— é público) e que `cloudflare/.wrangler/` não vaza estado local.

---

## 7. Logs com PII

### S15 — 🟢 Sem `print` direto encontrado nas telas auditadas

Uso de `debugPrint` é seguro (removido em release).

**Mas:** ao ligar Crashlytics ([PRODUCTION.md §G.3](PRODUCTION.md)),
**não passar PII** (nome, telefone, email) como `setUserIdentifier`. Usar só
UID Firebase (hash interno do Firebase, não PII).

---

## 8. OWASP MASVS (Mobile Application Security Verification Standard)

Para iOS:

| Categoria | Status Live Long |
|-----------|------------------|
| MASVS-STORAGE — Não armazenar PII em plaintext local | 🟢 `image_picker` cria temp file; `cloud_firestore` cache é controlado pelo SDK. App **não usa** `shared_preferences` em código auditado (vs Whenote que usa para drafts). |
| MASVS-CRYPTO | 🟢 N/A (sem cripto custom). |
| MASVS-AUTH — sessões | 🟡 Firebase Auth gerencia. Cuidar de `signOut()` em rotas críticas — `agent_dashboard_screen` faz `logout` ok. |
| MASVS-NETWORK — TLS | 🟢 Tudo HTTPS. Sem cert pinning, mas Firebase + Anthropic estão sob CDNs auditados. |
| MASVS-PLATFORM — webview etc | 🟢 N/A. |
| MASVS-CODE — anti-tampering | 🔴 Sem App Check / Play Integrity / DeviceCheck. Ver §5. |
| MASVS-RESILIENCE — runtime | 🟡 Sem detecção de jailbreak. Aceitável para B2B SaaS. |

---

## 9. Checklist de ação antes do release

- [ ] **🔴 S7/S8 — Decidir entre desativar `anthropicProxy` Cloud Function
      OU adicionar Origin allowlist + rate limit no Cloudflare Worker.**
      Diego decide. *Bloqueia o release seguro.*
- [ ] **🔴 App Check em modo monitor** (PRODUCTION.md §G.1) — 1 dia.
- [ ] **🟠 S6 — Hardening do `storage.rules`** (limite de tamanho/tipo) — 5 min.
- [ ] **🟠 S4 — Adicionar `data.slug == slug` em `slugWriteValid()`** — 1 min.
- [ ] **🟠 S9 — Migrar `functions.config()` para Secret Manager** — 30 min.
- [ ] **🟠 S5 — Restringir `companies` create a `isHitLookMaster()`** — 1 min.
- [ ] **🟠 Crashlytics inicializado** — 1h.
- [ ] **🟡 Atualizar `docs/02-CURRENT_STATUS.md`** removendo o "chat_screen.dart fora do git" — 2 min.

---

*Última atualização: 2026-05-23.*
