# Live Long / HitLook — Polish Audit (Apple v1.0)

> Comparação de **acabamento profissional** do Live Long contra o
> projeto irmão Whenote (OpenWhen). Foco no que o reviewer da Apple e
> os primeiros 50 agentes vão sentir.
>
> Auditoria: **2026-05-24**. Escopo **Apple-only v1.0** — gaps que
> aparecem só no Android estão marcados como adiados.

---

## 0. Filosofia

Não copiar o Whenote inteiro — Live Long é B2B insurance, não B2C social.
Mas vários padrões do Whenote são neutros e elevam a média do app:

- **i18n via ARB** em vez de `switch (lang)` espalhado no código.
- **Settings screen real** com logout, política, conta.
- **Account deletion in-app** (exigência CCPA + Apple Guideline 5.1.1(v)).
- **Error/empty/offline states** consistentes.
- **About / Help** com Privacy + Terms links.
- **Email verification** do agente.
- **Acessibilidade** mínima (Semantics, contraste).
- **Splash → first action guide** ao primeiro login.

---

## 1. Comparativo dimensão por dimensão

### 1.1 Internacionalização (i18n)

| Dimensão | Whenote | Live Long | Gap |
|----------|---------|-----------|-----|
| Onde mora | `lib/l10n/app_en.arb`, `app_es.arb`, `app_pt.arb`, `app_pt_BR.arb` (ICU plurals) | Maps inline e `switch (lang)` em cada tela | **Alto** — código duplica strings em 3 idiomas em N telas |
| Geração | `flutter gen-l10n` cria `AppLocalizations` | Manual | **Alto** |
| Mudança de idioma em runtime | `locale_provider.dart` + Firestore `preferredLanguage` | URL/cookie só | **Médio** |

**Para v1.0** — não migrar tudo, mas **iniciar o framework**:
- Adicionar `flutter_localizations` ao pubspec (já está em deps via Flutter SDK).
- Criar `lib/l10n/app_*.arb` com **apenas as strings novas** que adicionei
  no Sprint 1 (disclaimers, sugestões da Ana).
- Migrar o resto **incremental** em v1.1+.

🟡 **Recomendação:** **adiar para v1.1.** Migrar i18n inteiro é ~2 dias
de trabalho e não bloqueia App Review. O app já funciona em 3 idiomas
funcionalmente.

### 1.2 Settings screen do agente

| Dimensão | Whenote | Live Long |
|----------|---------|-----------|
| Settings completa | `settings_screen.dart` 2044 linhas | **Não existe** |
| Logout visível | ✅ | ⚠️ Existe em `admin_master_screen` e `agent_dashboard_screen` mas **não** em `agent_setup_screen` |
| Sobre / versão do app | ✅ | ❌ |
| Privacidade — link para política | ✅ | ❌ |
| Termos de uso — link | ✅ | ❌ |
| Idioma do app — toggle | ✅ Riverpod | ❌ |
| Notificações | ✅ | ❌ (sem push v1.0) |
| Excluir conta | ✅ Soft-delete 15d | ❌ — **bloqueia Guideline 5.1.1(v)** |

🔴 **CRÍTICO** para Apple Review: a partir de iOS 14+, Apple exige que
qualquer app que crie conta ofereça **deleção da conta de dentro do
app** (Guideline 5.1.1(v)). Sem isso, **rejeita**.

### 1.3 Account deletion in-app

🔴 **Gap absoluto.** Live Long tem 0 código para deleção self-service.

Whenote tem:
- `core/services/account_deletion_service.dart`
- `core/services/deletion_request_service.dart` (soft-delete + grace 15d)
- `functions/src/delete_account.ts` (cleanup server-side com hash dos UIDs)
- UI no Settings com re-auth, dialog explicativo, banner amarelo de
  cartas pendentes.

Para Live Long v1.0, MVP de deleção:
- Botão "Delete my account" no Settings.
- Dialog: "This will permanently remove your profile and all your leads".
- Re-auth com senha (Firebase Auth requirement).
- Callable function `deleteAgentAccount` que:
  - Deleta `sellers/{id}`, `agents/{uid}`, `agents/{slug}`, `seller_slugs/{slug}`
  - Deleta `companies/{cid}/leads where sellerId == uid` (ou anonimiza)
  - Deleta foto em Storage
  - Deleta Firebase Auth user
- Log hasheado em `accountDeletions/{hashUid}`.

🔴 **BLOQUEIA App Review.** Implementar agora.

### 1.4 Email verification

Whenote: ao registrar, Firebase Auth envia verification email com
template customizado. Senha reset funciona.

Live Long: agentes são criados por admin via `createSellerAccount`
callable com password default. Não há email de welcome com link de
verificação ou primeiro-login. Senha reset existe (✅ — visto em
[`docs/05-CHECKLIST.md`](../docs/05-CHECKLIST.md)).

🟠 **Médio.** Não bloqueia Apple, mas é UX feia: agente recebe credencial
genérica (`HitLook2026!` é o `defaultSellerPassword` em
[`app_config.dart:19`](../lib/core/config/app_config.dart) — 🔴 **MUITO RUIM**).

**Fix mínimo v1.0:**
1. Remover `defaultSellerPassword` literal do código.
2. `createSellerAccount` gera senha temporária aleatória de 16 chars,
   manda email com link "set your password" (Firebase Auth password
   reset link gerado server-side).
3. Documentar fluxo de onboarding do agente.

### 1.5 Error / offline / empty states

Whenote: cada lista tem (a) loading skeleton, (b) error widget com
retry, (c) empty state ilustrado.

Live Long:
- `agent_dashboard_screen` ✅ tem loading + error + empty (já bom).
- `admin_master_screen` ✅ tem.
- `result_screen` ⚠️ sem fallback se Firestore falhar ao salvar lead.
- `chat_screen` ⚠️ erro genérico de "problema técnico" — sem retry button.
- Tela 404 para link inválido ✅ existe.

🟡 **Médio.** Adicionar retry buttons nos catches já existentes —
~1h de trabalho.

### 1.6 About / Help / Legal

Whenote: `legal_screen.dart` mostra Privacy + Terms scroll com
versão e data efetiva.

Live Long: **não existe** equivalente. Os HTML em `web/` (criados em A3)
estão **só na web**. Em mobile app, não há acesso.

🔴 **Apple exige** que o app tenha link para Privacy Policy acessível
de dentro do app (não só na app store description).

**Fix:** adicionar `LegalScreen` que carrega o HTML em WebView OU
abre via `url_launcher` para `hitlook-app.web.app/privacy.html`. Link
no Settings.

### 1.7 Acessibilidade

Whenote: usa `Semantics` em widgets críticos. Cores com contraste
WCAG. Tamanhos de fonte respeitam `MediaQuery.textScaleFactor`.

Live Long:
- Tema preto/dourado tem **contraste baixo** em alguns lugares
  (texto cinza claro em fundo preto está em `AppColors.grey.withOpacity(0.6)`).
- Botões pequenos (alguns abaixo de 44pt de altura — fora do HIG da Apple).
- `Semantics` praticamente ausente.

🟡 **Médio para Apple Review** (rejeição rara). Mas afeta agentes
40+ anos lendo no celular.

### 1.8 Deep linking / Universal Links

Whenote: `apple-app-site-association` em `hosting/public/.well-known/`,
intent filters Android, `DeepLinkCoordinator` no client.

Live Long: deep link só funciona via Flutter web em `https://hitlook-app.web.app/a/{slug}`.
No iOS, abrir esse URL **abre o Safari**, não o app.

🟡 **Adiar para v1.1.** No release v1.0, o app **não substitui** o link
público — agentes continuam enviando o link web pelo WhatsApp do
prospect. O app iOS é só para o agente.

### 1.9 Splash & first-run experience

Whenote: splash → auth check → onboarding 4 telas → first action guide.

Live Long: splash 1.5s → language → onboarding → questions.
**Mas só do PROSPECT.**

Para o **agente** (que é quem vai instalar o app iOS), não há
welcome screen, tutorial, nem first-action guide. Após login cai direto
no dashboard.

🟡 **Médio.** Apple não rejeita, mas reviewer pode achar "minimum
functionality" (Guideline 4.2). Considerar uma tela de boas-vindas
após primeiro login do agente.

### 1.10 Push notifications

Whenote: FCM completo, com `fcmToken` no `users/{uid}`, notification
service, `moderation_notifications_screen`.

Live Long: **não usa push**. Notificações de novo lead vão por **email**
via `notifyAgentOnNewLead`.

🟢 **OK para v1.0.** Email funciona. Push é v1.1+.

### 1.11 Versioning e about

| Dimensão | Whenote | Live Long |
|----------|---------|-----------|
| Mostra versão no Settings | ✅ via `package_info_plus` | ❌ |
| CHANGELOG visível ao user | ❌ (interno) | ❌ |
| Build number incrementa | manualmente | manualmente |

🟡 Adicionar versão no Settings é trivial (1 linha com
`package_info_plus`).

### 1.12 Crashlytics breadcrumbs / context

Whenote: `setUserIdentifier(hashUid)`, `setCustomKey('tier', tier)`.

Live Long: Crashlytics inicializado em A8 mas **sem contexto**.

🟡 Adicionar:
```dart
FirebaseCrashlytics.instance.setUserIdentifier(uid_hash);
FirebaseCrashlytics.instance.setCustomKey('role', role);
FirebaseCrashlytics.instance.setCustomKey('companyId', companyId);
```

### 1.13 Estrutura de pastas profissional

| Whenote | Live Long |
|---------|-----------|
| `features/<area>/data/`, `domain/`, `models/`, `presentation/{providers,screens,widgets}/` | `legacy/` + `features/` esqueletos |
| Riverpod centralizado | StatefulWidget + setState ad-hoc |

🟡 Já documentado em [ARCHITECTURE.md §2.2](ARCHITECTURE.md). Adiar
para v1.1 — não bloqueia release.

### 1.14 Theming

Whenote: 4 temas (Classic, Dark, Midnight, Sepia) via `ThemeProvider` Riverpod.

Live Long: 1 tema fixo (preto/dourado). Apropriado para identidade.
**Não mudar.**

🟢 N/A.

### 1.15 Loading skeletons vs spinner

Whenote: tela de cartas usa skeleton boxes durante load.

Live Long: `CircularProgressIndicator` em tudo.

🟡 Baixo impacto v1.0. Adiar.

### 1.16 Hardcoded admin password — risco crítico

[`lib/core/config/app_config.dart:19`](../lib/core/config/app_config.dart):
```dart
static const defaultSellerPassword = 'HitLook2026!';
```

🔴 **Vazamento.** Qualquer pessoa lendo o repo público sabe a senha
default. Se `createSellerAccount` ainda usa essa constante (auditar),
todos os agentes criados pelo admin têm essa senha inicial até trocarem.

**Fix:**
- Remover a constante.
- `createSellerAccount` gera senha aleatória (crypto random 16 chars)
  no servidor.
- Email automático com link "set your password" via Firebase Auth
  password reset link.

### 1.17 OG meta tags estáticas

[`web/index.html:21-37`](../web/index.html): título e descrição fixos
para "M4LIFE USA — Proteção Familiar". Quando o prospect compartilha
`https://hitlook-app.web.app/a/renan`, deveria mostrar **"Renan Sampaio
te convidou..."** com foto.

🟡 [`docs/02-CURRENT_STATUS.md`](../docs/02-CURRENT_STATUS.md) já
menciona "Open Graph por agente — genérico M4LIFE para todos" como
pendência. Adiar para v1.1.

### 1.18 Privacy event logging

Whenote: `privacy_log_service.dart` registra cada export, deletion
request, reauth.

Live Long: **inexistente.** Para CCPA Right-to-Know auditável, precisa
de log.

🟠 **Médio.** MVP: gravar em `privacyAuditLogs/{hashId}` quando o
usuário tocar "delete my account" ou "export my data". 30 min de
trabalho.

### 1.19 Pull-to-refresh consistente

Whenote: RefreshIndicator em listas.

Live Long: já tem em `agent_dashboard_screen` ✅ — bom. Estender para
`admin_master_screen` e `admin_company_screen`.

🟢 Já bom.

### 1.20 Empty state ilustrado

Live Long: empty state textual "Nenhum lead ainda" no dashboard.
Whenote: ícone + título + subtítulo + CTA.

🟢 Aceitável v1.0.

---

## 2. Matriz de prioridade para v1.0

| # | Gap | Severidade | Esforço | Faz v1.0? |
|---|-----|------------|---------|-----------|
| P1 | **Account deletion in-app** (1.3) | 🔴 bloqueia Apple Review | Alto (1 dia) | **Sim** |
| P2 | **Settings screen** com logout + Sobre + links Legal (1.2, 1.6, 1.11) | 🔴 bloqueia Apple Review | Médio (4h) | **Sim** |
| P3 | **Remover `defaultSellerPassword` literal** (1.16) | 🔴 vazamento crítico | Baixo (30 min) | **Sim** |
| P4 | **Legal screen** in-app (Privacy + Terms) (1.6) | 🔴 bloqueia Apple Review | Baixo (1h) | **Sim** |
| P5 | **Crashlytics context** (`setUserIdentifier`, `setCustomKey`) (1.12) | 🟠 importante | Baixo (30 min) | **Sim** |
| P6 | **Privacy event log** mínimo (1.18) | 🟠 CCPA audit trail | Baixo (1h) | **Sim** |
| P7 | **Retry buttons** em catches (`chat_screen`, `result_screen` save) (1.5) | 🟡 polish | Baixo (1h) | **Sim** |
| P8 | **Versão do app no Settings** (1.11) | 🟡 polish | Baixo (15 min) | **Sim** |
| P9 | **Acessibilidade básica** (1.7) | 🟡 | Médio (2h) | Parcial |
| P10 | **i18n via ARB** (1.1) | 🟡 | Alto (1-2 dias) | **Não** — v1.1 |
| P11 | **Email verification + welcome** (1.4) | 🟠 | Médio (3h) | **Sim** parte (rm default password) |
| P12 | **Splash + first-run para agente** (1.9) | 🟡 | Médio (3h) | **Não** — v1.1 |
| P13 | **Deep linking universal links** (1.8) | 🟡 | Médio (1 dia) | **Não** — v1.1 |
| P14 | **Push notifications** (1.10) | 🟢 | Alto | **Não** — v1.1 |
| P15 | **OG meta por agente** (1.17) | 🟡 | Médio | **Não** — v1.1 |
| P16 | **Loading skeletons** (1.15) | 🟢 | Baixo | **Não** — v1.1 |
| P17 | **Refactor `lib/legacy/` → `features/`** (1.13) | 🟡 | Alto | **Não** — v1.1 |

**Total para v1.0:** **8 itens críticos** (P1-P8) + parte de P11.
Estimativa: **2 dias de trabalho concentrado**.

---

## 3. Plano de execução para Sprint 2

Ordem otimizada para destravar Apple Review:

1. **P3** — Remover `defaultSellerPassword` literal (30 min) — security.
2. **P4** — `LegalScreen` que abre `privacy.html` / `terms.html` via WebView (1h).
3. **P2** — `SettingsScreen` com logout, Sobre, version, links (4h).
4. **P1** — Account deletion: callable `deleteAgentAccount` + UI Settings (1 dia).
5. **P5** — Crashlytics context após login (30 min).
6. **P6** — Privacy audit log básico (1h).
7. **P7** — Retry buttons (1h).
8. **P8** — Versão app no Settings (15 min, junto com P2).
9. **P11 parcial** — `createSellerAccount` gera senha aleatória + envia email
   set-password (2h).

---

## 4. Validação no simulator iPhone 17

Após executar P1-P8 + P11 parcial, abrir Xcode e validar:

- [ ] Tela do prospect renderiza com disclaimer
- [ ] Login do agente funciona
- [ ] Settings abre com todas as opções
- [ ] Logout funciona e retorna pro Language Screen
- [ ] "Delete my account" funciona com re-auth
- [ ] Privacy Policy abre dentro do app
- [ ] Crash forçado é registrado no Crashlytics dashboard
- [ ] Modo avião → app mostra estados de erro razoáveis, não crasha
- [ ] Pull-to-refresh no dashboard funciona offline → online

---

*Documento criado em 2026-05-24 durante a transição Sprint 1 → Sprint 2.*
