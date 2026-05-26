# Live Long / HitLook — Riscos para o 1º release Apple

Mapa de riscos **operacionais e regulatórios** que podem bloquear ou
atrasar o release iOS. Distinto de [`docs/07-RISKS.md`](../docs/07-RISKS.md),
que cobre riscos de negócio de longo prazo (concorrência, burnout, etc.).
Este documento foca em **risco de produção / Apple Review** imediato.

Auditado em **2026-05-23**.

---

## R1 — 🔴 Apple Guideline 1.4.1: insurance advice sem licença

**Origem:** [`docs/07-RISKS.md`](../docs/07-RISKS.md) §1 já cita o risco
**regulatório** (Florida DFS), mas Apple **também** rejeita apps que parecem
oferecer insurance advice sem licença explícita. Análise jurídica detalhada
em [LEGAL.md §1.2 e §6](LEGAL.md) (Florida Insurance Code, NAIC Model 870).

**Onde aparece no produto:**

- Tela de **resultado** (`result_screen.dart`) — "plano recomendado" pode
  ser lido como recomendação personalizada.
- **Ana** (`chat_screen.dart`) — system prompt obriga "EDUCAÇÃO ONLY", mas
  o display vai dizer "M4LIFE Assistant" e usuário pode confundir.

**Mitigação:**

1. **Disclaimer visível** em 3 telas — bloqueante. Ver
   [APPLE_RELEASE.md §2.4](APPLE_RELEASE.md).
2. **Descrição da loja**: usar "lead qualification tool" e
   "educational AI assistant". **Nunca** "insurance recommendation" ou
   "AI insurance advisor".
3. **Política de privacidade** com seção explícita "We do not provide
   insurance advice".

**Probabilidade de rejeição se não mitigar:** 70%.
**Probabilidade após mitigação:** 10%.

---

## R2 — 🔴 Identidade do app inconsistente

`CFBundleDisplayName=Livelong`, `CFBundleName=hitlook`, bundle ID
`com.livelong.livelong`, domínio web `hitlook-app.web.app`, marca pública
"M4LIFE".

Apple Review pergunta "qual o nome real do app?".

**Mitigação:**

- 🟡 Diego decide entre **HitLook**, **Livelong**, **M4LIFE Consultant**
  ([APPLE_RELEASE.md §2.1](APPLE_RELEASE.md)).
- Tudo alinhado em **um commit** antes do build IPA: `pubspec`, `Info.plist`,
  Firebase project, App Store Connect metadata.

**Probabilidade de rejeição:** 50% se ficar inconsistente.

---

## R3 — 🔴 Política de privacidade e termos ausentes

App Store Connect tem campo obrigatório **Privacy Policy URL**. Sem isso,
não dá nem para iniciar submissão.

Live Long **não tem** essas páginas hoje (verificado em `web/` do repositório).

**Mitigação:**

- Criar `web/privacy.html` e `web/terms.html`. ~1 dia.
- Estrutura detalhada em [LEGAL.md §3 e §4](LEGAL.md) — Privacy Policy
  com 16 seções e ToU com 10, adaptadas a B2B insurance.
- Modelo de referência: [`OpenWhen/hosting/public/privacy.html`](../../OpenWhen/hosting/public/privacy.html)
  **NÃO** copiar direto — Whenote é GDPR-primário, Live Long é
  CCPA/FIPA-primário. Estrutura é diferente. Ver [LEGAL.md §0](LEGAL.md).

**Probabilidade de rejeição se não mitigar:** 100%.

---

## R4 — 🔴 Info.plist sem chaves de privacidade

Camera/Photos sem `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`
**mata o app em runtime** quando o usuário toca em "trocar foto".

**Mitigação:** patch de 30 minutos. Ver [PRODUCTION.md §C](PRODUCTION.md).

**Probabilidade de rejeição:** 100% (App Review testa).

---

## R5 — 🔴 `anthropicProxy` / Cloudflare Worker abertos publicamente

Custo Anthropic API descontrolado se alguém abusar do endpoint.
Documentado em [SECURITY.md §S7, §S8](SECURITY.md) e [FUNCTIONS_AUDIT.md §2, §5](FUNCTIONS_AUDIT.md).

**Não bloqueia Apple Review**, mas pode bloquear o **negócio** se atacado
nas primeiras 48h pós-lançamento.

**Mitigação:**

1. **Imediato (1h):** Origin allowlist no Cloudflare Worker.
2. **Semana 1:** decidir destino do `anthropicProxy` (remover ou proteger).
3. **Semana 2:** App Check enforced → header `X-Firebase-AppCheck`
   validado no Worker.

**Probabilidade de abuso nas primeiras 4 semanas:** **alta** (40-60%).
Endpoints públicos com chave Anthropic atrás são alvo conhecido.

---

## R6 — 🟠 Apple Guideline 5.1.2: declaração incompleta de 3rd-party

App envia conteúdo do usuário (mensagens da Ana) para Anthropic, mas a
declaração em **App Privacy** + Política de Privacidade precisa listar
explicitamente:

- Anthropic (via Cloudflare) — recebe conteúdo do chat
- Cloudflare Workers — recebe payload do chat (sem persistir, mas recebe)
- Google Firebase — armazena dados

**Mitigação:** preencher App Privacy completo (PRODUCTION.md §E) e
Política de Privacidade com seção "Third Parties".

**Probabilidade de rejeição:** 30% se incompleto, 5% se completo.

---

## R7 — 🟠 Apple Guideline 2.1: app falha em condições edge

Apple Review:

- Sem internet → app deveria mostrar mensagem amigável, não crashar.
- Em iPad → orientações suportadas (Info.plist:62-68 já tem 4 orientações).
- Em iPhone SE (small screen) — layout responsivo?
- Em iOS 13.0 mínimo — algumas APIs novas não funcionam.

**Schemas duplos** ([ARCHITECTURE.md §2.1](ARCHITECTURE.md)) podem
gerar inconsistência visual se um schema retornar dados que o outro não tem.

**Mitigação:**

- QA dispositivo real ANTES da submissão.
- Modo avião + abrir o app → não deve crashar (testar em
  `agent_dashboard_screen` que faz `Future.timeout` — `:42`).
- Testar em iPad mini.

**Probabilidade de rejeição:** 20%.

---

## R8 — 🟠 Falta de Crashlytics / observabilidade pós-release

Sem Crashlytics, qualquer crash em produção é invisível. Apple Review
pode passar (não testa crashes raros), mas usuário real reportará crash
sem você nem saber qual.

**Mitigação:** [PRODUCTION.md §G.3](PRODUCTION.md) — 1h.

**Probabilidade de impacto:** 100% (acontecerá), só a magnitude varia.

---

## R9 — 🟡 Domínio `hitlook-app.web.app` em vez de domínio próprio

Apple não rejeita por isso, mas:

- Política de privacidade em `*.web.app` parece menos profissional.
- Links em `wa.me/...` direcionando para `hitlook-app.web.app/a/...` —
  pode passar; usuário não estranha porque já está vindo do WhatsApp.

**Mitigação:** **adiar para v1.1.** Comprar `livelong.app` ou
`hitlook.us` ou usar `m4life.us` (do Renan) com CNAME para Firebase
Hosting.

**Probabilidade de impacto na 1ª submissão:** 0%.

---

## R10 — 🟡 Sem CI/CD

Deploy depende de Diego rodar localmente. Se Diego ficar doente na
semana da submissão, atraso garantido.

**Mitigação:** **adiar para pós-release** (v1.1). Risco é operacional, não
de produto.

---

## R11 — 🟡 Pasta `legacy/` cria atrito mental para novo dev

Mencionado em [ARCHITECTURE.md §2.2](ARCHITECTURE.md). Não afeta
release, afeta velocidade de desenvolvimento.

---

## R12 — 🟡 Email do `notifyAgentOnNewLead` em PT only

[FUNCTIONS_AUDIT.md §4.2 F15](FUNCTIONS_AUDIT.md). Agente que prefere
ES recebe email em PT. **Não rejeita Apple**, mas é UX degradada.

---

## R13 — 🟡 Stripe / monetização não implementada

[`docs/02-CURRENT_STATUS.md`](../docs/02-CURRENT_STATUS.md) lista Stripe
como pendente. Para Apple:

- App **não tem In-App Purchase** — ok porque é B2B SaaS, não consumível
  digital.
- Cobrança Stripe **fora do app** (link, email) — Apple permite para SaaS
  de uso comercial (Guideline 3.1.3(b) — "Reader app"). Mas se Diego
  adicionar botão "Subscribe" no app que abre Stripe Checkout, Apple
  exige IAP.

**Mitigação:** **não colocar botão de subscribe no app v1.0**. Cobrar
agentes por boleto/cartão fora do app. Discutir IAP só na v1.2 se voltar
a ser estratégico.

---

## R15 — 🔴 Sem entidade jurídica formal (LLC) e EIN

**Origem:** [LEGAL.md §10](LEGAL.md).

App Store Connect exige **legal entity name + tax ID** para conta business
(que é o que insurance B2B precisa, não conta individual). Sem EIN do IRS,
Apple bloqueia a criação.

ToU **não pode** dizer "HitLook LLC" se a LLC não existe — vira contrato
ineficaz.

**Mitigação:**

- Formalizar **Florida LLC** ou **Delaware LLC** (decisão Diego — ver
  trade-offs em LEGAL.md §10).
- Obter EIN no IRS (gratuito, online, ~10 min após LLC formalizada).
- Setup completo: 1-3 semanas dependendo do estado.

**Probabilidade de bloqueio:** 100% se tentar criar conta business no
ASC sem EIN.

---

## R14 — 🟢 Cloudflare Worker monocultura

Se Cloudflare cair, Ana fica offline. Pequeno risco operacional.

**Mitigação:** já documentado o fallback Cloud Function
`anthropicProxy` ([FUNCTIONS_AUDIT.md](FUNCTIONS_AUDIT.md)).

---

## Matriz de prioridade

| Risco | Severidade | Esforço para mitigar | Faça antes do release? |
|-------|------------|----------------------|------------------------|
| R1 — insurance advice | 🔴 | Baixo (2h) | **Sim** |
| R2 — nome inconsistente | 🔴 | Baixo (1h após decisão) | **Sim** |
| R3 — privacy policy | 🔴 | Médio (1 dia) | **Sim** |
| R4 — Info.plist | 🔴 | Baixo (30 min) | **Sim** |
| R5 — Worker aberto | 🔴 | Baixo (1h) | **Sim** |
| R6 — 3rd-party declaration | 🟠 | Baixo (1h) | **Sim** |
| R7 — edge cases | 🟠 | Médio (1 dia QA) | **Sim** |
| R8 — Crashlytics | 🟠 | Baixo (1h) | **Sim** |
| R9 — domínio | 🟡 | Médio (1 dia) | Adiar v1.1 |
| R10 — CI/CD | 🟡 | Alto (3 dias) | Adiar v1.1 |
| R11 — pasta legacy | 🟡 | Médio (refactor) | Adiar v1.2 |
| R12 — email i18n | 🟡 | Baixo (30 min) | **Sim** (ganho fácil) |
| R13 — Stripe in-app | 🟢 | Não fazer agora | — |
| R14 — Worker monocultura | 🟢 | — | — |
| R15 — Sem LLC + EIN | 🔴 | Alto (1-3 semanas) | **Sim** (bloqueia ASC) |

**Total bloqueantes:** 9 itens, ~3 dias úteis de trabalho concentrado +
1-3 semanas de wait para LLC + EIN (rodar em paralelo).

---

*Última atualização: 2026-05-23.*
