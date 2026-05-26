# Live Long / HitLook — Changelog

Mudanças notáveis no projeto.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Para mudanças anteriores a maio/2026, ver `docs/02-CURRENT_STATUS.md`.

---

## [Unreleased]

### Security incident — 2026-05-24

- 🔴 **Anthropic API key exposta no chat** durante tentativa de
  configurar Secret Manager. Resposta: revogação + rotação +
  monitoramento de billing 48h. Aprendizado documentado em
  [TROUBLESHOOTING.md §15](TROUBLESHOOTING.md) e nas instruções de
  B2 no [CHECKLIST.md](CHECKLIST.md). Regra adicionada: **nunca colar
  credenciais como argumento posicional da CLI** — usar prompt mascarado
  ou `--data-file=-`.

### Firebase config audit — 2026-05-24

- 📘 **`planning/FIREBASE_PROJECT.md`** criado — referência operacional
  com todos os IDs (`hitlook-app` / project number `807145542991`),
  comandos `firebase` por área (deploy, secrets, logs, hosting,
  crashlytics), inventário dos arquivos que tocam config, e procedimento
  para regerar tudo via FlutterFire CLI se A1 mudar o bundle ID.
- 🔧 **iOS Analytics** ligado de fato: `GoogleService-Info.plist`
  `IS_ANALYTICS_ENABLED` mudado para `true` (estava `false`,
  contradizendo a inicialização em `bootstrap.dart` feita em A8).
- 🔧 **Android Crashlytics plugin** adicionado: `com.google.firebase.crashlytics`
  em `android/settings.gradle.kts` e aplicado em `android/app/build.gradle.kts`.
  Sem isso o `firebase_crashlytics` v5 silenciosamente não envia
  mappings de R8/proguard.
- 🔒 **`web/env.js` neutralizado**: era `window.ENV = { ANTHROPIC_API_KEY: '' }`
  — placeholder convidativo para colar uma chave que ficaria pública via
  Hosting. Trocado por `Object.freeze({})` com comentário explicando
  o risco e apontando para o Cloudflare Worker / Secret Manager.
- 🔧 **`.firebaserc`** expandido com alias `prod` (aponta para
  `hitlook-app`) e `targets.hitlook-app.hosting.app = ['hitlook-app']`
  para preparar multi-site/multi-env futuro sem refactor.

### Sprint 1 — Execution (2026-05-23)

12 itens code-safe executados em uma sessão. Working tree em `master` com
13 arquivos modificados / 6 criados. **Pendente o commit em lote.**

#### Security & Compliance

- **B7 — chip "pre-existing condition" removido** dos 3 idiomas em
  `chat_screen.dart`. Substituído por "How to choose the right coverage?".
  Achado crítico de [LEGAL.md §2.2](LEGAL.md): evitar coleta de dados
  médicos via Anthropic.
- **A4 — disclaimer regulatório** "Educational tool. Not insurance advice."
  agora visível em 3 telas: `language_screen` (entrada do funil),
  `chat_screen` (header da Ana, EN/PT/ES via `_disclaimerText()`),
  `result_screen` (antes do CTA do consultor). Email do `notifyAgentOnNewLead`
  também recebeu rodapé com disclaimer.
- **B3 — `storage.rules`** com limite 5MB + `contentType.matches('image/.*')`
  + catch-all explícito (`allow read, write: if false`).
- **B4 — `firestore.rules`** com `slugWriteValid(slug)` validando
  `data.slug == slug` (S4) e `companies` create restrito a `isHitLookMaster()` (S5).
- **A6 (parte 1) — Cloudflare Worker** com Origin allowlist, timeout 30s,
  logging estruturado, aceita `X-Firebase-AppCheck` header.
- **B2 — Secret Manager:** `anthropicProxy` refatorada para Functions v2
  `onRequest` + `defineSecret('ANTHROPIC_API_KEY')` + Origin allowlist + timeout.

#### Apple Release readiness

- **A2 — Info.plist patch**: `NSCameraUsageDescription`,
  `NSPhotoLibraryUsageDescription`, `ITSAppUsesNonExemptEncryption=false`,
  `LSApplicationQueriesSchemes=[whatsapp]`. Validado com Python plistlib.
- **A3 — Privacy Policy + Terms of Use scaffolds** em EN/PT/ES (6 arquivos
  HTML em `web/`) seguindo a estrutura de [LEGAL.md §3 e §4](LEGAL.md).
  Placeholders `[LEGAL_TEXT — …]` nos pontos que dependem de advogado.
  Dark theme alinhado ao app. hreflang cross-link entre idiomas.
  `firebase.json` ajustado com headers de cache e nosniff.
- **A8 — Crashlytics + Analytics**: `firebase_crashlytics: ^5.0.0`,
  `firebase_analytics: ^12.0.0` no `pubspec`. `bootstrap.dart` agora
  inicializa ambos + `FlutterError.onError` + `PlatformDispatcher.onError`.
  `firebase.json:uploadDebugSymbols: true`.

#### Quality / Performance

- **B6 — Email i18n** no `notifyAgentOnNewLead`: `EMAIL_I18N` dict
  EN/PT/ES, `resolveEmailLang(lead)` lê `lead.lang/locale` com fallback PT.
  Adicionado disclaimer regulatório no rodapé do email.
- **D2 — Lead fetch paralelizado**: `_loadData` agora usa `Future.wait`
  para `resolvePublicLinkId`, `_fetchRootLeads` e `_fetchCompanyLeads`
  em vez de chamadas sequenciais.
- **D3 — Dedup normalizado**: `_normalizeName` (case + acentos),
  `_normalizePhone` (só dígitos), `_leadFingerprint` `phone|name`.
  `_mergeLeadRows` agora é O(n+m) via Set, não O(n×m).

#### Pendências operacionais (não-código) deixadas para Diego/Yuri

1. `firebase functions:secrets:set ANTHROPIC_API_KEY` + `firebase deploy --only functions`
2. `firebase deploy --only firestore:rules,storage`
3. `cd cloudflare && ./deploy.sh`
4. `flutter pub get && cd ios && pod install --repo-update`
5. `firebase functions:config:unset anthropic` (após confirmar Secret Manager funcionando)
6. Decisões C1, C2, C3, A1 ainda travam Sprint 2.

### Documentation

- **planning/ criada (2026-05-23):** nova pasta operacional inspirada no
  padrão `planning/` do Whenote (mesmos donos). Inclui:
  - `README.md` — índice.
  - `PRODUCTION.md` — checklist operacional por fases (A–H) para release Apple.
  - `APPLE_RELEASE.md` — playbook específico do iOS / TestFlight / App Review.
  - `ARCHITECTURE.md` — auditoria de `lib/` e dívidas técnicas vs Whenote.
  - `FIRESTORE_AUDIT.md` — auditoria de queries (lições do refactor de
    busca de usuários do Whenote em abril/2026).
  - `SECURITY.md` — análise de `firestore.rules`, `storage.rules`,
    `functions/index.js`, `cloudflare/worker.js`.
  - `FUNCTIONS_AUDIT.md` — auditoria das 3 Cloud Functions + Cloudflare Worker.
  - `RISKS.md` — riscos para o 1º release (Apple/regulatório/segurança).
  - `TROUBLESHOOTING.md` — problemas conhecidos e diagnóstico.
  - `CHANGELOG.md` — este arquivo.

- **LEGAL.md adicionada (2026-05-23):** análise jurídica completa
  adaptada ao contexto B2B insurance EUA. Inclui:
  - Mapeamento de jurisdições (CCPA/CPRA, FIPA, Florida Insurance Code, NAIC
    Model 870, COPPA, TCPA, GLBA). LGPD/GDPR documentados como contingentes.
  - Inventário de dados coletados por persona (agente, prospect, admin).
  - Achado crítico: chips de sugestão em [`chat_screen.dart:99-104`](../lib/legacy/screens/chat_screen.dart)
    incentivam prospect a compartilhar pré-existência médica com Ana → vai
    para Anthropic. Recomendação: remover chip.
  - Estrutura proposta da Privacy Policy (16 seções) e Terms of Use (10 seções)
    em EN/PT/ES.
  - Política de retenção: 24 meses prospects não convertidos; 5-7 anos
    convertidos (NAIC); 6 anos agentes pós-cancelamento (FL statute).
  - Playbook de breach (FIPA 30 dias + CCPA "expedient").
  - Diferenças explícitas vs Whenote para não confundir os modelos.
  - 11 itens de ação antes do release.
  - Perfil ideal do advogado a contratar (insurance + privacy + SaaS, FL).

  Mantida a pasta `docs/` como fonte da verdade da **estratégia** (visão,
  modelo de negócio, schema). A `planning/` é **operacional**.

### Pending decisions

🟡 Decisões abertas para Diego — listadas para tracking, ver detalhes em
cada doc:

- **Nome final do app iOS** (HitLook vs Livelong vs M4LIFE Consultant) —
  [APPLE_RELEASE.md §2.1](APPLE_RELEASE.md).
- **Schemas duplos**: deprecar `/leads` raiz pós-piloto ou manter para v1.1+ —
  [ARCHITECTURE.md §2.1](ARCHITECTURE.md).
- **`anthropicProxy` Cloud Function**: remover (Cloudflare Worker já faz o
  trabalho) ou proteger com App Check —
  [FUNCTIONS_AUDIT.md §2.3](FUNCTIONS_AUDIT.md).
- **Pasta `lib/legacy/`**: renomear para `screens_v1/` ou migrar para
  `features/` — [ARCHITECTURE.md §2.2](ARCHITECTURE.md).
- **Dead code de IA** (`lib/services/ai/`, `FirebaseAiRecommendationRepository`,
  rewrite `/api/anthropic/**` em `firebase.json`): remover para reduzir
  superfície e confusão — [ARCHITECTURE.md §2.5](ARCHITECTURE.md).
- **Entidade jurídica** (Florida LLC vs Delaware LLC) — bloqueia
  App Store Connect (EIN obrigatório). [LEGAL.md §10](LEGAL.md).
- **Chip "I have a pre-existing condition" em `chat_screen.dart`** — manter
  ou remover? Remover é o caminho seguro pelo NAIC. [LEGAL.md §2.2](LEGAL.md).
- **Lead de agente que sai do tenant** — fica com o agente ou com Renan?
  Implicação contratual + privacy. [LEGAL.md §5](LEGAL.md).

---

## Histórico anterior (resumo)

Para o histórico completo até **2026-05-19**, ver
[`docs/02-CURRENT_STATUS.md`](../docs/02-CURRENT_STATUS.md) e
[`docs/05-CHECKLIST.md`](../docs/05-CHECKLIST.md).

### Marcos relevantes

- **2026-05-19** — Auditoria SaaS, foto agente persistência validada.
- **~maio/2026** — Painel master Diego + drill-down M4LIFE entregues.
- **~maio/2026** — Cadastro público bloqueado (só admin cria agentes via
  `createSellerAccount`).
- **~abr/2026** — Cloudflare Worker entrou em produção, eliminando CORS
  direto do client para Anthropic.
- **~abr/2026** — Schemas duplos coexistindo (`/leads` raiz + `companies/.../leads`).

---

## Notas para futuras releases

### Antes da v1.0 (1ª submissão Apple)

Sequência sugerida (alinhada com [PRODUCTION.md §H](PRODUCTION.md) e
[RISKS.md](RISKS.md) matriz de prioridade):

- [ ] Decidir nome do app (R2)
- [ ] Patch `Info.plist` (R4)
- [ ] Política de privacidade + Termos publicados (R3)
- [ ] Disclaimer regulatório em 3 telas (R1)
- [ ] Origin allowlist no Cloudflare Worker (R5)
- [ ] Crashlytics + Analytics inicializados (R8)
- [ ] App Check em modo monitor (R5)
- [ ] App Privacy preenchido em App Store Connect (R6)
- [ ] QA dispositivo real (R7)
- [ ] TestFlight interno → externo → submissão App Review

### v1.1 (post-piloto)

- Unificar schemas (`/leads` deprecado).
- Sign in with Apple (preparar para Google Sign-In v1.2).
- CI/CD em GitHub Actions.
- Renomear `lib/legacy/`.
- Email i18n no `notifyAgentOnNewLead`.

### v1.2

- Domínio próprio (livelong.app ou hitlook.us).
- Stripe self-service.
- Open Graph dinâmico por agente.
- App Check em **enforce**.

---

*Criado em 2026-05-23.*
