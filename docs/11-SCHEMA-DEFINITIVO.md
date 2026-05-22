# 11 — Schema Firestore definitivo (HitLook)

Documento único de referência para coleções, campos, sincronização e fluxos críticos.  
Projeto: `hitlook-app` · App: https://hitlook-app.web.app

---

## 1. Visão geral

O HitLook usa **dois trilhos** de dados que convivem:

| Trilho | Uso | Coleções |
|--------|-----|----------|
| **SaaS (fonte da verdade)** | Admin, link público `/a/{slug}`, leads novos | `users`, `companies`, `sellers`, `seller_slugs`, `companies/.../leads` |
| **Legado (espelho + dashboard antigo)** | Perfil do agente, painel `/dashboard`, email de lead | `agents`, `leads` (raiz) |

Regra: **toda escrita de perfil do agente** deve atualizar **seller + agents/{uid} + agents/{slug}** (ver `agent_setup_screen._syncSellerAndPublicSlug` e `create_seller_service._writeUserAndAgents`).

---

## 2. Hierarquia e rotas

```
tenants/{tenantId}                    ← branding (leitura pública)
companies/{companyId}                 ← conta B2B (ex: m4life)
  └── sellers/{sellerId}              ← agente (ex: diego-teste, renan)
  └── leads/{leadId}                  ← lead qualificado (SaaS)
        └── ai_recommendations/{id}   ← recomendação IA (opcional)

seller_slugs/{slug}                   ← índice público → companyId + sellerId

users/{uid}                           ← Auth + role + vínculo empresa/seller

agents/{docId}                        ← espelho legado (docId = uid OU slug)

leads/{leadId}                        ← lead legado (agentId = Auth UID)

mail/{mailId}                         ← fila Trigger Email (somente Cloud Functions)
```

**Storage:** `agents/{uid}/photo` — foto do agente (leitura pública, escrita só pelo dono `uid`).

---

## 3. Coleções — campos exatos

### 3.1 `tenants/{tenantId}`

| Campo | Tipo | Obrigatório | Notas |
|-------|------|-------------|-------|
| `name` | string | sim | Nome da marca (ex: M4LIFE) |
| `logoUrl` | string | não | URL do logo |
| `primaryColorHex` | string | não | Cor primária |
| `isActive` | bool | não | default `true` |

**Escrita:** apenas Admin SDK / console (rules: `write: false`).

---

### 3.2 `companies/{companyId}`

| Campo | Tipo | Obrigatório | Notas |
|-------|------|-------------|-------|
| `tenantId` | string | sim | ex: `m4life` |
| `name` | string | sim | ex: `M4LIFE USA` |
| `plan` | string | sim | `starter` \| `growth` \| `enterprise` |
| `isActive` | bool | não | |
| `createdAt` | timestamp | sim (create) | server timestamp |
| `updatedAt` | timestamp | sim (create/update) | server timestamp |

**Leitura:** membros da empresa ou HitLook master (`companyId == hitlook`).

---

### 3.3 `companies/{companyId}/sellers/{sellerId}`

Documento **canônico** do agente no SaaS. ID do doc = `sellerId` (ex: `diego-teste`, `renan`).

| Campo | Tipo | Obrigatório | Notas |
|-------|------|-------------|-------|
| `companyId` | string | sim | Redundante no path; deve bater |
| `displayName` | string | sim | Nome no card público |
| `slug` | string | sim* | URL pública; deve = `sellerId` na prática |
| `userId` | string | sim* | Firebase Auth UID do agente |
| `email` | string | não | |
| `phone` | string | não | WhatsApp (legado: `whatsapp` só em `agents`) |
| `photoUrl` | string | não | URL Storage; sincronizar com `agents.fotoUrl` |
| `bio` | string | não | |
| `isActive` | bool | não | default `true` |
| `idioma` | string | não | `pt` \| `es` \| `en` |
| `nicho` | string | não | `seguro`, `pisos`, `solar`, `mortgage` |
| `instagramUrl` | string | não | |
| `linkedinUrl` | string | não | |
| `createdAt` | timestamp | não | |
| `updatedAt` | timestamp | não | |

\*Obrigatório para agente ativo com link público e login.

**Leitura pública:** `get` permitido para todos (card `/a/{slug}`).

**Sincronizar com:** `seller_slugs/{slug}`, `agents/{userId}`, `agents/{slug}`, `users/{uid}.sellerId`.

---

### 3.4 `seller_slugs/{slug}`

Índice para resolver `/a/diego-teste` sem autenticação.

| Campo | Tipo | Obrigatório | Notas |
|-------|------|-------------|-------|
| `companyId` | string | sim | |
| `sellerId` | string | sim | |
| `slug` | string | sim (write) | Deve ser igual ao doc ID |

**Leitura pública:** `get: true`.

**Criado/atualizado por:** `FirebaseSellerRepository._upsertSlugIndex`, seeds, admin.

---

### 3.5 `users/{uid}`

| Campo | Tipo | Obrigatório | Notas |
|-------|------|-------------|-------|
| `email` | string | sim | |
| `displayName` | string | não | |
| `role` | string | sim | `seller` \| `admin` |
| `companyId` | string | sim* | |
| `sellerId` | string | sim* | |
| `tenantId` | string | não | |
| `createdAt` | timestamp | sim (create) | |
| `updatedAt` | timestamp | sim (create/update) | |

\*Obrigatório para `role: seller`.

**Leitura:** só o próprio usuário ou admin da empresa (não anônimo).

---

### 3.6 `agents/{agentId}`

Espelho legado para perfil público e dashboard. **Dois documentos por agente:**

| docId | Propósito |
|-------|-----------|
| `{firebaseAuthUid}` | Dono do perfil; regras `auth.uid == agentId` |
| `{slug}` | Espelho para leitura em `/a/{slug}`; `userId` no doc |

| Campo | Tipo | Obrigatório | Notas |
|-------|------|-------------|-------|
| `userId` | string | sim* | UID dono (no doc `{slug}`) |
| `slug` | string | não | Slug público |
| `nome` | string | sim* | = `displayName` do seller |
| `bio` | string | não | |
| `whatsapp` | string | não | = `phone` do seller |
| `fotoUrl` | string | não | = `photoUrl` do seller |
| `photoUrl` | string | não | Alias aceito no código |
| `idioma` | string | não | |
| `nicho` | string | não | |
| `instagramUrl` | string | não | |
| `linkedinUrl` | string | não | |
| `updatedAt` | timestamp | não | |

**Leitura pública:** `read: true` (todos os campos).

**Foto real:** arquivo em Storage `agents/{userId}/photo` (não o doc `{slug}`).

---

### 3.7 `companies/{companyId}/leads/{leadId}`

Lead qualificado (fluxo novo).

| Campo | Tipo | Obrigatório | Notas |
|-------|------|-------------|-------|
| `companyId` | string | sim | |
| `sellerId` | string | sim | |
| `status` | string | sim | `new` ou `novo` no create público |
| `nome` | string | não* | Nome do prospect |
| `telefone` | string | não* | |
| `prospectName` | string | não | Alias de `nome` |
| `prospectPhone` | string | não | Alias de `telefone` |
| `nascimento` | string | não | |
| `lang` | string | não | |
| `locale` | string | não | |
| `answers` | map | não | Respostas do questionário |
| `score` | int | não | 0–100 |
| `agentId` | string | não | UID do agente (legado no payload) |
| `recommendedPlan` | string | não | |
| `createdAt` | timestamp | sim (create) | |
| `updatedAt` | timestamp | sim (create) | |

\*Preenchidos pelo formulário em `result_screen._saveLead`.

**Status no app:** também `contacted`, `follow_up`, `closed`, `lost` (repositório).

---

### 3.8 `leads/{leadId}` (raiz — legado)

| Campo | Tipo | Obrigatório | Notas |
|-------|------|-------------|-------|
| `agentId` | string | sim | Firebase Auth UID |
| `nome` | string | sim | |
| `telefone` | string | sim | |
| `nascimento` | string | não | |
| `lang` | string | não | |
| `answers` | map | não | |
| `score` | int | não | |
| `status` | string | sim | `novo` no create |
| `createdAt` | timestamp | sim | |

**Leitura:** só agente com `agentId == auth.uid` (dashboard legado).

**Sempre gravado** em `result_screen` (mesmo quando existe lead SaaS).

---

### 3.9 `companies/.../leads/.../ai_recommendations/{id}`

| Campo | Tipo | Obrigatório |
|-------|------|-------------|
| `companyId` | string | sim |
| `leadId` | string | sim |
| `sellerId` | string | sim |
| `summary` | string | sim |
| `recommendedPlan` | string | não |
| `score` | int | não |
| `locale` | string | não |
| `rawResponse` | string | não |

---

### 3.10 `mail/{mailId}`

Fila da extensão Trigger Email. Cliente não escreve.

---

## 4. Campos sincronizados (obrigatório manter alinhados)

| Conceito | Fonte da verdade | Espelhos |
|----------|------------------|----------|
| Nome exibido | `sellers.displayName` | `agents/{uid}.nome`, `agents/{slug}.nome` |
| Foto URL | `sellers.photoUrl` | `agents/{uid}.fotoUrl`, `agents/{slug}.fotoUrl` |
| Foto arquivo | Storage `agents/{uid}/photo` | — |
| WhatsApp | `sellers.phone` | `agents/{uid}.whatsapp` |
| Slug URL | `sellers.slug` | `seller_slugs/{slug}`, `agents.{slug}`, `agents/{slug}.slug` |
| UID dono | `sellers.userId` | `users/{uid}`, `agents/{uid}.userId`, `agents/{slug}.userId` |
| Vínculo SaaS | `users.companyId` + `users.sellerId` | paths em `companies/.../sellers/...` |

**Ao salvar perfil (`/perfil`):** `agent_setup_screen` atualiza `agents/{uid}`, seller, `agents/{slug}`.

**Ao criar agente (admin):** `create_seller_service` cria `users`, seller, `seller_slugs`, `agents/{uid}`, `agents/{slug}`.

---

## 5. `AgentProvider.loadAgent()` — resolução do slug até a foto

Entrada: `agentId` = segmento da URL (`diego-teste`, `renan`, ou Firebase UID).

### Link público `/a/{slug}` — 3 passos

```
PASSO 1 — Índice + seller (fonte da verdade)
  seller_slugs/{slug}
    → companyId, sellerId
  companies/{companyId}/sellers/{sellerId}
    → displayName, photoUrl, userId, phone, bio, ...

PASSO 2 — Perfil legado (foto e overrides)
  agents/{userId}
    → fotoUrl, nome, whatsapp (prioridade se preenchidos)

PASSO 3 — Merge + contexto público
  - nome  := displayName | agents.nome | formatSlug(slug)
  - fotoUrl := photoUrl | agents.fotoUrl
  - userId := seller.userId  → Storage agents/{userId}/photo
  - id := slug (nunca UID na UI do card)
```

**Exibição da foto na web:** `AgentProfilePhoto` usa `storageUid` → `getData(agents/{userId}/photo)` (evita CORS de `Image.network`).

### UID na URL `/a/{uid}`

Mesmos 3 passos, começando por `agents/{uid}` e opcionalmente `seller_slugs` via campo `slug` no doc.

### Fallbacks (documentados)

| Situação | Comportamento |
|----------|----------------|
| `seller_slugs` ausente | Tenta só `agents/{slug}` |
| Seller sem `userId` | Usa só seller + mirror slug |
| Sem nome no Firestore | `formatSlugAsDisplayName(slug)` — ex: `diego-teste` → **Diego Teste** |
| Sem foto URL | Tenta Storage `agents/{userId}/photo` |
| `agentId` vazio ou `default` | Perfil genérico da empresa (só rota `/`) |

**Nunca** usar `"Consultor"` ou `"M4LIFE USA"` como nome do agente quando existe slug real ou dados no seller/agents.

---

## 6. Como um lead é salvo

Fluxo: `result_screen._saveLead()` após o questionário.

```
1. resolveOwnerUid(widget.agentId)
   → UID Firebase (via slug → seller.userId)

2. loadAgent(widget.agentId)
   → companyId + sellerId (hasSaaSContext)

3. SEMPRE grava legado:
   leads.add({
     agentId: uid,
     nome, telefone, nascimento, lang, answers, score,
     status: 'novo',
     createdAt: serverTimestamp,
   })

4. SE agent.hasSaaSContext:
   companies/{companyId}/leads.add({
     companyId, sellerId, agentId: uid,
     nome, telefone, prospectName, prospectPhone,
     nascimento, lang, locale, answers, score,
     status: 'novo',
     createdAt, updatedAt: serverTimestamp,
   })
```

**Duplo write intencional:** dashboard legado lê `leads`; admin SaaS lê `companies/.../leads`.

Cloud Function `notifyAgentOnNewLead` escuta `leads/{leadId}` (raiz) e envia email.

---

## 7. Exemplos de referência (produção)

### Diego (`/a/diego-teste`)

| Doc | Campos chave |
|-----|----------------|
| `seller_slugs/diego-teste` | `companyId: m4life`, `sellerId: diego-teste` |
| `companies/m4life/sellers/diego-teste` | `displayName: Diego Agente Teste`, `userId: kdlynxa7...`, `photoUrl: https://...` |
| `agents/kdlynxa7...` | `nome`, `fotoUrl`, `slug: diego-teste` |
| `agents/diego-teste` | espelho do mesmo payload |

### Renan (`/a/renan`)

| Doc | Campos chave |
|-----|----------------|
| `seller_slugs/renan` | `companyId: m4life`, `sellerId: renan` |
| `companies/m4life/sellers/renan` | `displayName: Renan Sampaio`, `userId: C0cssi1v...` |
| `agents/C0cssi1v...` + `agents/renan` | criados pelo script de sync |

---

## 8. Scripts de manutenção

```bash
cd scripts/seed && node sync_public_agent_profiles.js
```

Valida e cria `agents/{uid}` + `agents/{slug}` faltantes.

---

## 9. Referência de código

| Responsabilidade | Arquivo |
|------------------|---------|
| Modelo + `loadAgent` | `lib/legacy/screens/agent_profile.dart` |
| Card público | `AgentCard`, `AgentProfilePhoto` |
| Salvar lead | `lib/legacy/screens/result_screen.dart` |
| Sync perfil | `lib/legacy/screens/agent_setup_screen.dart` |
| Criar agente | `lib/legacy/admin/create_seller_service.dart` |
| Regras | `firestore.rules`, `storage.rules` |
| Paths | `lib/core/constants/firestore_paths.dart` |

---

*Última atualização: alinhado ao refactor `AgentProvider` 3-pass e commit `refactor: unified schema documentation and simplified AgentProvider`.*
