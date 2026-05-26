# Live Long / HitLook — Firebase Project Reference

> Source of truth for everything `firebase` CLI needs to target the right
> backend. Última auditoria: **2026-05-24**.

---

## 1. Projeto

| Campo | Valor |
|-------|-------|
| Project ID | `hitlook-app` |
| Project number | `807145542991` |
| Console | https://console.firebase.google.com/u/0/project/hitlook-app/overview |
| Default location | `nam5` (Iowa, US multi-region — Firestore) |
| Plan | Blaze (pay-as-you-go) — necessário para Cloud Functions e Secret Manager |
| Auth domain | `hitlook-app.firebaseapp.com` |
| Storage bucket | `hitlook-app.firebasestorage.app` |
| Web URL | https://hitlook-app.web.app |

---

## 2. Onde a config aparece no repo

| Arquivo | Papel |
|---------|-------|
| [`.firebaserc`](../.firebaserc) | Define `default: hitlook-app` para o CLI |
| [`firebase.json`](../firebase.json) | Config de Hosting, Functions, Firestore (rules+indexes), Storage, Flutter platforms |
| [`firestore.rules`](../firestore.rules) | Rules deployadas com `firebase deploy --only firestore:rules` |
| [`firestore.indexes.json`](../firestore.indexes.json) | Índices compostos |
| [`storage.rules`](../storage.rules) | Rules de Storage |
| [`functions/index.js`](../functions/index.js) | Cloud Functions v2 (Node 24) |
| [`functions/package.json`](../functions/package.json) | Dependências das functions |
| [`lib/firebase_options.dart`](../lib/firebase_options.dart) | Re-export do FlutterFire CLI |
| [`lib/services/firebase/firebase_options.dart`](../lib/services/firebase/firebase_options.dart) | Config FlutterFire (web/android/ios) |
| [`ios/Runner/GoogleService-Info.plist`](../ios/Runner/GoogleService-Info.plist) | Config iOS |
| [`android/app/google-services.json`](../android/app/google-services.json) | Config Android |
| [`android/settings.gradle.kts`](../android/settings.gradle.kts) | Plugins `google-services`, `firebase-crashlytics` |
| [`android/app/build.gradle.kts`](../android/app/build.gradle.kts) | Apply dos plugins acima |
| [`web/index.html`](../web/index.html) | OG tags com URL `https://hitlook-app.web.app` |
| [`web/env.js`](../web/env.js) | DEPRECATED — não usar para secrets |

### App IDs por plataforma

| Plataforma | App ID | Bundle / Package |
|------------|--------|------------------|
| Web | `1:807145542991:web:b8563944647cd042c2a13a` | — |
| iOS | `1:807145542991:ios:8f54c4325326d8cac2a13a` | `com.livelong.livelong` |
| Android | `1:807145542991:android:845fd33c83baeecdc2a13a` | `com.livelong.livelong` |

### API keys por plataforma (públicas — protegidas por App Check + rules)

| Plataforma | apiKey |
|------------|--------|
| Web | `AIzaSyBSx_LQ1LMujnRnCFDjB8Fsgbpzn-z22Rs` |
| iOS | `AIzaSyCZotNzz2au1PusQeccVc1RczjiZSA_WAQ` |
| Android | `AIzaSyBfVW_NQDz2615HHfv9DvDbAGVLaZxyVCs` |

> Estas keys são **públicas por design** no Firebase — elas só identificam
> o projeto; a segurança real vem das Security Rules + App Check (quando
> ligado, ver [PRODUCTION.md §G.1](PRODUCTION.md)).

---

## 3. Comandos `firebase` por área

> Sempre rodar da **raiz do repositório** (`/Users/yurilima/Downloads/projects/livelong`).
> Se o CLI estiver autenticado em conta errada, ver
> [TROUBLESHOOTING.md §14](TROUBLESHOOTING.md).

### 3.1 Setup inicial (uma vez por máquina)

```bash
# Confirmar conta logada
firebase login:list

# Trocar de conta se necessário
firebase logout && firebase login

# Selecionar projeto explicitamente (já é default via .firebaserc, mas garante)
firebase use hitlook-app

# Validar
firebase projects:list
```

### 3.2 Deploy seletivo

```bash
# Tudo (Hosting + Functions + Firestore rules/indexes + Storage rules)
firebase deploy

# Só rules
firebase deploy --only firestore:rules
firebase deploy --only storage

# Só índices Firestore
firebase deploy --only firestore:indexes

# Só Cloud Functions
firebase deploy --only functions
firebase deploy --only functions:anthropicProxy            # função específica
firebase deploy --only functions:notifyAgentOnNewLead

# Só Hosting (após `flutter build web --release`)
flutter build web --release
firebase deploy --only hosting

# Combinar
firebase deploy --only firestore:rules,storage,hosting
```

### 3.3 Secret Manager (Functions v2)

```bash
# Listar
firebase functions:secrets:list

# Setar (usar o prompt MASCARADO — nunca colar a chave como argumento!)
firebase functions:secrets:set ANTHROPIC_API_KEY
# Cole no prompt seguro; o terminal não ecoa.

# Alternativa via stdin (sem deixar no history)
read -s K && echo "$K" | firebase functions:secrets:set ANTHROPIC_API_KEY --data-file=- && unset K

# Ver versões e quais funções usam
firebase functions:secrets:access ANTHROPIC_API_KEY:latest --quiet

# Após confirmar que tudo funciona, remover legado functions.config()
firebase functions:config:unset anthropic --project hitlook-app
```

### 3.4 Functions logs e debug

```bash
firebase functions:log
firebase functions:log --only anthropicProxy
firebase functions:log --only notifyAgentOnNewLead --since 1h

# Emulador local (não toca em produção)
firebase emulators:start --only functions,firestore,auth
```

### 3.5 Hosting

```bash
# Listar sites do projeto
firebase hosting:sites:list

# Histórico de releases (para rollback)
firebase hosting:releases:list

# Rollback se um deploy quebrar
firebase hosting:rollback

# Preview channel para testar antes do live
firebase hosting:channel:deploy preview-name --expires 7d
```

### 3.6 Firestore — emulador, queries, índices

```bash
# Emulator
firebase emulators:start --only firestore --inspect-functions

# Listar índices compostos atuais
firebase firestore:indexes

# Backup (recomenda configurar via Console — schedule daily)
# https://console.firebase.google.com/project/hitlook-app/firestore/backups
```

### 3.7 App Check (quando ligado — B1 em [CHECKLIST.md](CHECKLIST.md))

```bash
# Listar app providers
firebase appcheck:apps:list                  # (se disponível na versão)

# Geralmente App Check é configurado pelo console:
# https://console.firebase.google.com/project/hitlook-app/appcheck
```

### 3.8 Crashlytics — upload de dSYMs (iOS) e mappings (Android)

Após build de release iOS:

```bash
# Encontre os dSYMs em build/ios/archive/Runner.xcarchive/dSYMs/
# Upload manual se o run script do Xcode não fizer automaticamente:
upload-symbols -gsp ios/Runner/GoogleService-Info.plist \
               -p ios build/ios/archive/Runner.xcarchive/dSYMs
```

Android (R8 mappings): após `flutter build apk --release` ou `appbundle`,
o plugin `com.google.firebase.crashlytics` faz o upload automaticamente
no build de release (se conexão com internet ok).

---

## 4. Domínios e Hosting custom

| Domínio | Status | Notas |
|---------|--------|-------|
| `hitlook-app.web.app` | ✅ Default | Sempre HTTPS, gratuito |
| `hitlook-app.firebaseapp.com` | ✅ Alias automático | Aceitar como Origin no Cloudflare Worker (já feito) |
| `livelong.app` / `hitlook.us` / `m4life.us` | ❌ Não configurado | v1.1+; ver [RISKS.md R9](RISKS.md) |

Configurar domínio custom: Console → Hosting → Add custom domain → seguir
DNS verification (TXT + CNAME). Se um dia for adicionado, atualizar:
1. [`cloudflare/worker.js`](../cloudflare/worker.js) `ALLOWED_ORIGINS`
2. [`functions/index.js`](../functions/index.js) `ANTHROPIC_PROXY_ALLOWED_ORIGINS`
3. [`web/index.html`](../web/index.html) OG `og:url`
4. Privacy/Terms `web/*.html`

---

## 5. Regenerar config (se mudar bundle ID)

Caso a decisão A1 ([CHECKLIST.md](CHECKLIST.md)) leve a um bundle ID
novo (ex: `com.hitlook.app`), regerar **tudo** com o FlutterFire CLI:

```bash
# Instalar (uma vez)
dart pub global activate flutterfire_cli

# Reconfigurar para o projeto hitlook-app
flutterfire configure \
  --project=hitlook-app \
  --platforms=ios,android,web \
  --ios-bundle-id=com.hitlook.app \
  --android-package-name=com.hitlook.app \
  --out=lib/services/firebase/firebase_options.dart
```

Saídas geradas/atualizadas:
- `lib/services/firebase/firebase_options.dart`
- `ios/Runner/GoogleService-Info.plist`
- `android/app/google-services.json`
- `firebase.json` (`flutter.platforms`)

Depois é preciso recriar os apps no console Firebase (cada bundle ID =
um App ID novo) ou pedir ao FlutterFire CLI para fazer isso.

---

## 6. Saúde da config — checks rápidos

Rode periodicamente:

```bash
# Project ID consistente em todos os arquivos
grep -rn "hitlook-app" \
  .firebaserc firebase.json \
  lib/services/firebase/firebase_options.dart \
  ios/Runner/GoogleService-Info.plist \
  android/app/google-services.json \
  | wc -l
# Esperado: ≥ 10 ocorrências

# Validar JSONs
python3 -c "import json; json.load(open('firebase.json'))"
python3 -c "import json; json.load(open('.firebaserc'))"
python3 -c "import json; json.load(open('android/app/google-services.json'))"
python3 -c "import plistlib; plistlib.load(open('ios/Runner/GoogleService-Info.plist','rb'))"
python3 -c "import plistlib; plistlib.load(open('ios/Runner/Info.plist','rb'))"

# Project ativo no CLI
firebase use
# Esperado: "Active project: hitlook-app"
```

---

## 7. Pendências relacionadas (não config, mas vinculadas)

- [ ] **App Check** ativado em modo monitor — [CHECKLIST.md B1](CHECKLIST.md)
- [ ] **Budget alert** $30/mês com 50/80/100% — [CHECKLIST.md B8](CHECKLIST.md)
- [ ] **Trigger Email extension** instalada — [CHECKLIST.md B5](CHECKLIST.md)
- [ ] **`ANTHROPIC_API_KEY`** no Secret Manager — [CHECKLIST.md B2](CHECKLIST.md), pendente após rotação por segurança
- [ ] **`uploadDebugSymbols: true`** em `firebase.json` para iOS — ✅ já está ativo após Sprint 1

---

## 8. Achados desta auditoria (2026-05-24)

| # | Item | Ação tomada |
|---|------|-------------|
| F-A1 | `IS_ANALYTICS_ENABLED=false` no `GoogleService-Info.plist` enquanto `firebase_analytics` está ativo no app | ✅ Mudado para `true` — alinhado com A8 |
| F-A2 | Android sem plugin `com.google.firebase.crashlytics` | ✅ Adicionado em `settings.gradle.kts` + `app/build.gradle.kts` |
| F-A3 | `web/env.js` com placeholder `ANTHROPIC_API_KEY: ''` | ✅ Neutralizado para `Object.freeze({})` + comentário com aviso de segurança |
| F-A4 | `.firebaserc` minimalista — sem `prod` alias nem `targets` para Hosting | ✅ Expandido com alias `prod` + target `app` |
| F-A5 | Signing config release Android = debug (TODO em `app/build.gradle.kts:38-41`) | ⚠️ Documentado; não bloqueia Apple-first release, mas bloqueia Play Store |
| F-A6 | Falta `apple-app-site-association` para Universal Links | 🟡 v1.1 — não necessário se TestFlight inicial não usa deep link nativo |
| F-A7 | Sem `firebaseAppCheck` config em `firebase.json` | 🟡 v1.1 — App Check é configurado pelo console, não pelo JSON |

---

*Próxima revisão sugerida: após decisão A1 (bundle ID definitivo) ou
quando aparecer segundo ambiente (staging).*
