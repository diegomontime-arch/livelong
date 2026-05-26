# Live Long / HitLook — Checklist de Produção

> Roadmap operacional para colocar o app na App Store. Inspirado no
> [PRODUCTION.md do Whenote](../../OpenWhen/planning/PRODUCTION.md).
>
> **Atenção:** o repositório foi auditado em **2026-05-23**. Itens marcados
> `🟡 DECISÃO PENDENTE` precisam de Diego antes de prosseguir.

---

## 0. tl;dr do estado atual

| Vertical | Estado | Bloqueia App Store? |
|----------|--------|---------------------|
| Fluxo público (web) | ✅ Em produção em `hitlook-app.web.app` | Não — não é o release iOS |
| Build iOS | ⚠️ Configurado para Flutter, **nunca submetido** | Sim, ver §A |
| Bundle ID iOS | ⚠️ `com.livelong.livelong`, mas `CFBundleName=hitlook`, `CFBundleDisplayName=Livelong` | Sim — alinhar com a identidade do produto |
| Sign in with Apple | ❌ Não implementado | **Sim**, se houver qualquer outro login social |
| App Privacy / nutrition labels | ❌ Não preenchido em App Store Connect | Sim |
| ATT (App Tracking Transparency) | ❌ Sem `NSUserTrackingUsageDescription` | Sim se quiser usar analytics com IDFA |
| Firebase App Check | ❌ Não ativo | Não bloqueia release, mas **bloqueia produção segura** |
| Firebase Analytics / Crashlytics | ❌ Não inicializado | Forte recomendação antes do release |
| Schemas Firestore duplos (`leads` raiz + `companies/.../leads`) | ⚠️ Convivem — duplo write em `result_screen.dart` | Não bloqueia, mas **dívida grave** ([ARCHITECTURE.md](ARCHITECTURE.md) §3) |
| Anthropic API key | ✅ Atrás do Cloudflare Worker (`cloudflare/worker.js`) | OK |
| `anthropicProxy` em `functions/index.js` | ⚠️ Permite POST anônimo de qualquer origem (`Access-Control-Allow-Origin: *`) | **Sim** — desativar ou proteger ([FUNCTIONS_AUDIT.md](FUNCTIONS_AUDIT.md)) |
| Disclaimer "não é insurance advice" | ⚠️ Existe no system prompt da Ana, **falta em UI visível** | Apple e regulador americano podem rejeitar |
| Política de Privacidade pública | ❌ Não encontrada no repo | Sim (App Store exige URL) — estrutura em [LEGAL.md §3](LEGAL.md) |
| Termos de Uso públicos | ❌ Não encontrados | Sim — estrutura em [LEGAL.md §4](LEGAL.md) |
| Entidade jurídica (LLC) + EIN | ❌ Não formalizada | **Sim** — App Store Connect exige tax ID. [LEGAL.md §10](LEGAL.md) |
| Insurance regulatory analysis | ⚠️ Mapeada em [LEGAL.md](LEGAL.md) §1.2, mas falta consulta com advogado FL | Sim ([RISKS.md R1](RISKS.md)) |

> Se o objetivo é "subir para TestFlight em 7 dias" — faça **fase A → B → C → F**.
> Se o objetivo é "ir para review pública na App Store" — faça **todas**.

---

## A. Identidade do app e build iOS

- [ ] **Decidir nome final** entre **HitLook** e **Livelong** (atualmente
      `CFBundleDisplayName=Livelong`, `CFBundleName=hitlook`,
      `package=hitlook` em [`pubspec.yaml:1`](../pubspec.yaml)). Apple usa
      `CFBundleDisplayName` no springboard.
      🟡 **DECISÃO PENDENTE** para Diego.
- [ ] **Bundle ID final** em [`ios/Runner.xcodeproj/project.pbxproj`](../ios/Runner.xcodeproj/project.pbxproj):
      atual `com.livelong.livelong` (visto via grep `PRODUCT_BUNDLE_IDENTIFIER`).
      Confirmar que este ID está registrado no Apple Developer Portal **e**
      no Firebase project `hitlook-app` (atualmente o app iOS no `firebase.json`
      tem `appId: 1:807145542991:ios:8f54c4325326d8cac2a13a` — verificar
      bundle associado no console).
- [ ] **`pubspec.yaml`** ainda está em `version: 1.0.0+1` — para a 1ª
      submissão, manter `1.0.0+1`, mas garantir que cada build novo incrementa
      `+N`.
- [ ] **DEVELOPMENT_TEAM** já está definido como `UGDFYNG9SK` no `project.pbxproj`.
      Confirmar que Diego tem acesso ativo a esta team.
- [ ] **IPHONEOS_DEPLOYMENT_TARGET** está em `13.0` — Flutter 3.41+ exige
      iOS 13 mínimo, ok. Não baixar.
- [ ] Definir **assinatura de release** (Apple Distribution + Provisioning
      Profile App Store) — atualmente `CODE_SIGN_STYLE = Automatic`, o que
      funciona se Xcode estiver logado com a Team `UGDFYNG9SK`. Para CI/CD,
      mudar para `Manual` e exportar perfis.
- [ ] Comando de build de release iOS validado localmente:
      ```bash
      flutter clean && flutter pub get
      cd ios && pod install --repo-update && cd ..
      flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
      ```
      (`ExportOptions.plist` ainda **não existe** no repo — criar.)

---

## B. Ícones, splash e assets nativos

- [ ] **Ícone 1024×1024**
      (`ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`)
      está em **PNG RGB sem alpha** — ✅ ok para App Store (Apple rejeita 1024
      com canal alpha). **Verificado em 2026-05-23.**
- [ ] Demais ícones (`20x`, `29x`, `40x`, `60x`, `76x`, `83.5x`) estão presentes
      em `8-bit colormap` (paleta) — ok para iOS.
- [ ] Confirmar que o ícone **representa o produto que vai à loja** (não a
      coruja "símbolo pessoal de Diego" mencionada em [`docs/03-HONEST_ASSESSMENT.md`](../docs/03-HONEST_ASSESSMENT.md) §9).
- [ ] LaunchScreen está apontada para storyboard `LaunchScreen` (Info.plist L52).
      Verificar visual em Xcode — atualmente um Flutter default.
- [ ] Adicionar `fonts:` em [`pubspec.yaml`](../pubspec.yaml) **só se** o tema
      `AppTheme.dark` ([`lib/core/theme/app_theme.dart`](../lib/core/theme/app_theme.dart))
      depender de tipografia custom. A revisão de 2026-05-23 não encontrou
      `Schyler`/`TrajanPro` em uso real — manter `uses-material-design: true`.

---

## C. Info.plist — chaves obrigatórias para Apple Review

Estado atual de [`ios/Runner/Info.plist`](../ios/Runner/Info.plist) auditado em
2026-05-23. **Faltam todas as chaves de privacidade abaixo**, e a app **usa**
recursos que as exigem.

| Chave | Por quê | Status |
|-------|---------|--------|
| `NSCameraUsageDescription` | `image_picker` (`pubspec.yaml:46`) pode acionar câmera. Sem isto → **crash em runtime** em iOS 10+ | ❌ ADICIONAR |
| `NSPhotoLibraryUsageDescription` | `image_picker` lê biblioteca de fotos (perfil do agente) | ❌ ADICIONAR |
| `NSPhotoLibraryAddUsageDescription` | Só se o app salvar imagens — talvez não, mas avaliar | 🟡 opcional |
| `NSUserTrackingUsageDescription` | Necessário **se** integrar Firebase Analytics com IDFA. Sem isto, ATT prompt não pode ser exibido | ⚠️ ADICIONAR antes de ligar Analytics |
| `LSApplicationQueriesSchemes` (`whatsapp`, `whatsapp-bizapp`) | `whatsapp_utils.dart` usa `url_launcher` para `https://wa.me/...` — `wa.me` funciona via universal link, mas se o app testar `canLaunch('whatsapp://send?...')` Apple exige declarar o scheme | ⚠️ ADICIONAR para evitar warning |
| `LSApplicationQueriesSchemes` (`mailto`, `tel`) | Idem se o app abrir email/telefone | 🟡 opcional |
| `ITSAppUsesNonExemptEncryption` = `false` | App não usa cripto não-exempta. Sem esta chave → Apple pergunta a cada submissão | ⚠️ ADICIONAR |
| `CFBundleURLTypes` | Se um dia houver deep link `hitlook://` ou `livelong://` | 🟡 só se necessário |
| `UIBackgroundModes` | App **não** precisa hoje. Não adicionar sem motivo (Apple rejeita) | ✅ não adicionar |
| `NSAppTransportSecurity` overrides | App só fala HTTPS (Firestore, Worker Cloudflare, Anthropic via proxy). **Não** adicionar exceções ATS | ✅ ok |

**Patch sugerido** para Info.plist (apenas as 4 críticas):

```xml
<key>NSCameraUsageDescription</key>
<string>HitLook precisa da câmera para você adicionar uma foto ao seu perfil de agente.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>HitLook acessa suas fotos para você escolher uma imagem de perfil.</string>

<key>ITSAppUsesNonExemptEncryption</key>
<false/>

<key>LSApplicationQueriesSchemes</key>
<array>
  <string>whatsapp</string>
</array>
```

---

## D. Sign in with Apple

🟡 **DECISÃO PENDENTE.** Apple exige **Sign in with Apple** sempre que o app
oferece *qualquer outro* login social (Google, Facebook, etc.). Hoje o app **só
tem login com email/senha** ([`agent_login_screen.dart`](../lib/legacy/screens/agent_login_screen.dart)),
então Sign in with Apple **não é obrigatório**.

**Mas:**

1. Apenas **admin** (Renan / Diego) e **agentes pré-cadastrados** fazem login.
   Prospect não cria conta. Isso reduz a importância de SIWA.
2. Se um dia houver Google Sign-In para agentes (acelerar onboarding fora da
   M4LIFE), **SIWA passa a ser obrigatório** no mesmo release.

Se for adicionar agora (recomendado, simplifica futuro):

- [ ] Adicionar capability `Sign In with Apple` em
      `ios/Runner/Runner.entitlements` (criar — não existe hoje).
- [ ] `pubspec.yaml`: adicionar `sign_in_with_apple: ^6.x`.
- [ ] No Firebase Console → Authentication → Sign-in method → ativar Apple.
- [ ] Configurar Service ID + Key (.p8) no Apple Developer Portal.
- [ ] Ver fluxo de referência em
      [`OpenWhen/planning/CHANGELOG.md`](../../OpenWhen/planning/CHANGELOG.md)
      seção "Sign in with Apple" — usa `OAuthProvider('apple.com')` com nonce
      SHA-256, exatamente como Apple recomenda.

---

## E. App Privacy (nutrition labels) e Política de Privacidade

App Store Connect exige preencher antes de cada submissão:

- [ ] **Data Collected:**
      - Nome, telefone, data nascimento (prospect) → "Contact Info" + "Identifiers"
      - Email do agente (auth) → "Contact Info"
      - Foto do agente (Storage) → "User Content"
      - Respostas do questionário → "Other → Other User Content"
      - Conversa com Ana → "User Content" (chat) **e** envia para 3rd-party
        (Anthropic via Cloudflare Worker) → declarar **Tracking? Não. Linked to
        user? Sim.**
- [ ] **Política de Privacidade pública** com URL HTTPS estável.
      Sugestão de URL: `https://hitlook-app.web.app/privacy` (servir como
      static HTML via Firebase Hosting; ver `hosting.rewrites` em
      [`firebase.json`](../firebase.json)).
      Modelo: [`OpenWhen/hosting/public/privacy.html`](../../OpenWhen/hosting/public/privacy.html).
- [ ] **Termos de Uso** com URL público. Sugestão: `/terms.html` no mesmo host.
- [ ] **Disclaimer regulatório explícito**, baseado em
      [`docs/07-RISKS.md`](../docs/07-RISKS.md) §1:
      > "Esta ferramenta é educacional. Não fornece aconselhamento de seguros.
      > Toda recomendação deve vir de um agente licenciado pelo seu estado."
      — exibir em (1) splash do prospect, (2) topo da `ChatScreen` com Ana,
      (3) política de privacidade. **Hoje só existe dentro do system prompt
      da Ana — Apple e regulador não veem.**
- [ ] **CCPA/CPRA + LGPD** (já mencionado em [`docs/07-RISKS.md`](../docs/07-RISKS.md) §8):
      botão "Excluir meus dados" — pode ser link `mailto:privacy@…` em v1.

---

## F. Firebase — backend e produção

| Ação | Estado | Comando |
|------|--------|---------|
| Deploy de regras Firestore | ✅ Arquivo robusto auditado em [SECURITY.md](SECURITY.md) | `firebase deploy --only firestore:rules` |
| Deploy de regras Storage | ⚠️ **Frágil**: só protege `agents/{uid}/photo` (1 path) | `firebase deploy --only storage` |
| Deploy de índices | ✅ Definidos para `sellerId+createdAt` e `agentId+createdAt` ([`firestore.indexes.json`](../firestore.indexes.json)) | `firebase deploy --only firestore:indexes` |
| Deploy de Cloud Functions | ✅ `npm install` dentro de `functions/` e `firebase deploy --only functions` | ver [FUNCTIONS_AUDIT.md](FUNCTIONS_AUDIT.md) |
| `anthropic.key` em `functions.config()` | ⚠️ Deprecado no Node 18+; migrar para Secret Manager | `firebase functions:secrets:set ANTHROPIC_API_KEY` |
| **Budget alerts** na Google Cloud Console | ❌ Não documentado como configurado | Limite sugerido inicial: **$30/mês** (alertas 50/80/100%). Renan + Diego + Yuri por email |
| **App Check** | ❌ **Não habilitado** | Ver §G abaixo |
| **Firebase Analytics** | ❌ Não inicializado no `bootstrap.dart` | Ver §G |
| **Firebase Crashlytics** | ❌ Não inicializado | Ver §G |

### F.1 — Migrar `functions.config()` → Secret Manager

Hoje [`functions/index.js:29`](../functions/index.js) usa
`functions.config().anthropic?.key` — **deprecado** em Firebase Functions v2
e Node 24. Plano:

1. `firebase functions:secrets:set ANTHROPIC_API_KEY`
2. Trocar `anthropicProxy` para `onRequest({ secrets: ['ANTHROPIC_API_KEY'] }, ...)`
3. Ler `process.env.ANTHROPIC_API_KEY` em vez de `functions.config()`.
4. **Bonus:** se a Ana já chama o Cloudflare Worker (`AnaProxyConfig.workerBase`),
   a `anthropicProxy` em `functions/index.js` **não está em uso** —
   considerar **remover** a função para reduzir superfície de ataque.
   🟡 **DECISÃO PENDENTE.**

---

## G. Observabilidade e App Check (segurança de produção)

> Inspirado em [`OpenWhen/planning/PRODUCTION.md`](../../OpenWhen/planning/PRODUCTION.md)
> §5 — Whenote habilitou App Check em 2026-05-03 e isso protege as Cloud
> Functions de uso indevido por bots.

### G.1 — App Check (anti-abuso)

Sem App Check, qualquer pessoa que descobrir o endpoint do Cloudflare Worker
ou do `anthropicProxy` pode queimar a chave Anthropic. Risco real, já
mencionado em [`docs/07-RISKS.md`](../docs/07-RISKS.md) §4.

- [ ] Adicionar `firebase_app_check: ^0.x` ao `pubspec.yaml`.
- [ ] Em [`lib/core/bootstrap.dart`](../lib/core/bootstrap.dart) após
      `Firebase.initializeApp`, chamar:
      ```dart
      await FirebaseAppCheck.instance.activate(
        appleProvider: AppleProvider.deviceCheck,    // iOS prod
        androidProvider: AndroidProvider.playIntegrity,
        webProvider: ReCaptchaV3Provider('SITE_KEY'),
      );
      ```
- [ ] No Firebase Console → App Check → ativar para Firestore, Storage,
      Functions. Começar em **modo monitor**, migrar para **enforce** após 48h
      de tráfego limpo.
- [ ] Modificar `anthropicProxy` (se mantida) para
      `onCall({ enforceAppCheck: true })` em vez de `onRequest`.
- [ ] Cloudflare Worker: validar o cabeçalho `X-Firebase-AppCheck` em
      `worker.js` antes de fazer proxy. Hoje aceita qualquer POST.

### G.2 — Firebase Analytics

- [ ] Adicionar `firebase_analytics: ^11.x`.
- [ ] Em `bootstrap.dart`, `FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true)`.
- [ ] Eventos mínimos para o release (alinhar com
      [`docs/03-HONEST_ASSESSMENT.md`](../docs/03-HONEST_ASSESSMENT.md) §10):
      `link_aberto`, `idioma_escolhido`, `p1_respondida` … `p5_respondida`,
      `score_exibido`, `chat_iniciado`, `consultor_clicado`, `lead_salvo`.
- [ ] **ATT obrigatório no iOS 14.5+** se quiser IDFA — ver §C.
      Se preferir manter analytics **sem IDFA**, omitir
      `NSUserTrackingUsageDescription` e não chamar ATT prompt; o SDK
      continua coletando eventos não-personalizados.

### G.3 — Firebase Crashlytics

- [ ] Adicionar `firebase_crashlytics: ^4.x`.
- [ ] Em `main.dart`:
      ```dart
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (e, st) {
        FirebaseCrashlytics.instance.recordError(e, st, fatal: true);
        return true;
      };
      ```
- [ ] No Xcode: configurar **upload de dSYMs** para iOS release builds.
      `firebase.json:33` já tem `"uploadDebugSymbols": false` — virar `true`
      antes do primeiro build de release.

---

## H. TestFlight e App Review

- [ ] **App Store Connect** — criar registro do app:
      Nome ("HitLook" ou "Livelong" — §A), categoria primária
      **Business**, secundária **Lifestyle**. Age rating **4+** (sem UGC entre
      usuários).
- [ ] **Descrição da App Store** em PT + EN + ES. Não usar a palavra
      *insurance advice* — usar *educational tool to qualify prospects*.
- [ ] **Test account para Apple Review:**
      - Email + senha de um agente seed (criar `apple-review@hitlook.test`
        via [`createSellerAccount`](../functions/index.js) callable).
      - URL pública de teste: `https://hitlook-app.web.app/a/diego-teste`
        para o reviewer testar o fluxo do prospect sem login.
      - Notas para review: "This app qualifies insurance leads. The AI
        assistant ('Ana') provides general financial education only and never
        recommends specific products. Reference: [link para política]."
- [ ] **Screenshots**: mínimo **3** para iPhone 6.5"/6.7" (uma para 5.5"
      também ajuda Apple aceitar mais rápido). Capturar:
      - Tela de seleção de idioma (PT/ES/EN)
      - Pergunta P1 com avatar do agente
      - Score + plano recomendado + disclaimer
- [ ] **Build para TestFlight** primeiro com **5 agentes M4LIFE** + Renan
      antes de submeter para review pública (alinhado com
      [`docs/05-CHECKLIST.md`](../docs/05-CHECKLIST.md) — "Renan testa com 5 agentes piloto").
- [ ] **Notification permissions**: o app **não usa push** hoje. Não pedir.
- [ ] **Universal Links** opcional v1 (deep link `/a/{slug}` só funciona via
      web). Considerar `apple-app-site-association` quando houver app nativo
      iOS substituindo o link público web.

---

## Anexos

### Sequência recomendada para a 1ª submissão (~2-3 semanas)

1. **Semana 1:**
   - Decidir nome final (HitLook vs Livelong) — §A.
   - Patch do Info.plist (§C) — 30 min.
   - Política de Privacidade + Termos publicados em Hosting — 1 dia.
   - Disclaimer regulatório nas 3 telas críticas — 2h.
2. **Semana 2:**
   - App Check ativado em **monitor** — 1 dia.
   - Crashlytics + Analytics ligados — meio dia.
   - Migrar `functions.config()` → Secret Manager — 2h.
   - Schemas duplos: **adiar unificação** para pós-piloto (não bloqueia loja).
3. **Semana 3:**
   - TestFlight interno com Diego + Renan — 1 dia.
   - Screenshots + metadata App Store Connect — 1 dia.
   - Submissão para App Review.

### Métricas de sucesso da 1ª submissão

- Tempo até aprovação: **< 7 dias** (média Apple é 24-48h se Info.plist + privacy
  estiverem corretos).
- Zero rejeições por **Guideline 5.1 (data privacy)** — políticas claras.
- Zero rejeições por **Guideline 2.5.1 (private APIs)** — Flutter padrão não toca.
- Zero rejeições por **Guideline 4.2 (minimum functionality)** — o app **não**
  é só um web view; tem fluxo nativo de captura e UI custom.
- Zero rejeições por **Guideline 1.4.1 (medical/insurance claims)** — depende
  do disclaimer estar visível ([RISKS.md](RISKS.md) §1).

---

*Documento criado 2026-05-23. Próxima revisão sugerida após primeira submissão
para TestFlight.*
