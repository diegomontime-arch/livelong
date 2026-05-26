# Live Long / HitLook — Apple Release Playbook

Guia focado em **subir para TestFlight → App Review** sem retrabalho. Tudo o
que é específico de Apple/iOS está aqui; itens cross-platform vivem em
[PRODUCTION.md](PRODUCTION.md).

> Auditoria de `ios/` em **2026-05-23** sobre o repositório `livelong` no
> commit atual de `master`.

---

## 1. Estado atual do projeto iOS

Levantado por inspeção direta:

| Item | Estado | Onde |
|------|--------|------|
| Bundle ID | `com.livelong.livelong` | `ios/Runner.xcodeproj/project.pbxproj` |
| Development Team | `UGDFYNG9SK` | idem |
| Code Sign Style | `Automatic` | idem |
| Deployment Target | `13.0` | idem |
| Marketing version | `1.0` (via `$(FLUTTER_BUILD_NAME)`) | `pubspec.yaml:19` → `1.0.0+1` |
| Current Project Version | `1` (via `$(FLUTTER_BUILD_NUMBER)`) | idem |
| `CFBundleName` | `hitlook` | `ios/Runner/Info.plist:18` |
| `CFBundleDisplayName` | `Livelong` | `ios/Runner/Info.plist:10` |
| AppDelegate usa `FlutterImplicitEngineDelegate` | ✅ | `ios/Runner/AppDelegate.swift` |
| Scene Delegate ativo | ✅ Vazio (apenas `import UIKit`) | `ios/Runner/SceneDelegate.swift` |
| Firebase iOS configurado | ✅ `GoogleService-Info.plist` presente | `ios/Runner/` |
| AppIcon 1024×1024 sem alpha | ✅ Verificado: PNG RGB | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` |
| Demais ícones | ✅ Paleta indexada, sem alpha | mesma pasta |

---

## 2. Bloqueadores absolutos antes de submeter

### 2.1 Decidir nome final ("HitLook" vs "Livelong")

🟡 **DECISÃO PENDENTE — Diego.**

O conflito interno:

- `CFBundleDisplayName = Livelong` → springboard mostra "Livelong"
- `CFBundleName = hitlook` → nome interno
- `pubspec.yaml:1` `name: hitlook`
- Documentos `docs/01-VISION.md` e `docs/03-ARCHITECTURE.md` falam de
  "HitLook como motor invisível" e tenants (M4LIFE, Portobello)
- Bundle ID: `com.livelong.livelong`

Apple Review **vai questionar** se o nome no springboard, no metadata da
loja, e no Info.plist forem inconsistentes. Decisão precisa ser **uma das
abaixo** e aplicada em **todos** os pontos:

| Opção | Implicação |
|-------|------------|
| **A. HitLook** | Trocar `CFBundleDisplayName=HitLook`, registrar `com.hitlook.app` no Apple Developer, regerar provisioning, criar app novo na App Store Connect. **Reescrever Bundle ID** é uma break-change para Firebase (precisa recriar app iOS no Firebase). |
| **B. Livelong** | Manter `com.livelong.livelong`. Alinhar `CFBundleName=Livelong`, rebrand do `docs/` futuramente. Menos esforço técnico, mas conflita com o domínio `hitlook-app.web.app` em produção web. |
| **C. M4LIFE (white-label do tenant)** | App específico do Renan. **Não recomendado v1** — `docs/03-HONEST_ASSESSMENT.md` §3 explicitamente diz que multi-tenant é fuga de engenheiro antes do primeiro cliente. Mas para Apple Review, pode ajudar — uma app por tenant é mais claro do que "multi-tenant SaaS". |

**Recomendação técnica (não decisão de produto):** se o release iOS vai
servir **apenas agentes M4LIFE no piloto**, fazer **opção C** com bundle
`com.m4life.app` e marketing como "M4LIFE Consultant" — Apple aprova
mais rápido e Diego mantém HitLook como engine invisível. Mas isso depende
da estratégia de venda — pergunte antes de mudar.

### 2.2 Info.plist sem chaves de privacidade

Atual `ios/Runner/Info.plist` (verificado em 2026-05-23) **não tem** nenhuma
chave de privacidade. Mas o app **usa**:

- `image_picker` (`pubspec.yaml:46`) — câmera + biblioteca
- `url_launcher` (`pubspec.yaml:48`) — abrir WhatsApp

iOS **mata o app em runtime** quando o usuário toca em "trocar foto" sem a
chave declarada. Garante 1 estrela e rejeição.

**Patch obrigatório** ([PRODUCTION.md §C](PRODUCTION.md) tem o snippet pronto).

### 2.3 Política de Privacidade pública

App Store Connect tem campo obrigatório **Privacy Policy URL**. Sem ele a
submissão nem inicia.

- Mais rápido: criar `web/privacy.html` e `web/terms.html` dentro do
  diretório web do Flutter (vai para `build/web/` no `flutter build web`).
  O `firebase.json` já tem `hosting.public = build/web`, então o deploy do
  Hosting publica.
- Conteúdo mínimo:
  - Quem coleta o quê (prospect: nome/tel/idade/respostas; agente: email/foto/bio).
  - Onde armazena (Firebase US/EU).
  - 3rd-party: Google (Firebase), Anthropic (Ana), Cloudflare (Worker).
  - Retenção: 24 meses para prospects não convertidos (alinhar
    [`docs/07-RISKS.md`](../docs/07-RISKS.md) §8).
  - Contato: email do DPO (sugerir `privacy@m4life.us` se Renan
    autorizar — ou `diego@hitlook.…`).

### 2.4 Disclaimer regulatório visível

Hoje o disclaimer "não é insurance advice" **só existe dentro do system
prompt** da Ana ([`chat_screen.dart:60`](../lib/legacy/screens/chat_screen.dart)).
Apple não consegue inspecionar prompts internos. Regulador estadual
(Florida DFS) também não.

Adicionar em **3 lugares**:

1. **Tela de splash do prospect** (`hitlook_splash_screen.dart`): texto
   pequeno embaixo "Educational tool. Not insurance advice."
2. **Tela da Ana** (`chat_screen.dart`): banner abaixo do header
   ("M4LIFE Assistant • Online") com o disclaimer.
3. **Tela de resultado** (`result_screen.dart`): antes do botão
   "Falar com consultor", uma linha "Recommendations come from your licensed
   M4LIFE consultant, not from this app."

### 2.5 `ITSAppUsesNonExemptEncryption`

App só usa HTTPS padrão. Adicionar `<key>ITSAppUsesNonExemptEncryption</key><false/>`
no Info.plist evita o questionário de exportação em **toda** submissão.

---

## 3. Sign in with Apple — quando é obrigatório?

Apple Guideline **4.8** exige Sign in with Apple **se** o app oferecer
qualquer outro login social (Google, Facebook, X, etc.).

Hoje o `livelong` tem **apenas email/senha** ([`agent_login_screen.dart`](../lib/legacy/screens/agent_login_screen.dart)).
Não há Google Sign-In. **Então SIWA não é obrigatório no release 1.0.**

Mas:

- Adicionar SIWA agora é **fácil** (~ 3h de trabalho — referência:
  [Whenote CHANGELOG seção "Sign in with Apple"](../../OpenWhen/planning/CHANGELOG.md)).
- Adicionar SIWA depois — quando vier o Google Sign-In — exige nova
  capability, novo deploy, nova review.

Recomendação: **adiar para v1.1** se a estratégia for "Renan cria os
agentes manualmente via [`createSellerAccount`](../functions/index.js)".

---

## 4. App Privacy ("nutrition labels") — preenchimento detalhado

Cada submissão exige declarar dados coletados em App Store Connect →
*App Privacy*. Para `livelong`:

| Categoria | Tipo de dado | Usado para | Linked to user? | Tracking? |
|-----------|--------------|------------|----------------|-----------|
| Contact Info | Email | App Functionality (auth) | Yes | No |
| Contact Info | Phone Number | App Functionality (lead/WhatsApp) | Yes | No |
| User Content | Photos or Videos | App Functionality (foto agente) | Yes | No |
| User Content | Other User Content (respostas do questionário, chat) | App Functionality, Product Personalization | Yes | No |
| Identifiers | User ID (Firebase UID) | App Functionality | Yes | No |
| Usage Data | Product Interaction | Analytics (se Analytics ligado) | Yes | No |
| Diagnostics | Crash Data | App Functionality | No | No |
| Diagnostics | Performance Data | App Functionality | No | No |

**Importante**: o chat com Ana **envia conteúdo do usuário para a Anthropic**
(via Cloudflare Worker → `api.anthropic.com`). Isso precisa ser declarado
explicitamente no campo *Third-Party Partners* da política de privacidade.
Não declarar = rejeição na Guideline 5.1.

---

## 5. Build, assinatura e upload

### 5.1 Pré-requisitos no Mac

```bash
# Versões mínimas
xcode-select --print-path                   # /Applications/Xcode.app/...
flutter --version                           # 3.41+
cd ios && pod --version && cd ..            # 1.16+
```

### 5.2 Configurar assinatura

1. Abrir `ios/Runner.xcworkspace` no Xcode.
2. Target **Runner** → **Signing & Capabilities**:
   - Team: `UGDFYNG9SK` (Diego).
   - Bundle Identifier: igual ao decidido em §2.1.
   - Provisioning: **Automatically manage signing** (ok para 1ª submissão).
3. Capabilities ativas necessárias:
   - **Push Notifications**: ❌ não adicionar (não usado).
   - **Sign in with Apple**: ❌ não adicionar v1 (ver §3).
   - **Background Modes**: ❌ não adicionar.

### 5.3 Build de release

```bash
# Limpar
flutter clean
flutter pub get

# Pods iOS
cd ios && pod install --repo-update && cd ..

# IPA (sem export options se for fazer upload pelo Xcode Organizer)
flutter build ipa --release \
  --build-name=1.0.0 \
  --build-number=1
```

Saída: `build/ios/ipa/livelong.ipa`. Upload via **Transporter** ou Xcode
Organizer.

### 5.4 dSYMs e Crashlytics

`firebase.json:33` está com `"uploadDebugSymbols": false`. **Mudar para
`true` antes do release** — sem dSYMs, Crashlytics mostra stack traces
inúteis.

Após o primeiro build, Xcode → Organizer → Archives → seleciona o build →
*Distribute App* → *App Store Connect* → *Upload* → marcar **Upload your
app's symbols**.

---

## 6. TestFlight

Aprovação interna (até 100 usuários, sem review): **imediato após upload
processado** (~15 min após Transporter).

Aprovação **externa** (testers de fora da team): exige **Beta App Review**,
geralmente 24-48h.

### 6.1 TestFlight Internal

- Adicionar `diegomontime@…` e Renan como **Internal Testers** (precisam de
  Apple ID).
- Cada um instala o app TestFlight e baixa o build.
- Validar manualmente:
  - Login com email/senha de um agente seed.
  - Abrir `https://hitlook-app.web.app/a/diego-teste` no Safari iOS — fluxo
    público funciona via Universal Link (ainda não configurado v1, então
    abre no Safari, ok).
  - Botão "Falar com consultor" abre o app WhatsApp (precisa do app
    instalado).
  - Foto de agente: `image_picker` → câmera → permissão exibida →
    foto enviada para Storage `agents/{uid}/photo`.

### 6.2 TestFlight External (recomendado antes da App Store)

Adicionar **5 agentes M4LIFE indicados pelo Renan** como External Testers.
Coletar feedback por 7 dias. Métricas alvo:

- 100% conseguem logar.
- 80%+ enviam ao menos 1 link para teste.
- 0 crashes no Crashlytics.

---

## 7. App Review — submissão final

### 7.1 Notas para o reviewer (campo "App Review Information")

```
HitLook is a B2B SaaS tool for licensed insurance agents in the US.
It helps them qualify prospects via WhatsApp using an educational AI
assistant ("Ana").

The AI does NOT recommend insurance products. It provides general
financial education only. All recommendations are delivered by the
human licensed agent via WhatsApp after the prospect completes the
questionnaire.

Test account (login):
  email: apple-review@hitlook.test
  password: [definir]

Public flow (no login required):
  https://hitlook-app.web.app/a/diego-teste

Privacy Policy: https://hitlook-app.web.app/privacy.html
Terms of Use:    https://hitlook-app.web.app/terms.html
```

### 7.2 Riscos de rejeição (e mitigação)

| Guideline | Risco | Mitigação |
|-----------|-------|-----------|
| **1.4.1 — Medical & Insurance** | Ana parecer dar insurance advice | Disclaimer em 3 telas + system prompt + texto na descrição da loja |
| **2.5.1 — Private APIs** | N/A (Flutter padrão) | — |
| **4.2 — Minimum Functionality** | App parecer "só um web view" do `/a/...` | Tela do agente é nativa, login, dashboard, perfil — não é WebView |
| **4.8 — Sign in with Apple** | N/A se não tiver Google/Facebook | Confirmar que **não** há SIWA exigido por ausência de outro social login |
| **5.1.1 — Data Collection** | Política incompleta, ATT ausente | §2.3 + ATT só se Analytics+IDFA |
| **5.1.2 — Data Use & Sharing** | Não declarar Anthropic como 3rd-party | Declarar na Privacy Policy explicitamente |
| **3.1.1 — In-App Purchase** | N/A v1 | Sem IAP; cobrança Stripe **fora** do app é ok porque é B2B SaaS, não consumível digital |
| **2.1 — App Completeness** | Schemas duplos quebrarem em runtime | QA dispositivo real ANTES de submeter |

### 7.3 Erros comuns no Transporter

Documentar conforme acontecerem (ver
[`OpenWhen/planning/TROUBLESHOOTING.md`](../../OpenWhen/planning/TROUBLESHOOTING.md)
para padrão). Principais até hoje observados em outros Flutter Firebase
apps:

- `ITMS-90683` Missing Purpose String — **resolvido pelo §2.2** (Info.plist).
- `ITMS-90809` Deprecated API Usage (UIWebView) — Flutter 3.41+ não usa, mas
  confirmar após `flutter clean`.
- `Invalid Bundle` por incluir `Frameworks/Flutter.framework/Flutter` com
  arch x86_64 — **rodar `flutter build ipa --release`** (não `flutter build
  ios --release` puro).

---

## 8. Versão por release — convenção

| Versão | Build | Quando |
|--------|-------|--------|
| 1.0.0 | 1 | Primeira submissão TestFlight |
| 1.0.0 | 2,3,… | Iterações até passar review |
| 1.0.1 | N+1 | Hotfix pós-loja |
| 1.1.0 | N+1 | Feature (ex: Sign in with Apple) |

Sempre atualizar **build number** (`+N` em `pubspec.yaml`) — Apple rejeita
upload com o mesmo build number.

---

*Última atualização: 2026-05-23.*
