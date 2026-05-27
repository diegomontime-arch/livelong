# Live Long / HitLook — Master Execution Checklist

> **Última atualização:** 2026-05-23
> **Fonte:** consolidado dos 10 documentos em `planning/` para navegação rápida.
> Cada item tem **ID estável** (ex: `R4`, `S7`, `L1`) — referenciar em
> commits/PRs como `fix: R4 Info.plist privacy keys`.

---

## Escopo v1.0 — Apple-only

Decisão de 2026-05-24: foco no release iOS. Android volta em v1.2+. Itens
deste checklist que mencionam Android ou Play Store ficam **🚫 fora de
escopo v1.0** mas permanecem documentados para retomada futura.

Itens cross-platform (Firestore rules, Cloud Functions, Privacy Policy)
**continuam valendo** porque o web app em `hitlook-app.web.app` ainda
roda em produção.

## Como navegar

- 🔴 **Bloqueante** = sem isso, App Store rejeita ou produção quebra.
- 🟠 **Alto** = não bloqueia loja, bloqueia operação segura.
- 🟡 **Médio** = qualidade de vida ou dívida técnica.
- 🟢 **Baixo** = nice-to-have.
- 🤖 **Code-safe** = pode ser executado sem decisão humana.
- 👤 **Decisão Diego/Yuri** = bloqueado por escolha de produto/legal/estratégia.
- 🌐 **Externo** = depende de Apple, IRS, advogado, etc.

Cada item linka para o **documento detalhado** com contexto completo.

---

## Fase A — Bloqueios absolutos do release iOS (🔴)

Itens que **impedem** a submissão à App Store. ~3 dias úteis + 1-3 semanas
externas (LLC, advogado).

### A1 — Identidade do app (nome, bundle ID)
- **Status:** 👤 Decisão Diego pendente
- **Detalhe:** [APPLE_RELEASE.md §2.1](APPLE_RELEASE.md), [RISKS.md R2](RISKS.md)
- **O que falta:**
  - [ ] Decidir: HitLook · Livelong · M4LIFE Consultant
  - [ ] Alinhar `CFBundleDisplayName`, `CFBundleName`, `pubspec.name`, Bundle ID, Firebase app iOS
  - [ ] Registrar Bundle ID final no Apple Developer Portal

### A2 — Info.plist sem chaves de privacidade
- **Status:** ✅ Concluído (2026-05-23)
- **Detalhe:** [PRODUCTION.md §C](PRODUCTION.md), [APPLE_RELEASE.md §2.2](APPLE_RELEASE.md), [RISKS.md R4](RISKS.md)
- **Concluído:**
  - [x] `NSCameraUsageDescription` adicionada
  - [x] `NSPhotoLibraryUsageDescription` adicionada
  - [x] `ITSAppUsesNonExemptEncryption = false` adicionada
  - [x] `LSApplicationQueriesSchemes` com `whatsapp` adicionada
  - [x] Plist validado com Python plistlib

### A3 — Privacy Policy + Terms of Use públicos
- **Status:** ✅ Scaffolds prontos (2026-05-23) — conteúdo legal pendente de advogado
- **Detalhe:** [LEGAL.md §3 e §4](LEGAL.md), [RISKS.md R3](RISKS.md)
- **Concluído:**
  - [x] `web/privacy.html` (EN), `web/privacy.pt.html`, `web/privacy.es.html` — 16 seções alinhadas com LEGAL.md, com placeholders `[LEGAL_TEXT — …]` nos pontos que dependem de advogado
  - [x] `web/terms.html`, `web/terms.pt.html`, `web/terms.es.html` — 10 seções, disclaimer regulatório no topo, FL governing law
  - [x] hreflang cross-link entre os 3 idiomas
  - [x] `firebase.json`: headers `X-Content-Type-Options: nosniff` + cache 1h para privacy/terms
  - [x] Visual: dark theme alinhado às cores do app (--gold, --black)
- **Pendente:**
  - [ ] Revisão por advogado FL (A7) — preencher placeholders `[LEGAL_TEXT — …]`
  - [ ] `flutter build web && firebase deploy --only hosting`
  - [ ] URLs estáveis: `https://hitlook-app.web.app/privacy.html`, `/privacy.pt.html`, `/privacy.es.html`, idem terms

### A4 — Disclaimer regulatório em 3 telas
- **Status:** ✅ Concluído (2026-05-23)
- **Detalhe:** [LEGAL.md §6](LEGAL.md), [RISKS.md R1](RISKS.md), [APPLE_RELEASE.md §2.4](APPLE_RELEASE.md)
- **Concluído:**
  - [x] `language_screen.dart` (entrada do funil): disclaimer "Educational tool. Not insurance advice. Recommendations come from your licensed agent." abaixo do "AI · PROTECTION · SALES"
  - [x] `chat_screen.dart`: banner permanente abaixo do header da Ana, traduzido EN/PT/ES via `_disclaimerText()`
  - [x] `result_screen.dart`: disclaimer reusando key `edu_disc` (já traduzida nos 3 idiomas) imediatamente antes do botão "Falar com consultor"
  - [x] **Bônus:** disclaimer também no email do `notifyAgentOnNewLead` (B6)

### A5 — Entidade jurídica (LLC) + EIN
- **Status:** 🌐 Externo (IRS + state filing)
- **Detalhe:** [LEGAL.md §10](LEGAL.md), [RISKS.md R15](RISKS.md)
- **Wait time:** 1-3 semanas
- **O que falta:**
  - [ ] Diego: decidir Florida LLC vs Delaware LLC
  - [ ] State filing
  - [ ] EIN no IRS (gratuito, online)
  - [ ] Banking opcional v1

### A6 — Cloudflare Worker / `anthropicProxy` aberto
- **Status:** ✅ Parte 1 concluída (2026-05-23); 👤 Parte 2 pendente (decisão C2)
- **Detalhe:** [SECURITY.md S7, S8](SECURITY.md), [FUNCTIONS_AUDIT.md §2, §5](FUNCTIONS_AUDIT.md), [RISKS.md R5](RISKS.md)
- **Concluído:**
  - [x] Worker: Origin allowlist + timeout 30s + logging estruturado
  - [x] `cloudflare/worker.js` aceita `X-Firebase-AppCheck` header (preparado para semana 2)
  - [x] `anthropicProxy` (Cloud Function) recebeu o mesmo tratamento (B2) — mas continua **órfã** até C2 ser decidido
- **Pendente:**
  - [ ] Deploy Worker: `cd cloudflare && ./deploy.sh` (manual)
  - [ ] **C2 (decisão Diego):** remover `anthropicProxy` Cloud Function ou mantê-la como fallback

### A7 — Consulta com advogado FL
- **Status:** 🌐 Externo
- **Detalhe:** [LEGAL.md §12](LEGAL.md), [`docs/05-CHECKLIST.md`](../docs/05-CHECKLIST.md)
- **Wait time:** 1-2h de meeting, agendar
- **O que falta:**
  - [ ] Diego: marcar 1-2h com Mound Cotton / Eversheds / Locke Lord
  - [ ] Validar Privacy Policy + ToU + disclaimer
  - [ ] Documentar conclusões no `LEGAL.md` §14

### A8 — Crashlytics + Analytics iniciados
- **Status:** ✅ Concluído (2026-05-23) — pendente `pub get` + iOS pods
- **Detalhe:** [PRODUCTION.md §G.2, §G.3](PRODUCTION.md), [RISKS.md R8](RISKS.md)
- **Concluído:**
  - [x] `pubspec.yaml`: `firebase_crashlytics: ^5.0.0`, `firebase_analytics: ^12.0.0` (compatíveis com `firebase_core ^4.9.0`)
  - [x] `lib/core/bootstrap.dart`: setup completo — `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `setCrashlyticsCollectionEnabled(!kDebugMode)` + `setAnalyticsCollectionEnabled(!kDebugMode)`
  - [x] `firebase.json`: `uploadDebugSymbols: true`
- **Pendente (manual):**
  - [ ] `flutter pub get`
  - [ ] `cd ios && pod install --repo-update`
  - [ ] Validar dSYMs upload em release build (Xcode Organizer ou via `firebase crashlytics:symbols:upload`)
  - [ ] **Importante:** quando criar consent UI para Analytics (CCPA — [LEGAL.md §3](LEGAL.md)), trocar `!kDebugMode` por flag do usuário

### A9 — App Privacy preenchido em App Store Connect
- **Status:** 🌐 Externo (depende A1 + ASC account)
- **Detalhe:** [APPLE_RELEASE.md §4](APPLE_RELEASE.md), [RISKS.md R6](RISKS.md)
- **O que falta:**
  - [ ] Preencher data categories conforme tabela
  - [ ] Declarar Anthropic como 3rd-party

### A10 — QA dispositivo real
- **Status:** 🌐 Externo (precisa device físico)
- **Detalhe:** [RISKS.md R7](RISKS.md)
- **O que falta:**
  - [ ] iPhone real: fluxo prospect + agente
  - [ ] iPad real (orientações)
  - [ ] iPhone SE (small screen)
  - [ ] Modo avião → não crashar
  - [ ] Câmera → permission prompt → não crashar

---

## Fase B — Alto risco pós-release (🟠)

Itens que **não bloqueiam Apple**, mas podem causar incidente de produção
nas primeiras 4 semanas.

### B1 — Firebase App Check em modo monitor
- **Status:** 🤖 Code + 🌐 Console Firebase
- **Detalhe:** [PRODUCTION.md §G.1](PRODUCTION.md), [SECURITY.md §5](SECURITY.md)
- **O que falta:**
  - [ ] `pubspec.yaml`: `firebase_app_check`
  - [ ] `lib/core/bootstrap.dart`: `FirebaseAppCheck.instance.activate(...)`
  - [ ] Console Firebase: ativar **modo monitor** (não enforce ainda)
  - [ ] 48h de observação antes de enforce

### B2 — Migrar `functions.config()` para Secret Manager
- **Status:** ✅ Código concluído (2026-05-23); 🔴 **Incidente de chave em 2026-05-24** — pendente rotação + provisioning
- **Detalhe:** [PRODUCTION.md §F.1](PRODUCTION.md), [SECURITY.md S9](SECURITY.md)
- **Concluído:**
  - [x] `defineSecret('ANTHROPIC_API_KEY')` no `functions/index.js`
  - [x] Refatorada `anthropicProxy` para Functions v2 `onRequest` + `secrets: [ANTHROPIC_API_KEY]`
  - [x] **Bônus:** Origin allowlist + timeout 30s + logging estruturado (S7, F19)
  - [x] Sintaxe validada com `node --check`
- **🔴 Incidente 2026-05-24:** chave Anthropic foi exposta no chat ao
  ser colada como argumento de `firebase functions:secrets:set`. Ação:
  - [ ] Revogar a chave exposta em https://console.anthropic.com/settings/keys
  - [ ] Gerar nova chave (nome sugerido `hitlook-prod-YYYY-MM-DD`)
  - [ ] Monitorar billing 48h
- **Pendente operacional:**
  - [ ] Resolver IAM 403: garantir que a conta do `firebase login` tem
        `roles/serviceusage.serviceUsageConsumer` em `hitlook-app`
        (ou usar conta Owner)
  - [ ] **Forma correta** de setar secret (não colar no chat):
        ```bash
        firebase functions:secrets:set ANTHROPIC_API_KEY
        # Digite a chave no prompt mascarado — nunca como argumento na CLI.
        ```
        ou via stdin:
        ```bash
        read -s ANTHROPIC_KEY
        echo "$ANTHROPIC_KEY" | firebase functions:secrets:set ANTHROPIC_API_KEY --data-file=-
        unset ANTHROPIC_KEY
        ```
  - [ ] `firebase deploy --only functions:anthropicProxy`
  - [ ] Após deploy, revogar `functions.config()` antigo: `firebase functions:config:unset anthropic`

> **⚠️ Regra geral para todo item de secret no checklist:** nunca colar
> credenciais no chat ou como argumento posicional da CLI. Use o prompt
> interativo (TTY mascarado) ou stdin. Documentado para B5, A6 deploy,
> Stripe (v1.2) e qualquer rotação futura.

### B3 — Storage rules — hardening
- **Status:** ✅ Concluído (2026-05-23) — pendente deploy
- **Detalhe:** [SECURITY.md S6](SECURITY.md)
- **Concluído:**
  - [x] Limite 5MB + `contentType.matches('image/.*')`
  - [x] Catch-all explícito `allow read, write: if false`
  - [ ] **Deploy:** `firebase deploy --only storage` (manual — Diego/Yuri)

### B4 — Firestore rules — refinos
- **Status:** ✅ Concluído (2026-05-23) — pendente deploy
- **Detalhe:** [SECURITY.md S4, S5](SECURITY.md)
- **Concluído:**
  - [x] `slugWriteValid(slug)` recebe slug do path e valida `data.slug == slug` (S4)
  - [x] `companies` create restrito a `isHitLookMaster()` (S5)
  - [ ] **Deploy:** `firebase deploy --only firestore:rules` (manual)

### B5 — Trigger Email Extension validar instalação
- **Status:** 🌐 Console Firebase
- **Detalhe:** [FUNCTIONS_AUDIT.md §4.3 F13](FUNCTIONS_AUDIT.md), [TROUBLESHOOTING.md §9](TROUBLESHOOTING.md)
- **O que falta:**
  - [ ] Verificar `firestore-send-email` instalado
  - [ ] Configurar SMTP (Google Workspace Relay sugerido)
  - [ ] Smoke test: criar lead → email chega

### B6 — Email i18n no `notifyAgentOnNewLead`
- **Status:** ✅ Concluído (2026-05-23) — pendente deploy
- **Detalhe:** [FUNCTIONS_AUDIT.md §4.3 F15](FUNCTIONS_AUDIT.md), [RISKS.md R12](RISKS.md)
- **Concluído:**
  - [x] Templates EN/PT/ES com `EMAIL_I18N` dict
  - [x] `resolveEmailLang()` lê `lead.lang` / `lead.locale`, fallback PT
  - [x] **Bônus:** disclaimer regulatório no rodapé do email (alinha [LEGAL.md §6](LEGAL.md) ponto 6)
- **Pendente (manual):** `firebase deploy --only functions:notifyAgentOnNewLead`

### B7 — Remover chip "I have a pre-existing condition"
- **Status:** ✅ Concluído (2026-05-23)
- **Detalhe:** [LEGAL.md §2.2](LEGAL.md), achado crítico de saúde + NAIC
- **Concluído:**
  - [x] Removido chips de pré-existência médica nos 3 idiomas (`chat_screen.dart:91-115`). Substituídos por "How to choose the right coverage?". Comentário legal inline.

### B8 — Budget alerts na Google Cloud Console
- **Status:** 🌐 Externo
- **Detalhe:** [PRODUCTION.md §F](PRODUCTION.md)
- **O que falta:**
  - [ ] $30/mês com alertas 50/80/100%
  - [ ] Emails: Diego + Yuri + Renan

### B9 — `dSYMs` no Xcode + Crashlytics
- **Status:** 🌐 Manual Xcode
- **Depende de:** A8

### B10 — Field `licenseNumber` no schema
- **Status:** 👤 Decisão estrutural (mas low-risk) + 🤖 code
- **Detalhe:** [LEGAL.md §11 L8](LEGAL.md)
- **O que falta:**
  - [ ] Adicionar campo em `users/{uid}` e UI de admin
  - [ ] Update Firestore rules (validar string não-vazia)
  - [ ] Update `createSellerAccount` para exigir

---

## Fase C — Decisões estruturais pendentes (👤)

Decisões de produto/arquitetura que **destravam** ou afetam várias tarefas.

### C1 — Schemas duplos: deprecar ou manter
- **Status:** 👤 Decisão Diego
- **Detalhe:** [ARCHITECTURE.md §2.1](ARCHITECTURE.md)
- **Opções:**
  - **A.** Deprecar `/leads` raiz pós-piloto (~1 semana migração + CF backfill)
  - **B.** Manter ambos v1.0, unificar em v1.1
- **Impacto:** afeta `notifyAgentOnNewLead` trigger (F16), `_mergeLeadRows`,
  custo Firestore, complexidade de futuras features.

### C2 — `anthropicProxy` Cloud Function: remover ou proteger
- **Status:** 👤 Decisão Diego
- **Detalhe:** [FUNCTIONS_AUDIT.md §2.3](FUNCTIONS_AUDIT.md)
- **Opções:**
  - **A.** Remover (Cloudflare Worker já cobre) — diminui surface
  - **B.** Manter como fallback + protect com App Check

### C3 — Dead code de IA (`lib/services/ai/`, rewrite `firebase.json`)
- **Status:** 👤 Confirmação Diego
- **Detalhe:** [ARCHITECTURE.md §2.5](ARCHITECTURE.md)
- **Sugestão:** **remover** (não está em uso, rewrite quebrado)

### C4 — Pasta `lib/legacy/`: renomear vs migrar
- **Status:** 👤 Diego (qualidade de vida)
- **Detalhe:** [ARCHITECTURE.md §2.2](ARCHITECTURE.md)
- **Sugestão:** **adiar para v1.1**

### C5 — Lead de agente que sai do tenant — fica com agente ou com Renan?
- **Status:** 👤 Decisão Diego + Renan + advogado
- **Detalhe:** [LEGAL.md §5](LEGAL.md)
- **Impacto:** contratual + privacy + retenção

---

## Fase D — Qualidade de vida e dívidas técnicas (🟡)

Itens que não bloqueiam release nem operação imediata.

### D1 — `AdminSession.load()` cache in-memory
- **Status:** 🤖 Code-safe — snippet pronto
- **Detalhe:** [ARCHITECTURE.md §2.3](ARCHITECTURE.md), [FIRESTORE_AUDIT.md A3](FIRESTORE_AUDIT.md)

### D2 — `_fetchRootLeads` / `_fetchCompanyLeads` em paralelo
- **Status:** ✅ Concluído (2026-05-23)
- **Detalhe:** [FIRESTORE_AUDIT.md A1](FIRESTORE_AUDIT.md)
- **Concluído:**
  - [x] `_loadData` agora usa `Future.wait` para `resolvePublicLinkId`, `_fetchRootLeads` e `_fetchCompanyLeads` em paralelo. ~1 round-trip a menos em iOS slow network.

### D3 — Normalizar dedup em `_mergeLeadRows`
- **Status:** ✅ Concluído (2026-05-23) — paliativo até C1
- **Detalhe:** [FIRESTORE_AUDIT.md A2](FIRESTORE_AUDIT.md), [TROUBLESHOOTING.md §11](TROUBLESHOOTING.md)
- **Concluído:**
  - [x] `_normalizeName` (case + acentos), `_normalizePhone` (só dígitos), `_leadFingerprint` `phone|name`.
  - [x] Dedup agora é **O(n+m)** via `Set<String>` em vez de O(n×m) com `any()`.
  - [x] "José" / "Jose" e "+1 305" / "1305" agora deduplicam corretamente.

### D4 — `companies` query com `.limit()` (preventivo)
- **Status:** 🤖 Code-safe v1.2
- **Detalhe:** [FIRESTORE_AUDIT.md A4](FIRESTORE_AUDIT.md)

### D5 — `createSellerAccount` — password strength, atomicidade
- **Status:** 🤖 Code-safe (snippet pronto)
- **Detalhe:** [FUNCTIONS_AUDIT.md §3.3](FUNCTIONS_AUDIT.md) — F8, F10

### D6 — `systemConfig/app` para feature flags
- **Status:** 🤖 Code + Firestore doc
- **Detalhe:** [ARCHITECTURE.md §3.2](ARCHITECTURE.md)
- **Use case imediato:** `anaChatEnabled` para desligar Ana sem deploy.

### D7 — Atualizar `docs/02-CURRENT_STATUS.md`
- **Status:** 🤖 Code-safe
- **Detalhe:** remover aviso "chat_screen.dart fora do git" — agora está [SECURITY.md S13](SECURITY.md)

### D8 — Age gate no início do funil do prospect
- **Status:** 🤖 Code-safe
- **Detalhe:** [LEGAL.md §11 L10](LEGAL.md)
- **Lógica:** se `nascimento` < 18 anos atrás → bloquear avanço com explicação

### D9 — Sem `print()` em release
- **Status:** 🤖 Code-safe (grep)
- **Detalhe:** [ARCHITECTURE.md §2.6](ARCHITECTURE.md)

### D10 — CI/CD GitHub Actions
- **Status:** 🤖 Code-safe (v1.1)
- **Detalhe:** [ARCHITECTURE.md §2.7](ARCHITECTURE.md)

---

## QA Sprint 2 — Validação no Simulator iPhone 17 (2026-05-26)

Build rodou no simulator do iPhone 17 (iOS 26.4) com sucesso após
correções da task #32. Validação **parcial** — login do agente precisa
de credenciais para destravar telas Sprint 2 (Settings/Legal/Delete).

### ✅ Validado funcionando

- **Splash → Language Screen** transição correta, logo M4LIFE
- **Disclaimer A4 — Language Screen** visível com texto "Educational
  tool. Not insurance advice. Recommendations come from your licensed
  agent." abaixo de "AI · PROTECTION · SALES"
- **Welcome screen** renderiza com M4LIFE branding ("Se algo
  acontecer com você...")
- **Onboarding** abre com 3 campos (Nome, Telefone, Data nascimento)
- **Phone formatter** funciona — digitando `13055551234` resulta em
  `(305) 555-1234` automaticamente
- **Numeric keypad** apropriado para campo Telefone
- **Login do agente** abre via "Área do Agente"
- **Disclaimer regulatório no login** — "Ferramenta educacional. Não
  constitui aconselhamento de seguros." visível no rodapé do login
- **Botão back** funciona em todas as telas testadas
- **i18n** estável — UI em PT renderiza certo

### 🐛 Bugs encontrados

#### BUG-Q1 — Onboarding não scrolla com keyboard aberto ✅ Corrigido

- **Tela:** `language_screen.dart` (onboarding flow após selecionar
  idioma e clicar "DESCOBRIR MEU NÍVEL")
- **Sintoma:** quando o usuário toca em "Telefone" e o numeric keypad
  do iOS sobe, o campo "Data de nascimento" fica completamente
  escondido atrás do teclado.
- **Fix aplicado (2026-05-26):** o `SingleChildScrollView` (L1229) agora
  usa padding-bottom dinâmico:
  ```dart
  padding: EdgeInsets.only(
    left: 28, right: 28,
    bottom: MediaQuery.of(context).viewInsets.bottom + 28,
  ),
  ```
  Quando o keyboard sobe, o padding cresce e o scroll permite alcançar
  o campo. Validar após próximo hot reload.

#### BUG-Q2 — Auto-capitalização do nome inconsistente ✅ Corrigido

- **Tela:** onboarding, campo "Nome completo"
- **Sintoma:** ao digitar "maria" o resultado final no Firestore poderia
  ser "maria" (lowercase). O agente verá um nome assim no dashboard.
- **Fix aplicado (2026-05-26):**
  1. Adicionado parâmetro `textCapitalization` no widget `_Campo`
     (default `TextCapitalization.none`).
  2. O `_Campo` do **Nome** agora passa `TextCapitalization.words`
     (primeira letra de cada palavra automaticamente capitalizada).
  3. Outros campos (Telefone, Data) mantêm `.none` pois não fazem sentido.

#### BUG-Q3 — Não foi possível validar Settings, Legal e Delete account

- **Motivo:** as 3 telas do Sprint 2 (P1, P2, P4) só são acessíveis
  após login do agente. Sem credenciais de teste, não conseguimos
  validar:
  - `/settings` (SettingsScreen)
  - `/legal/privacy` e `/legal/terms` (LegalScreen WebView)
  - Botão "Excluir minha conta" + re-auth dialog + Cloud Function
- **Próximo passo:** Yuri/Diego fornece credenciais de teste OU faz o
  login manualmente e me chama de volta a partir do dashboard.

### ⚠️ Limitações conhecidas do QA workflow (não bug do app)

- **Computer-use `type` não entrega texto para Flutter TextField via
  hardware keyboard** no simulator — precisei usar software keyboard
  do iOS (Toggle Software Keyboard no menu I/O). Limitação da camada
  flutter↔iOS↔macOS simulator, não bug do app. Em iPhone real, o
  teclado nativo funciona normal.
- **Cursor agent ficou com Connection Error** durante a sessão (não
  afeta o build do app, mas alguns rebuilds/lints podem estar
  pendentes).



### E1 — Sign in with Apple
- v1.0 não exige (só email/password hoje). [APPLE_RELEASE.md §3](APPLE_RELEASE.md)

### E2 — Cloud Function `exportMyData` (CCPA automation)
- v1.2 — [LEGAL.md §7.1](LEGAL.md)

### E3 — App Check em modo **enforce**
- 48h após B1 estar limpo.

### E4 — Domínio próprio (livelong.app / hitlook.us)
- v1.1 — [RISKS.md R9](RISKS.md)

### E5 — Unificar schemas (executar C1.A)
- v1.1 após piloto

### E6 — Stripe self-service
- v1.2 — só **fora do app** (Guideline 3.1.3(b))

### E7 — Open Graph dinâmico por agente
- v1.1 — [`docs/05-CHECKLIST.md`](../docs/05-CHECKLIST.md)

---

## Ordem sugerida de execução

Otimizada para destravar bloqueantes em paralelo:

### Sprint 1 (~3 dias — pode rodar agora, sem decisões)
1. **A2** — Info.plist patch (30 min)
2. **B7** — remover chip pre-existing condition (5 min)
3. **A4** — disclaimers nas 3 telas (2h)
4. **A6** parte 1 — Cloudflare Worker Origin allowlist (1h)
5. **B3** — Storage rules hardening (15 min)
6. **B4** — Firestore rules refinos S4 + S5 (15 min)
7. **B6** — email i18n (30 min)
8. **A8** — Crashlytics + Analytics (2h)
9. **B2** — Secret Manager (30 min)
10. **D2 + D3** — paralelizar lead fetch + normalizar dedup (1h)

### Sprint 2 — depende de decisões Diego
11. **C1, C2, C3** — decisões → execução (1-3 dias)
12. **A1** — alinhar identidade após decisão (1h)
13. **A3** — Privacy/Terms HTML scaffolds em EN/PT/ES (1 dia)
14. **B10** — `licenseNumber` field (2h)
15. **D8** — age gate (1h)

### Sprint 3 — depende de externo
16. **A5** — LLC + EIN (1-3 semanas wait)
17. **A7** — advogado FL (1-2h reunião)
18. **A9** — App Store Connect setup
19. **A10** — QA dispositivo real
20. **B5** — Trigger Email validation
21. **B8** — Budget alerts
22. **B1** — App Check monitor

### Sprint 4 — TestFlight
23. Build IPA `flutter build ipa --release`
24. Upload via Transporter
25. TestFlight Internal (Diego + Renan)
26. TestFlight External (5 agentes M4LIFE)
27. Submissão App Review

---

## Convenções para tracking

### Marcar progresso

Edite este arquivo trocando `[ ]` por `[x]`. Adicionar **data** ao concluir:

```
- [x] Adicionar `NSCameraUsageDescription` (2026-05-23)
```

### Commits

Mensagens de commit devem referenciar o ID:

```
fix(R4): add NSCameraUsageDescription and NSPhotoLibraryUsageDescription
feat(B7): remove pre-existing condition chip from Ana suggestions
chore(B2): migrate functions.config() to Secret Manager
```

### Pull requests

PR title: `[A2] Info.plist privacy keys + ITSAppUsesNonExemptEncryption`

PR description deve linkar para a seção do `planning/` correspondente.

---

## Métricas de saúde

A cada semana, atualizar contagem:

| Categoria | Total | Concluído | % |
|-----------|-------|-----------|---|
| 🔴 Bloqueantes (Fase A) | 10 | 4 | 40% |
| 🟠 Alto risco (Fase B) | 10 | 5 | 50% |
| 👤 Decisões (Fase C) | 5 | 0 | 0% |
| 🟡 Dívidas (Fase D) | 10 | 2 | 20% |
| 🎨 Polish (POLISH_AUDIT) | 8 críticos | 5 | 62% |
| **Total v1.0** | **43** | **16** | **37%** |

**Sprint 1 (2026-05-23):** B7, A2, B3, B4, B2, B6, A6 (parte 1), A4, D2, D3, A8, A3.
12 deliverables em uma sessão. 13 arquivos modificados / 6 criados.

**Sprint 2 (2026-05-24) — Polish profissional vs Whenote:**
- **P1** Account deletion in-app (hybrid mode) — Cloud Function `deleteAgentAccount` + UI Settings
- **P2** `SettingsScreen` com Editar perfil, Privacidade, Termos, Sobre, Sair, Excluir conta
- **P4** `LegalScreen` com WebView renderizando `/privacy.html` e `/terms.html`
- **P5** Crashlytics context (`setUserIdentifier`, `setCustomKey('role'…)`)
- **P8** Versão do app exibida no Settings via `package_info_plus`
- Bloqueio de novos leads em seller `isActive: false` (rules)
- Cores `gold`/`goldDim`/`whiteWarm` adicionadas ao `AppColors` central
- Item "Configurações" no popup menu do dashboard
- Rotas `/settings`, `/legal/privacy`, `/legal/terms` no `app_router`
- Detalhes em [POLISH_AUDIT.md](POLISH_AUDIT.md)

**Patch 2026-05-24 — Firebase config audit:**
- iOS `GoogleService-Info.plist`: `IS_ANALYTICS_ENABLED=true` (estava `false`, contradizia A8)
- Android: plugin `com.google.firebase.crashlytics` adicionado em `settings.gradle.kts` + `app/build.gradle.kts`
- `web/env.js`: neutralizado (`Object.freeze({})`) com warning anti-vazamento
- `.firebaserc`: alias `prod` + `targets.hitlook-app.hosting` configurados
- `planning/FIREBASE_PROJECT.md` criado — referência completa dos comandos `firebase` para esse projeto

---

*Criado em 2026-05-23. Próximas revisões a cada sprint de execução.*
