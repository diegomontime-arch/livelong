# Live Long / HitLook — Arquitetura: Estado e Gaps

Auditoria de arquitetura do código Flutter em `lib/` realizada em **2026-05-23**.
Confrontada com o padrão usado no projeto Whenote (mesmos donos) para
identificar onde Live Long ainda precisa evoluir.

> Para a referência do schema Firestore, ver
> [`docs/11-SCHEMA-DEFINITIVO.md`](../docs/11-SCHEMA-DEFINITIVO.md) — está
> atualizado e detalhado, **não duplicar** aqui.

---

## 1. Visão geral do que existe

### 1.1 Estrutura de `lib/`

```
lib/
├── main.dart               — bootstrap simples (ver bootstrap.dart)
├── app.dart                — MaterialApp.router (HitLookApp)
├── core/                   — config, constants, routing, theme, utils, tenant
├── data/                   — models + repositories (interfaces + impl Firebase)
├── features/               — auth, dashboard, leads, onboarding, public_lead_form, seller_profile
├── legacy/                 — ⚠️ telas REAIS em produção (admin/, screens/, widgets/)
├── services/               — ai/, firebase/
└── shared/                 — extensions, widgets
```

**Total:** ~97 arquivos Dart, ~13.9k linhas (`find lib -name "*.dart"`).

### 1.2 Pontos fortes

| Padrão | Onde | Observação |
|--------|------|------------|
| Repository pattern | `lib/data/repositories/` | Interfaces (`auth_repository.dart`) + impl Firebase (`firebase/`). Bom para futuro vendor lock-in ([`docs/07-RISKS.md`](../docs/07-RISKS.md) §9). |
| `Result<T>` em vez de exceções | `lib/core/utils/result.dart` | Erros explícitos no contrato, evita try/catch aninhados em UI. Bem implementado. |
| `FirestorePaths` constants | `lib/core/constants/firestore_paths.dart` | Single source of truth para paths — ótimo. |
| Validação por regras | `firestore.rules` | Robusto, com `publicLeadAllowedKeys()` whitelist — ver [SECURITY.md](SECURITY.md). |
| Cloudflare Worker para Anthropic | `cloudflare/worker.js` | Chave nunca chega ao client. ✅ |
| Splash + redirect baseado em sessão | `lib/legacy/screens/hitlook_splash_screen.dart` + `route_guards.dart` | Funcional. |

---

## 2. Dívidas técnicas e gaps

### 2.1 🟡 **CRÍTICO — Schemas duplos não unificados**

Estado documentado em [`docs/02-CURRENT_STATUS.md`](../docs/02-CURRENT_STATUS.md):

> "Dois schemas de leads paralelos — leads raiz (legado) e
> companies/.../leads (SaaS)"

Verificação no código (2026-05-23):

- `lib/data/repositories/firebase/firebase_lead_repository.dart:13` —
  só lê/escreve `companies/{companyId}/leads`.
- `lib/legacy/screens/result_screen.dart` — **escreve em ambos** os schemas
  simultaneamente (linha 313-329 do schema doc).
- `lib/legacy/screens/agent_dashboard_screen.dart:51-119` — `_fetchRootLeads`
  e `_fetchCompanyLeads`, depois `_mergeLeadRows` deduplica por
  `(phone, name)`.

**Custo da dívida:**

1. **Duplo write** em cada lead criado → 2× Firestore writes →
   custo dobrado em runtime + 2× chance de falha parcial.
2. **Merge client-side** por `(phone, name)` é frágil — se o prospect digita
   nome com acento diferente, conta como 2 leads.
3. **`agents/{uid}` + `agents/{slug}`** ([`docs/11-SCHEMA-DEFINITIVO.md`](../docs/11-SCHEMA-DEFINITIVO.md) §3.6)
   exige sincronização manual em todo update de perfil — `agent_setup_screen.dart`
   e `create_seller_service.dart` precisam continuar fazendo dual-write
   ou o link público quebra.

**Recomendação:**

🟡 **DECISÃO PENDENTE — Diego.** Duas saídas razoáveis:

| Opção | Esforço | Impacto |
|-------|---------|---------|
| **A. Deprecar `/leads` raiz após o piloto** | ~ 1 semana de migração + Cloud Function para backfill | Único schema. Apaga 50% das regras em `firestore.rules`. **Quebra** notificação de email atual que escuta `leads/{leadId}` ([`functions/index.js:101`](../functions/index.js)) — migrar trigger para `companies/{cid}/leads/{lid}`. |
| **B. Manter ambos por v1.0 (release iOS), unificar em v1.1** | ~ 0 dias agora | Aceita dívida. Documenta no [CHANGELOG.md](CHANGELOG.md) como "tech debt #1". Risco: cada nova feature precisa pensar em 2 schemas. |

[`docs/03-HONEST_ASSESSMENT.md`](../docs/03-HONEST_ASSESSMENT.md) §3 já
argumenta a favor da Opção B — **"Hardcode TUDO pra M4LIFE. Quando aparecer
segundo cliente com cartão na mão, aí refatora."** Mas isso fala de
**multi-tenant**, não de schemas duplos. Schemas duplos são pura dívida
sem upside de venda. **Recomendo Opção A pós-TestFlight.**

### 2.2 Pasta `legacy/` contém o código de produção

Convenção atual confunde:

- `lib/legacy/screens/` tem **as telas reais em produção** segundo
  [`docs/03-ARCHITECTURE.md`](../docs/03-ARCHITECTURE.md):

  > "── TELAS REAIS EM USO"

- `lib/features/` existe mas vários `*_controller.dart` parecem
  esqueletos (ex: `lib/features/leads/presentation/leads_controller.dart`).

A nomenclatura "legacy" sugere que esse código deve sair — mas é onde o app
roda. Resultado: novo dev abre a pasta `features/` esperando achar a UI
real e não acha.

**Recomendação:**

- Renomear `lib/legacy/` → `lib/screens_v1/` ou `lib/legacy_inuse/`
  enquanto a migração para `features/` não estiver concluída.
- Ou: mover todas as telas funcionais para `lib/features/<feature>/presentation/screens/`
  ao estilo Whenote ([`OpenWhen/planning/ARCHITECTURE.md`](../../OpenWhen/planning/ARCHITECTURE.md)
  seção "Estrutura de pastas").
- 🟡 **DECISÃO PENDENTE.** Não é bloqueante para release, mas resolver antes
  de contratar segundo dev.

### 2.3 State management ad-hoc

Whenote usa **Riverpod** ([`OpenWhen/pubspec.yaml`](../../OpenWhen/pubspec.yaml)
tem `flutter_riverpod`). Live Long usa:

- `StatefulWidget` + `setState` (todas as telas em `legacy/screens/`).
- `Future`/`Stream` direto na UI via `FutureBuilder`/`StreamBuilder`.
- Não há `provider`, `riverpod`, `bloc` no `pubspec.yaml`.

Para o escopo atual (poucas telas, dados quase sempre 1-1 com uma coleção
Firestore) isso é **aceitável**. Mas:

- `AdminSession.load()` é chamado em **múltiplos lugares** (`route_guards.dart`,
  `admin_dashboard_screen.dart`, `admin_master_screen.dart`) — cada chamada
  faz um `get` no Firestore. Em uma navegação típica `splash → admin → company`,
  são **3 reads** do mesmo `users/{uid}`. Riverpod resolveria com cache.
- `AgentProfile.loadAgent()` é chamado em cada abertura de `/a/{slug}` —
  ok, é tela pública.

**Recomendação:** introduzir `flutter_riverpod` **só quando** houver mais
de 1 dev no projeto. Hoje, simplicidade vence sofisticação. Mas adicionar
cache em `AdminSession` (5 min in-memory) é low-hanging fruit:

```dart
class AdminSession {
  static AdminSession? _cached;
  static DateTime? _cachedAt;

  static Future<AdminSession?> load({Duration cacheTtl = const Duration(minutes: 5)}) async {
    if (_cached != null && _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < cacheTtl) {
      return _cached;
    }
    final fresh = await _loadFromFirestore();
    _cached = fresh;
    _cachedAt = DateTime.now();
    return fresh;
  }
}
```

### 2.4 Sem tratamento centralizado de erros

`AppException` existe em `lib/core/errors/app_exception.dart` mas:

- `chat_screen.dart:154-206` faz try/catch local com `debugPrint`.
- `firebase_lead_repository.dart` envolve com `FirestoreMappers.guard`
  ([`data/firebase/firestore_mappers.dart`](../lib/data/firebase/firestore_mappers.dart)).
- UI faz `SnackBar` em alguns lugares, `Text(error)` em outros.

**Recomendação:** quando ligar Crashlytics ([PRODUCTION.md §G.3](PRODUCTION.md)),
unificar em um helper:

```dart
Future<T?> safeCall<T>(Future<T> Function() fn, {required String op}) async {
  try {
    return await fn();
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st, reason: op);
    return null;
  }
}
```

### 2.5 Dead code de IA — `services/ai/` e `data/repositories/firebase/firebase_ai_recommendation_repository.dart`

[`lib/services/ai/ai_completion_service.dart`](../lib/services/ai/ai_completion_service.dart)
implementa `HttpAiCompletionService` que chama `AppConfig.anthropicProxyUrl`
= `https://hitlook-app.web.app/api/anthropic/v1/messages` — um rewrite do
Firebase Hosting ([`firebase.json:11-13`](../firebase.json)) que aponta para
`https://api.anthropic.com/**`.

Dois problemas:

1. **Firebase Hosting `destination` para URL externa** provavelmente não
   funciona (só `function`/`run` fazem proxy externo). Esse path
   está **broken**.
2. `HttpAiCompletionService` é usado apenas como default em
   `FirebaseAiRecommendationRepository.constructor` — repositório que **não
   é instanciado** em nenhuma rota / feature / controller.

Resultado: **código morto**, **rewrite quebrado**, **superfície confusa**.

**Recomendação:**
- Remover `lib/services/ai/` e o repo `FirebaseAiRecommendationRepository`.
- Remover o rewrite `/api/anthropic/**` de `firebase.json`.
- Single source of truth para Ana: `AnaProxyConfig` → Cloudflare Worker.

Ver detalhe em [FUNCTIONS_AUDIT.md §2](FUNCTIONS_AUDIT.md).

### 2.6 Logs de debug ainda ativos em build de release

[`docs/02-CURRENT_STATUS.md`](../docs/02-CURRENT_STATUS.md) menciona:

> "Logs de debug ainda ativos — public_lead_agent_id_log.dart"

Verificação: `lib/legacy/screens/agent_dashboard_screen.dart:42` usa
`debugPrint` — ok em release porque Flutter remove `debugPrint` em build
release. Mas `print()` direto **fica**. Grep necessário antes do release:

```bash
grep -rn "^\s*print(" lib/  # qualquer match → trocar para debugPrint
```

### 2.7 Falta CI/CD

Repo não tem `.github/workflows/` nem `codemagic.yaml` nem `bitrise.yml`
(verificado em 2026-05-23). Whenote tem CI em Codemagic.

**Não bloqueia release**, mas:

- Cada deploy depende de Diego rodar localmente.
- Sem testes automatizados em PR.
- Vulnerabilidade ao Diego ficar indisponível.

**Recomendação v1.1:** GitHub Actions com:

1. `flutter analyze`
2. `flutter test`
3. (Opcional) `flutter build web --release` em PR para validar que compila.

---

## 3. Sugestões inspiradas no Whenote

### 3.1 `core/user_search/` (estilo Whenote)

Whenote teve um incidente em abril/2026: carregava **todos** os documentos
de `users` em várias telas, custou milhares de reads por sessão. Solução
documentada em [`OpenWhen/planning/FIRESTORE_QUERY_AUDIT.md`](../../OpenWhen/planning/FIRESTORE_QUERY_AUDIT.md)
e o código vive em `OpenWhen/lib/core/user_search/`.

Live Long **não tem busca de usuários** hoje (admin lista por `watchByCompany`
com `orderBy('displayName')` — `firebase_seller_repository.dart:56`). Quando
crescer, **seguir o mesmo padrão Whenote**: `searchTokens` array no
documento + `array-contains` query, sem prefixo wildcard.

### 3.2 `systemConfig/app` para feature flags remotas

Whenote tem um documento `systemConfig/app` em Firestore com flags como
`aiModerationEnabled`, `reportsEnabled` ([`OpenWhen/planning/PRODUCTION.md §4`](../../OpenWhen/planning/PRODUCTION.md)).
Permite desligar a IA sem deploy.

Live Long pode adotar para:

- `anaChatEnabled` — desligar Ana se Anthropic API ficar instável.
- `signupEnabled` — bloquear cadastro de novos agentes.
- `maxLeadsPerDay` — rate limit.

Estrutura proposta:

```dart
// lib/core/config/system_config_provider.dart
class SystemConfig {
  final bool anaChatEnabled;
  final bool signupEnabled;
  final int maxLeadsPerDay;
  // ...
}

// Firestore: systemConfig/app (read: true; write: false — só admin SDK)
```

**Não é prioridade v1**, mas baixo esforço e alto valor operacional.

### 3.3 Deferred imports para reduzir bundle web

Whenote usa `import 'foo.dart' deferred as foo;` para carregar telas pesadas
sob demanda ([`OpenWhen/planning/ARCHITECTURE.md`](../../OpenWhen/planning/ARCHITECTURE.md)
seção "Performance e carregamento diferido").

Live Long web tem o fluxo do prospect (idioma → onboarding → 5 perguntas →
resultado → chat) e o fluxo do agente (login → dashboard → admin). O
**bundle do agente** poderia ser carregado **só após login**, reduzindo
o tempo de carregamento para o prospect que é a maioria do tráfego.

**Adiar para v1.2.**

### 3.4 Padrão `safe_callable` para Cloud Functions

Whenote criou um helper `SafeCallable` ([`OpenWhen/planning/CHANGELOG.md`](../../OpenWhen/planning/CHANGELOG.md)
sec App Check) que:

- Tenta `httpsCallable` nativo do `cloud_functions`.
- Se falhar (bug `firebase-ios-sdk#15974`), faz fallback HTTP com header
  `X-Firebase-AppCheck` manual.

Live Long só tem 2 callables (`createSellerAccount`, `notifyAgentOnNewLead`
trigger). Quando ativar App Check ([PRODUCTION.md §G.1](PRODUCTION.md)),
**provavelmente vai precisar do mesmo workaround**. Vale copiar o helper
do Whenote em vez de descobrir o bug em produção.

---

## 4. Arquitetura de testes

Repositório tem `test/` mas:

```bash
$ ls /Users/yurilima/Downloads/projects/livelong/test/
```

(Auditar — provavelmente só `widget_test.dart` boilerplate.)

**Não há testes** de:

- `_score` em `result_screen.dart` (lógica de pontuação) — alto valor,
  baixíssimo esforço para testar.
- `AgentProfile.loadAgent()` — fluxo crítico com 3 passos
  ([`docs/11-SCHEMA-DEFINITIVO.md`](../docs/11-SCHEMA-DEFINITIVO.md) §5).
- `firestore.rules` — Whenote tem suite de testes para regras em
  `OpenWhen/test/firestore.rules.test.ts`. Live Long não tem.

**Recomendação v1.1:** começar pelo teste das regras Firestore com
`@firebase/rules-unit-testing`. Cada regra nova ganha um teste. Em 3 meses
você tem a suite.

---

## 5. Resumo executivo para Diego

Em ordem de prioridade para o **release iOS 1.0**:

1. **Decisão de nome** (Hitlook vs Livelong vs M4LIFE) — bloqueia tudo do iOS.
2. **Patch Info.plist** — 30 min, destrava review.
3. **Disclaimer regulatório nas 3 telas** — risco regulatório Florida.
4. **App Check em modo monitor** — protege contra abuso da Ana.
5. **Schemas duplos** — não bloqueia release, **decidir depois do piloto** se
   refatora ou mantém.
6. **Renomear `lib/legacy/`** — qualidade de vida, não bloqueia.
7. **CI/CD** — pós-release, junto com o segundo dev.

---

*Última atualização: 2026-05-23.*
