# Live Long / HitLook — Auditoria de Queries Firestore

Padrão e formato inspirados em
[`OpenWhen/planning/FIRESTORE_QUERY_AUDIT.md`](../../OpenWhen/planning/FIRESTORE_QUERY_AUDIT.md).
Auditoria realizada em **2026-05-23** sobre os ~97 arquivos `.dart` do
`livelong`.

> Lição do Whenote: ler `users` inteira para contar seguidores custou
> milhares de reads/sessão. Esta auditoria preveniu o mesmo no Live Long.

---

## 1. Anti-patterns conhecidos (referência)

| # | Anti-pattern | Como detectar |
|---|--------------|---------------|
| 1 | Collection read só para contar | `.snapshots()` / `.get()` seguido de `.docs.length` |
| 2 | Query sem `.limit()` em coleção que cresce | `.collection(X).where(...).snapshots()` sem `limit` |
| 3 | Counter denormalizado sem manutenção | `users.followersCount` lido mas nenhuma function incrementa |
| 4 | `StreamBuilder` quando bastava `get()` | Dados estáticos com listener permanente |
| 5 | Query duplicada em widgets diferentes | Mesmo `.where()` em 2+ árvores |
| 6 | `whereIn` sem cuidar do limite 30 | Array de até `n` IDs passado direto |
| 7 | Export sem paginação | `.get()` sem `limit` para "todos os dados do usuário" |
| 8 | `orderBy` sem índice deployado | Query falha com `failed-precondition` |

---

## 2. Achados no Live Long

### 2.1 ✅ Boas práticas já em uso

| Onde | Padrão |
|------|--------|
| [`firebase_lead_repository.dart:51-66`](../lib/data/repositories/firebase/firebase_lead_repository.dart) | `watchByCompany`/`watchBySeller` com `orderBy('createdAt', descending: true)` — índice composto definido em `firestore.indexes.json` |
| [`agent_dashboard_screen.dart:51-67`](../lib/legacy/screens/agent_dashboard_screen.dart) | Usa `.limit(_pageSize)` em todas as queries. Paginação com `.startAfter([lastCreatedAt]).limit(_pageSize)` em `:282-285` ✅ |
| [`firebase_seller_repository.dart:56`](../lib/data/repositories/firebase/firebase_seller_repository.dart) | `orderBy('displayName')` em `companies/.../sellers` — sem `limit`, mas justificável: cada empresa tem dezenas, não milhares de sellers |
| [`firebase_company_repository.dart:25-37`](../lib/data/repositories/firebase/firebase_company_repository.dart) | `watchAll()` em `companies` — sem `limit`. **Mas**: usado só pelo admin master Diego, e número de tenants cresce devagar (1 hoje, 2-3 em 12 meses). **Aceitável.** |
| `firestore.rules` (`isValidPublicLeadCreate`) | Whitelist de chaves permitidas no create público do lead. Excelente. |
| `FirestoreService.collection(...)` central | Single source para criar referências. |
| `seller_slugs/{slug}` allow `get: true; list: false` | Lookup público sem permitir scan. Boa decisão. |

### 2.2 ⚠️ Problemas de prioridade ALTA

#### A1 — `_fetchRootLeads` / `_fetchCompanyLeads` rodam em série

[`agent_dashboard_screen.dart:158`](../lib/legacy/screens/agent_dashboard_screen.dart)
chama `_fetchRootLeads(uid)` e `_fetchCompanyLeads(agent)` sequencialmente.
São queries **independentes** em coleções diferentes — poderiam rodar em
paralelo.

**Custo:** ~1 segundo extra de latência em iOS no abrir do dashboard
(network round-trip duplicado).

**Fix:**
```dart
final results = await Future.wait([
  _fetchRootLeads(uid),
  _fetchCompanyLeads(agent),
]);
final rootLeads = results[0];
final companyLeads = results[1];
```

#### A2 — `_mergeLeadRows` deduplica por `(phone, name)` em client

[`agent_dashboard_screen.dart:121-156`](../lib/legacy/screens/agent_dashboard_screen.dart):

```dart
final duplicate = rootLeads.any(
  (r) => leadDisplayPhone(r) == phone &&
         phone.isNotEmpty &&
         leadDisplayName(r) == name,
);
```

Risco:

- Acento diferente em "José" vs "Jose" → 2 leads.
- Telefone com `+1` vs sem → 2 leads.
- `O(n²)` em listas grandes.

**Fix definitivo:** **resolver schemas duplos**
([ARCHITECTURE.md §2.1](ARCHITECTURE.md)).

**Fix paliativo:** normalizar (lowercase + remove acentos + remove
non-digits no phone) antes de comparar.

#### A3 — `AdminSession.load()` chamado em múltiplos lugares sem cache

Verificado:
- `route_guards.dart:60`
- `route_guards.dart:65`
- `admin_dashboard_screen.dart:27`
- `admin_dashboard_screen.dart:42` (via `FutureBuilder`)
- `admin_master_screen.dart:31`

Cada chamada faz `users/{uid}.get()`. Navegação típica de Renan:
**4-5 reads** do mesmo doc até chegar à tela.

**Fix:** cache de 5 min em memória — ver
[ARCHITECTURE.md §2.3](ARCHITECTURE.md) com snippet pronto.

#### A4 — Listener em `companies` (master) sem `limit`

[`firebase_company_repository.dart:25-37`](../lib/data/repositories/firebase/firebase_company_repository.dart):

```dart
return FirestoreService.collection(FirestorePaths.companies).snapshots().map(...)
```

Hoje há **1 empresa** (M4LIFE). Em 2 anos pode ter **20-50** empresas. Ainda
seguro. Mas quando passar de **200** empresas, `listen all` vira problema.

**Fix preventivo (v1.2):** adicionar `.limit(50)` + paginação. Documentar
no [CHANGELOG.md](CHANGELOG.md) o limite quando aplicado.

### 2.3 🟢 Problemas de prioridade BAIXA

#### B1 — Sem agregações Firestore (`count()`)

Em `admin_master_screen.dart` provavelmente exibe "X agentes / Y leads"
por empresa (não validado a fundo). Para esse caso, Firestore tem
`AggregateQuery.count()` desde 2023 — 1 read por agregação contra N reads
do `snapshots()`.

Live Long pode usar:

```dart
final aggSnap = await FirestoreService
    .collection(FirestorePaths.companyLeads(companyId))
    .count()
    .get();
print(aggSnap.count); // total leads
```

**Vale só se** o dashboard mostrar contagens em tempo real.

---

## 3. Custos estimados — 100 agentes / 1k leads/mês

Baseado em [`docs/06-BUSINESS_MODEL.md`](../docs/06-BUSINESS_MODEL.md)
projetando alvo do piloto.

| Operação | Reads/mês | Writes/mês | Custo (Firebase Blaze) |
|----------|-----------|------------|-----------------------|
| Lead criado (duplo write) | — | 1.000 × 2 = 2.000 | ~$0.04 |
| Agente abre dashboard 5×/dia (cache off) | 100 × 5 × 30 × ~50 leads = **750k** | — | ~$0.27 |
| Prospect carrega `/a/{slug}` (3 reads × 1.000) | 3.000 | — | ~$0.001 |
| Admin Diego/Renan navega | 1.000 | — | ~$0.0004 |
| Chat com Ana (no Firestore) | — | — | $0 (não persiste no Firestore) |
| **Total Firestore** | ~754k | 2.000 | **~$0.31** |
| Cloud Functions (`notifyAgentOnNewLead`) | — | 1.000 invocations | ~$0 (free tier) |
| Anthropic API (Ana) | 200 turnos × 1k tokens médio = 200k tokens | — | **~$3-6** dependendo de Sonnet vs Haiku |
| Storage (fotos agentes) | 100 × 200KB = 20MB | — | < $0.01 |

**Total estimado:** **$4-8/mês** para 100 agentes. Ainda dentro do free tier
do Firestore (50k reads grátis/dia).

**Maior risco de custo:** chat com Ana — limite por sessão é crítico.
[`docs/07-RISKS.md`](../docs/07-RISKS.md) §4 já lista mitigação:

- "Limite de mensagens por sessão (~20)"
- "Cache de respostas comuns"
- "Sonnet pra conversa rica, Haiku pra resposta rápida"

**Hoje:** `AnaProxyConfig.model = 'claude-sonnet-4-6'` e **sem limite** no
client. Ver [FUNCTIONS_AUDIT.md](FUNCTIONS_AUDIT.md).

---

## 4. Recomendações de índices Firestore

Estado atual (`firestore.indexes.json`):

```json
{
  "indexes": [
    { "collectionGroup": "leads", "fields": [
        { "fieldPath": "sellerId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
    ]},
    { "collectionGroup": "leads", "fields": [
        { "fieldPath": "agentId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
    ]}
  ]
}
```

**OK** para as queries existentes.

**Sugerido adicionar quando crescer:**

| Índice | Por quê |
|--------|---------|
| `sellerId + status + createdAt DESC` | Filtrar leads por status no dashboard ("não contatados") |
| `companyId + createdAt DESC` (collection group `leads`) | Admin Renan listar todos os leads M4LIFE |
| `searchTokens` em `companies/.../sellers` | Busca de agentes em painel multi-tenant futuro (estilo Whenote) |

---

## 5. Padrões a manter daqui pra frente

Para todo PR que toca Firestore:

- [ ] Toda query em coleção tem `.limit()` **ou** justificativa no comentário.
- [ ] `StreamBuilder` só quando o dado **muda visivelmente** na tela.
      Para snapshots estáticos, usar `FutureBuilder` com `get()`.
- [ ] Antes de ler um counter denormalizado, **conferir** que existe Cloud
      Function que o mantém. Senão, calcular sob demanda (com `count()`)
      ou recusar a feature.
- [ ] `whereIn` com array sempre dentro de `chunk(10)`.
- [ ] Cada `orderBy(...).where(...)` precisa de índice composto deployado.

---

## 6. Comandos úteis

```bash
# Validar que regras compilam (sem deploy)
cd /sessions/kind-amazing-maxwell/mnt/livelong
firebase emulators:exec --only firestore "echo ok"

# Deploy só de índices
firebase deploy --only firestore:indexes

# Deploy só de regras
firebase deploy --only firestore:rules

# Logs de queries em emulator
firebase emulators:start --only firestore --inspect-functions
```

---

*Última atualização: 2026-05-23.*
