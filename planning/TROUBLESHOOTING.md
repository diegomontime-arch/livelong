# Live Long / HitLook — Troubleshooting

Operacional. Problemas conhecidos e como diagnosticar em produção.
Formato inspirado em
[`OpenWhen/planning/TROUBLESHOOTING.md`](../../OpenWhen/planning/TROUBLESHOOTING.md).

---

## 1. `permission-denied` ao salvar lead público

### O que acontece

Prospect completa as 5 perguntas → `result_screen._saveLead()` falha com
`FirebaseException` code `permission-denied`. UI mostra erro genérico.

### Causas comuns

| Causa | O que verificar |
|-------|------------------|
| Regras Firestore desatualizadas no console | `firebase deploy --only firestore:rules` — confirmar que a versão deployada bate com [`firestore.rules`](../firestore.rules) |
| Slug do agente não corresponde a doc real em `companies/{cid}/sellers/{sid}` | `isValidPublicLeadCreate` exige `sellerExists(companyId, sellerId)`. Se o seller foi deletado mas o `seller_slugs/{slug}` ficou órfão, o create falha |
| Schema duplo: lead grava em ambos `/leads` e `/companies/.../leads` — se uma das regras falhar, **as duas** transações falham | Logs do client: ver qual collection foi rejeitada primeiro |
| `score` fora do range [0, 100] | `optionalScoreValid()` valida `>=0 && <=100` |
| Cliente envia campo extra (`userId`, `role`, etc.) | `data.keys().hasOnly(publicLeadAllowedKeys())` rejeita |

### Como debugar

1. Abrir Firebase Console → Firestore → Rules → **Rules Playground**.
2. Simular o `create` em `companies/m4life/leads/__autoid__` com o payload
   exato que o cliente enviou (copiar do `debugPrint` de
   [`result_screen.dart`](../lib/legacy/screens/result_screen.dart)).
3. Identificar qual `allow create` rejeitou.

### Referência de código

- Create: `lib/legacy/screens/result_screen.dart` → `_saveLead()`
- Schema: [`docs/11-SCHEMA-DEFINITIVO.md`](../docs/11-SCHEMA-DEFINITIVO.md) §3.7
- Rules: `firestore.rules:264-285`

---

## 2. Foto do agente não aparece no link público `/a/{slug}`

### Sintoma

Prospect abre `https://hitlook-app.web.app/a/renan` e vê placeholder
(círculo cinza) no lugar da foto do agente.

### Causas conhecidas

| # | Causa | Fix |
|---|-------|-----|
| 1 | `agents/{slug}.fotoUrl` vazio | Diego/Renan: salvar perfil novamente em `/perfil` — `agent_setup_screen._syncSellerAndPublicSlug` faz dual write |
| 2 | URL gerada mas Storage CORS bloqueia | `storage-cors.json` deployado: `gsutil cors set storage-cors.json gs://hitlook-app.appspot.com` |
| 3 | `Image.network` falha em web por CORS — solução é `getData(agents/{userId}/photo)` direto do SDK | Já implementado em `AgentProfilePhoto`. Validar uso |
| 4 | `seller_slugs/{slug}` aponta para `sellerId` que não tem `userId` | Rodar `node scripts/seed/sync_public_agent_profiles.js` |

### Como debugar

1. Abrir DevTools → Console → buscar `[AgentProvider]` ou erros 403 em
   `firebasestorage.googleapis.com`.
2. No console Firebase → Storage → `agents/{uid}/photo` deve existir.
3. Em `agents/{slug}.fotoUrl` (Firestore) deve estar a URL pública.

---

## 3. Ana não responde / chat trava em "Pensando..."

### Causas

| # | Causa | Como confirmar |
|---|-------|----------------|
| 1 | Cloudflare Worker `hitlook-ana-proxy.hitlook.workers.dev` fora do ar | `curl -X OPTIONS https://hitlook-ana-proxy.hitlook.workers.dev/v1/messages` deve voltar 200 |
| 2 | `ANTHROPIC_API_KEY` no Worker expirou | Cloudflare Dashboard → Workers → Settings → Variables |
| 3 | Anthropic API com latência alta (>30s) | Status: https://status.anthropic.com |
| 4 | Crédito Anthropic esgotado | Console Anthropic → Billing |
| 5 | Modelo `claude-sonnet-4-6` descontinuado/renomeado | Atualizar `AnaProxyConfig.model` em [`lib/core/config/ana_proxy_config.dart`](../lib/core/config/ana_proxy_config.dart) |
| 6 | CORS bloqueando — Origin allowlist (após [FUNCTIONS_AUDIT.md §5.3](FUNCTIONS_AUDIT.md)) | DevTools → Network → ver header `Access-Control-Allow-Origin` |

### Mitigação imediata

Adicionar feature flag `anaChatEnabled` (estilo Whenote — ver
[ARCHITECTURE.md §3.2](ARCHITECTURE.md)) para desligar Ana em produção sem
deploy.

---

## 4. Painel admin do Renan não carrega — fica em loading infinito

### Causas

| # | Causa | Fix |
|---|-------|-----|
| 1 | `users/{renan-uid}` não existe ou sem `role: 'admin'` | Criar manualmente no console Firestore |
| 2 | `users/{renan-uid}.companyId` ≠ `m4life` (ou companyId errado) | Corrigir doc |
| 3 | `AdminSession.load()` timeout de 8s (`admin_session.dart:30`) | Verificar latência Firestore + tamanho do doc |
| 4 | Renan está em rede com Firestore bloqueado (firewall corporativo) | Pedir teste em rede móvel |

### Como debugar

`agent_login_screen` faz login → `postLoginRoute` chama `AdminSession.load`
→ se retornar null vai para `/dashboard` (legado).

Adicionar `debugPrint('[AdminSession] role=${role.name}')` em
[`admin_session.dart:75`](../lib/legacy/admin/admin_session.dart) e
seguir os logs no Chrome DevTools / Xcode console.

---

## 5. Build iOS falha com erro de Pods

### Sintomas

```
[!] CocoaPods could not find compatible versions for pod "FirebaseFirestore":
```

ou

```
fatal: bad object HEAD
```

### Fix

```bash
cd ios
rm -rf Pods Podfile.lock
pod cache clean --all
pod install --repo-update
cd ..
flutter clean
flutter pub get
flutter build ios --release
```

Se ainda falhar, atualizar versão mínima do Podfile:

```ruby
# ios/Podfile
platform :ios, '13.0'   # bate com IPHONEOS_DEPLOYMENT_TARGET
```

E rodar `pod repo update` separadamente antes.

---

## 6. App crash no iOS ao tocar em "trocar foto" do agente

### Sintoma

Tela "Editar perfil" → toca "Trocar foto" → app fecha sem aviso.

### Causa

`Info.plist` sem `NSCameraUsageDescription` ou `NSPhotoLibraryUsageDescription`.
iOS mata o app silenciosamente ao chamar `image_picker`.

### Fix

Ver [APPLE_RELEASE.md §2.2](APPLE_RELEASE.md) ou
[PRODUCTION.md §C](PRODUCTION.md). Patch obrigatório.

---

## 7. App fecha (SIGABRT) ao abrir dashboard em iOS

Padrão observado em Whenote ([`OpenWhen/planning/TROUBLESHOOTING.md`](../../OpenWhen/planning/TROUBLESHOOTING.md) §2):
chamar múltiplos `httpsCallable` em paralelo no `initState` causa SIGABRT
no stack Firebase iOS.

**Live Long ainda não tem** padrão de múltiplos callables em paralelo no
mesmo screen — `AdminSession.load()` e `_companyRepo.watchAll()` são
**sequenciais ou stream**. Sem incidente conhecido.

**Preventivo:** se adicionar callables no admin, **sempre** rodar
sequenciais com `await` entre eles, dentro de
`WidgetsBinding.instance.addPostFrameCallback`.

---

## 8. WhatsApp não abre ao clicar "Falar com consultor"

### Causas

| # | Causa | Fix |
|---|-------|-----|
| 1 | WhatsApp não instalado no device | Esperado — `url_launcher` mostra erro. UI pode oferecer fallback (copiar número) |
| 2 | Número do agente vazio (`sellers.phone` null) | Validar no admin antes de publicar perfil |
| 3 | Número em formato incorreto (sem `+`) | `WhatsAppUtils` deve normalizar |
| 4 | iOS — `LSApplicationQueriesSchemes` sem `whatsapp` | Adicionar no Info.plist ([APPLE_RELEASE.md §2.2](APPLE_RELEASE.md)) |
| 5 | Safari bloqueando popup do `wa.me/...` | Já mitigado: pull pelo `kDefaultConsultantWhatsApp` em `whatsapp_utils.dart` |

---

## 9. Lead criado mas agente não recebe email

### Diagnóstico

1. **Trigger Email Extension instalada?** Console Firebase → Extensions
   → procurar `firestore-send-email`. Se não estiver, ler
   [FUNCTIONS_AUDIT.md §4.3 F13](FUNCTIONS_AUDIT.md).
2. **Função `notifyAgentOnNewLead` executou?** Console → Functions →
   Logs → buscar por `Queued lead email`. Se não houver, lead foi
   gravado só em `companies/.../leads` (schema novo) e a trigger só escuta
   `/leads` raiz.
3. **Documento `mail/{id}` foi criado?** Console → Firestore →
   collection `mail` → procurar pelo timestamp da criação do lead.
4. **Trigger Email reportou erro?** O próprio documento `mail/{id}` ganha
   subcoleção `delivery` com `state: SUCCESS | ERROR` e `error: ...`.

### Estados possíveis

| Estado em `mail/{id}/delivery` | Significado |
|-------------------------------|-------------|
| `PENDING` | Trigger Email ainda não processou |
| `PROCESSING` | Em envio |
| `SUCCESS` | Email enviado |
| `ERROR` | Falhou — campo `error` tem detalhe |
| Sem subcoleção `delivery` | Trigger Email Extension **não está instalada** |

---

## 10. Cloudflare Worker rate-limited ou Anthropic 429

### Sintoma

Ana responde "Desculpe, problema técnico. Tente novamente."

### Causa

Múltiplas requisições ao Anthropic em curto intervalo. Anthropic responde
com 429 ou 529.

### Fix

- **Curto prazo:** mostrar erro mais amigável no client com tempo de retry.
- **Médio prazo:** rate limit no Worker — máx 10 req/min/IP.
- **Longo prazo:** cache de respostas comuns (Sugestões dos chips) —
  resposta cacheada do Worker para perguntas conhecidas como
  "O que é benefício em vida?".

---

## 11. Schemas duplos: lead aparece duplicado no dashboard

### Sintoma

Renan vê 2 entradas para o mesmo prospect no dashboard `/admin`.

### Causa

[`agent_dashboard_screen._mergeLeadRows`](../lib/legacy/screens/agent_dashboard_screen.dart)
deduplica por `(phone, name)`. Se:

- Nome digitado tem espaço extra/acento diferente
- Telefone com `+1` em um, sem em outro

→ dedup falha → 2 entradas.

### Fix

- **Paliativo:** normalizar (lowercase + remove acentos + remove
  non-digits) antes de comparar. Pacote `diacritic` ou inline.
- **Definitivo:** unificar schemas ([ARCHITECTURE.md §2.1](ARCHITECTURE.md)).

---

## 12. App Check vai bloquear tudo no dia de ligar

### Cenário

Diego liga App Check em **enforce** direto sem passar por **monitor** →
tudo para de funcionar no client em produção.

### Prevenção

**Sempre** ativar em **monitor mode** primeiro. Esperar 48h. Conferir
no console → App Check → "Unverified Requests" → deve estar próximo de 0%
se o setup estiver correto. SÓ então virar **enforced**.

Documentado em [PRODUCTION.md §G.1](PRODUCTION.md).

---

## 13. Foto enviada para Storage volta 403 ao ler

### Causa típica

`storage.rules:6` exige `request.auth.uid == agentId`. Se a foto é gravada
mas o **leitor** está deslogado (ex: prospect público), o read deveria
funcionar porque `allow read: if true`.

Se voltar 403, verificar:

- Path do upload: deve ser exatamente `agents/{uid}/photo`, não
  `agents/{uid}/photo.jpg` (variação de nome cria outro path).
- CORS configurado: `storage-cors.json` deployado via gsutil.

### Comando

```bash
gsutil cors get gs://hitlook-app.appspot.com
# Saída esperada: lista com origens autorizadas e methods GET, HEAD
```

---

## 14. `firebase functions:secrets:set` falha com HTTP 403 `serviceusage.services.use`

### Sintoma exato

```
Error: Request to https://serviceusage.googleapis.com/v1/projects/hitlook-app/services/secretmanager.googleapis.com had HTTP Error: 403, Caller does not have required permission to use project hitlook-app.
```

### Causa

A conta autenticada no `firebase` CLI não tem permissão para habilitar
APIs no projeto. O Secret Manager precisa estar habilitado antes do
primeiro `secrets:set`.

### Fix

1. `firebase login:list` para conferir qual conta está em uso.
2. Confirmar que essa conta tem **Owner** ou **Editor** em
   https://console.cloud.google.com/iam-admin/iam?project=hitlook-app.
3. Se não tiver, adicionar o role
   `roles/serviceusage.serviceUsageConsumer` ou trocar a conta:
   ```bash
   firebase logout
   firebase login   # autenticar com a conta dona do projeto
   ```
4. Refazer: `firebase functions:secrets:set ANTHROPIC_API_KEY` —
   **usar o prompt mascarado**, não colar a chave como argumento.

### Diagnóstico relacionado

Se o erro for `serviceusage.googleapis.com` com mensagem **diferente**
(ex: "API not enabled"), abrir
https://console.cloud.google.com/apis/library/secretmanager.googleapis.com?project=hitlook-app
e clicar **Enable** manualmente.

---

## 15. Vazamento de API key (Anthropic / Stripe / outras) no chat

### Sintoma

Você colou uma chave em qualquer canal não-seguro (chat com Claude,
log do shell em screenshot, ticket público, Slack channel aberto).

### Resposta — em ordem

1. **Revogar imediatamente** no console do provedor:
   - Anthropic: https://console.anthropic.com/settings/keys → Delete
   - Stripe: https://dashboard.stripe.com/apikeys → Roll/Revoke
   - SendGrid: API Keys → Delete
2. **Rotacionar** — gerar nova chave com nome diferente
   (`{produto}-prod-{YYYY-MM-DD}`).
3. **Monitorar billing** do provedor por 24-48h. Anthropic alerta em
   picos. Stripe envia email em qualquer subida abrupta.
4. **Auditar logs** do produto: requests com origem suspeita nas
   últimas N horas.
5. **Atualizar segredos** no Cloudflare Worker / Secret Manager / etc.
6. Documentar incidente em [LEGAL.md §9](LEGAL.md) — pode acionar
   notificação por FIPA se PII foi atingida (raro para uma chave de
   IA, mas avaliar).

### Prevenção

- Nunca colar chave como **argumento** de comando CLI; usar prompt
  mascarado ou `--data-file=-` com stdin.
- Comandos como `firebase functions:secrets:set NAME` abrem prompt
  TTY que esconde o valor; usar essa via.
- 1Password CLI (`op read`) → pipe direto para o CLI receptor:
  ```bash
  op read "op://Personal/Anthropic API/hitlook-prod" \
    | firebase functions:secrets:set ANTHROPIC_API_KEY --data-file=-
  ```
- Em scripts de bootstrap, ler de variável de ambiente exportada por
  `direnv` ou similar — nunca de literal no histórico.

---

## Padrão para adicionar novos casos

Quando um problema novo aparecer em produção:

1. Adicionar seção numerada aqui (#14, #15, …).
2. Descrever **sintoma observável** (não causa).
3. Listar causas em tabela.
4. Apontar referências de código (`lib/...:linha`).
5. Documentar comandos exatos para reproduzir/corrigir.
6. Ligar para o item correspondente em `RISKS.md` / `SECURITY.md` se houver.

---

*Última atualização: 2026-05-23.*
