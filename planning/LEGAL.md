# Live Long / HitLook — Análise Legal: Privacy & Terms of Use

> **Última atualização:** 2026-05-23
> **Status:** 🟡 **Draft estrutural — não substitui revisão por advogado**
> **Contexto:** B2B SaaS para qualificação de leads de seguros de vida.
> Personas: **agentes licenciados (clientes pagantes)**, **prospects (data
> subjects, sem conta)**, **admin/tenant (Renan da M4LIFE)**.

Documento adaptado do padrão Whenote ([`OpenWhen/planning/LEGAL.md`](../../OpenWhen/planning/LEGAL.md))
ao contexto **B2B insurance nos EUA**, que é **muito diferente** do B2C
GDPR-primário do Whenote — ver §0 abaixo.

---

## 0. Por que Live Long ≠ Whenote do ponto de vista legal

| Dimensão | Whenote | Live Long / HitLook |
|----------|---------|---------------------|
| Modelo | B2C — usuário = subject = pagador | **B2B SaaS** — agente paga, prospect é subject **terceiro** |
| Mercado primário | Global (BR, UE, EUA) | **EUA (Flórida), brasileiros nos EUA** |
| Jurisdição predominante | GDPR + LGPD + CCPA | **CCPA/CPRA + FIPA + state insurance** |
| LGPD aplicável? | Sim (usuários BR) | **Não primariamente** — prospects são US residents, mesmo falando PT/ES |
| GDPR aplicável? | Sim (usuários UE) | **Pouco provável v1** — alvo é FL; se tenant onboardar agente UE, **vira** aplicável |
| Setor regulado | Não (comunicação social) | **Sim — seguros**, regulado por NAIC + Florida DFS |
| Conteúdo gerado por IA | OpenAI moderation (safety) | **Anthropic (Claude) em domínio regulado** — risco de "AI advice" sem licença |
| Dados de saúde | Não coleta | **POTENCIAL** — Ana pode receber "tenho pré-existência" do prospect (chips em `chat_screen.dart`) |
| Dados de menores | Sim, COPPA 13+ | **Não** intencional (agentes adultos; prospects de seguro de vida = adultos), mas precisa de age gate |
| TCPA (telemarketing US) | N/A | **Aplicável** — WhatsApp do agente para prospect pode acionar |
| Promessa-chave do produto | "Sua carta será entregue" → fundo de continuidade | "Lead qualificado pelo agente licenciado" → **disclaimer obrigatório** de que IA não recomenda |

---

## 1. Legislações aplicáveis (mapeadas ao produto)

### 1.1 Federais EUA

| Lei | Quando aplica | Pontos críticos para Live Long |
|-----|--------------|-------------------------------|
| **CCPA/CPRA** (Cal. Civ. Code §1798.100+) | Qualquer agente ou prospect residente na Califórnia, **ou** se receita anual ≥ $25M (não é o caso v1, mas alvo de longo prazo). | Disclosure obrigatório, "Do Not Sell My Info" link, opt-out de sharing, response em 45 dias. **Aplica mesmo na fase piloto** se ≥ 1 prospect for CA resident. |
| **COPPA** (16 CFR Part 312) | Coleta de dados de menores de 13. | Prospect de seguro de vida tipicamente adulto. **Mas** o questionário coleta `nascimento` — se um menor preencher, viola COPPA. **Mitigação:** age gate explícito no início do funil. |
| **TCPA** (47 USC §227) | Envio de SMS/chamadas automatizadas para celulares sem opt-in expresso. | WhatsApp link manual do agente **não** é TCPA. Mas: se Live Long automatizar disparos em massa para prospects via WhatsApp, **vira TCPA**. Penalidade: $500–$1.500 por mensagem. |
| **CAN-SPAM** (15 USC §7701) | Emails comerciais. | `notifyAgentOnNewLead` envia email **para o agente** (não comercial — funcional). Mas se Live Long mandar email para o **prospect** ("Confira seu plano!"), aplica. |
| **GLBA** (Gramm-Leach-Bliley Act) | Aplica a instituições financeiras incluindo **insurance providers**. Whenote não tem; Live Long **possivelmente** tem porque coleta financial information para qualificar para insurance. | "Safeguards Rule" — controles administrativos, técnicos e físicos. Live Long é **processador** dos agentes licenciados — pode estar dentro do escopo via cadeia. Discutir com advogado de seguros. |
| **HIPAA**? | Aplica a "covered entities" (planos de saúde, providers, clearinghouses). | Life insurance **não é HIPAA**. Mas **disability insurance** pode ser. Para v1 (life insurance only), **HIPAA não aplica**. Documentar. |

### 1.2 Estaduais — Flórida (mercado v1)

| Lei | Pontos críticos |
|-----|----------------|
| **Florida Information Protection Act (FIPA)** (Fla. Stat. §501.171) | Breach notification em até 30 dias para affected individuals + AG. **Cobre** "personal information": SSN, driver's license, financial account #, **medical/insurance** info, **biometric**. Vários campos coletados pelo Live Long se enquadram. |
| **Florida Insurance Code** (Fla. Stat. Title XXXVII) | **Ana não pode** recomendar produto/preço — só agente licenciado pelo FL DFS. Disclaimer obrigatório. **R1** em [RISKS.md](RISKS.md). |
| **NAIC Model Privacy Regulation (Model 870)** | Adotado pela FL (Fla. Stat. §626.9651). Define como "licensee" (= o agente, não o Live Long diretamente) deve tratar "nonpublic personal information". Live Long é **fornecedor** do licensee → contrato escrito é exigido (Service Provider Agreement). |
| **Florida Telemarketing Act** (Fla. Stat. §501.059) | Exige opt-in para envio de chamadas comerciais. Análogo a TCPA. |

### 1.3 Estaduais — outros (alvo futuro)

| Estado | Lei | Quando aplica |
|--------|-----|--------------|
| Texas | **TDPSA** (Texas Data Privacy and Security Act) | 100k consumidores ou 25k + venda de dados. Pouco provável v1, mas mapear. |
| Virginia | **VCDPA** | Idem TDPSA. |
| Colorado | **CPA** | Idem. |
| Nova York | **SHIELD Act** | Breach notification. |
| Connecticut | **CTDPA** | Idem VCDPA. |

> **Princípio operacional:** redigir a Privacy Policy alinhada a **CCPA/CPRA**
> (mais estrita entre as federais/estaduais que se aplicam **hoje**). Se um
> day virar TDPSA/VCDPA, requer atualização tópica, não rescrita.

### 1.4 Internacionais — quando preocupar

| Lei | Quando ativar |
|-----|--------------|
| **GDPR** (UE) | Se agente UE for cliente OU prospect UE preencher. Probabilidade baixa v1 (FL only), **mas** rastrear via IP/locale. Se acionar, requer SCCs com Anthropic/Cloudflare/Google. |
| **LGPD** (Brasil) | Se prospect resident no **Brasil** (não brasileiro nos EUA). Probabilidade baixa v1. |
| **PIPEDA** (Canadá) | Se expandir para CA. |
| **UK GDPR** | Idem GDPR UE. |

---

## 2. Mapa de dados coletados — Live Long

Inspirado em [`OpenWhen/planning/DATA_RETENTION_POLICY.md §1`](../../OpenWhen/planning/DATA_RETENTION_POLICY.md).
Auditoria do código em **2026-05-23**.

### 2.1 Dados do Agente (cliente pagante)

| Campo | Onde | Obrigatório? | Sensibilidade |
|-------|------|--------------|---------------|
| Email | `users/{uid}` + Firebase Auth | Sim | Baixa |
| `displayName` (nome real) | `users/{uid}`, `sellers/{id}.displayName` | Sim | Baixa |
| Foto | Storage `agents/{uid}/photo` | Não | Baixa |
| WhatsApp (telefone) | `sellers/{id}.phone`, `agents/{uid}.whatsapp` | Sim para venda | Baixa-Média |
| Bio | `sellers/{id}.bio` | Não | Baixa |
| `slug` (URL pública) | `sellers/{id}.slug`, `seller_slugs/{slug}` | Sim | **Pública por design** |
| Idioma | `sellers/{id}.idioma` | Não | Baixa |
| Nicho | `sellers/{id}.nicho` | Não | Baixa |
| Instagram / LinkedIn | `sellers/{id}.instagramUrl`, `linkedinUrl` | Não | Baixa |

### 2.2 Dados do Prospect (data subject, sem conta)

| Campo | Onde | Sensibilidade | Categoria CCPA |
|-------|------|---------------|----------------|
| Nome | `leads.nome` / `prospectName` | Média | Identifiers |
| Telefone | `leads.telefone` / `prospectPhone` | Média | Identifiers |
| Data de nascimento (idade) | `leads.nascimento` | **Sensitive** | Sensitive Personal Info (CPRA) — idade pode revelar minor |
| Idioma | `leads.lang`, `locale` | Baixa | Inference |
| Respostas do questionário | `leads.answers` (dependentes, renda, seguro atual) | **Alta** | Sensitive — **financial** info |
| Score calculado | `leads.score` (0-100) | Média | Inference |
| Plano recomendado (educacional) | `leads.recommendedPlan` | Média | Inference |
| Conversa com Ana | **não persistido no Firestore** (`chat_screen.dart` mantém em memória) | **Alta** se contém saúde | — |

> ⚠️ **Achado crítico:** chips de sugestão em [`chat_screen.dart:99-104`](../lib/legacy/screens/chat_screen.dart)
> incluem "Tenho pré-existência" / "Tengo una condición preexistente" /
> "I have a pre-existing condition". **Se o prospect tocar isso**, o
> conteúdo da mensagem subsequente vai para Anthropic e contém **health
> information**. Hoje não persiste no Firestore, mas:
> 1. Anthropic recebe (logs por 30 dias por padrão).
> 2. Cloudflare Worker pode logar.
> 3. **State insurance law** classifica condição médica como "nonpublic
>    personal health information" — categoria especial sob NAIC Model 670
>    (insurance regulations específicas para saúde, mas FL aplicou
>    aos demais ramos via §626.9651).
>
> **Mitigação proposta:** remover esse chip, OU adicionar disclaimer
> explícito "não compartilhe condições médicas com a assistente — fale com
> o consultor licenciado por canal seguro".

### 2.3 Dados de logs (server-side)

| Campo | Onde |
|-------|------|
| IP do prospect (request) | Cloudflare Worker logs (30 dias default) |
| User-Agent | Idem |
| Logs Cloud Functions | Google Cloud Logging (30 dias) |
| Logs Anthropic | Anthropic dashboard (zero data retention disponível se contratado em plano enterprise) |

### 2.4 Dados que **NÃO** são coletados (declarar explicitamente)

- SSN do prospect ✅
- Driver's license number ✅
- Cartão de crédito ou conta bancária do prospect ✅ (cobrança é com o agente, fora do app)
- Localização GPS ✅
- Acesso a contatos do device ✅
- Histórico médico estruturado ✅ (mas ver §2.2 warning)
- Dados biométricos ✅

---

## 3. Estrutura proposta — Privacy Policy (Live Long)

Modelo adaptado de [`OpenWhen/planning/LEGAL.md §5`](../../OpenWhen/planning/LEGAL.md).
**Não substitui** revisão por advogado especializado em insurance + privacy
(sugestões abaixo).

### 3.1 Seções (16 — vs 17 do Whenote)

| # | Seção | Conteúdo essencial |
|---|-------|--------------------|
| 1 | **Definitions** | "Agent", "Prospect", "Tenant", "Personal Information" (CCPA def.), "Educational Content" (não advice) |
| 2 | **Who we are** | HitLook LLC (assumindo formação) / contatos: `privacy@hitlook.us`, `dpo@…` |
| 3 | **Information we collect** | Inventário do §2 acima, separado em: (a) coletado do agente (b) coletado do prospect (c) coletado automaticamente |
| 4 | **How we use it** | Lead qualification, comunicação agente↔prospect, melhoria do produto, segurança |
| 5 | **Educational AI — Ana** | Disclaimer central: "Ana provides general financial education. She does NOT recommend insurance products. All recommendations come from your licensed agent." + lista Anthropic como subprocessador |
| 6 | **Sharing of information** | (a) Agentes — recebem dados do próprio prospect (b) Tenants/empresas — admin vê leads da empresa (c) Third-party service providers: Google Firebase, Anthropic, Cloudflare. **CCPA: We do NOT sell personal information.** |
| 7 | **Insurance regulatory disclosure** | "Live Long is not a licensed insurance producer. All licensed activities are performed by independent agents in the relevant state. Live Long acts as software vendor under §626.9651 Fla. Stat. and NAIC Model 870." |
| 8 | **Your rights** | Sub-seções: (a) CCPA/CPRA rights — Know, Delete, Correct, Opt-out, Limit (b) Other state laws if applicable. **Resposta em 45 dias.** |
| 9 | **Data retention** | Detalhar §5 abaixo |
| 10 | **Security measures** | TLS, Firebase rules, App Check, Cloudflare WAF |
| 11 | **Breach notification** | FIPA — até 30 dias, AG da FL + affected individuals. CCPA — sem prazo fixo mas "in the most expedient time possible" |
| 12 | **International users** | "Service intended for US residents. If you're outside the US, you acknowledge data is processed in the US." (não evita GDPR mas reduz surface) |
| 13 | **Minors** | "We do not knowingly collect data from individuals under 18. If you become aware that a minor provided data, contact us for deletion." |
| 14 | **Cookies and tracking** | Firebase Analytics (se ligado), Crashlytics, App Check. **ATT** declared. |
| 15 | **Changes to this policy** | Versão + data. Notificação por banner in-app + email para agentes. |
| 16 | **Contact** | DPO, email, postal address (LLC), processo CCPA Authorized Agent |

### 3.2 Idiomas

A política deve estar em **EN, PT, ES** desde o release, pelo mesmo motivo
do app:

- Agente latino lê em PT/ES — exigência prática.
- Prospect latino idem.
- Padrão Whenote teve **4 idiomas** (EN, PT, PT-BR, ES) com ARB files.
  Live Long pode começar com **3** (EN, PT, ES) — não há razão para
  separar PT-BR de PT-PT no contexto FL.

Arquivos sugeridos:

```
web/
  privacy.en.html
  privacy.pt.html
  privacy.es.html
  terms.en.html
  terms.pt.html
  terms.es.html
```

E nas configurações do Firebase Hosting, redirect baseado em
`Accept-Language` (não bloqueante v1; pode começar com `/privacy` →
`privacy.en.html`).

### 3.3 Bases legais — CCPA

CCPA não tem "legal basis" como GDPR. O que importa:

- **Notice at collection** — antes ou no momento da coleta. Live Long
  satisfaz com a tela de splash do prospect mostrando "By continuing, you
  agree to our Privacy Policy."
- **Purpose disclosure** — qual finalidade. Já mapeado em §3.1 (4).
- **Sale/Share disclosure** — Live Long NÃO vende. Declarar **explicitamente**.

---

## 4. Estrutura proposta — Terms of Use (Live Long)

### 4.1 Seções (10)

| # | Seção | Conteúdo essencial |
|---|-------|--------------------|
| 1 | **Acceptance** | "By using HitLook/Live Long, you agree to these Terms." Versão + data. |
| 2 | **Services description** | Software para qualificação de leads. NÃO é insurance broker, NÃO oferece insurance advice, NÃO é licenciado pelo FL DFS. |
| 3 | **User accounts** | Agente: criado por admin via [`createSellerAccount`](../functions/index.js). Cada agente confirma que é "licensed insurance producer in the relevant state". 🟡 **Idealmente coletar # de licença do agente — não está no schema hoje** ([`docs/11-SCHEMA-DEFINITIVO.md`](../docs/11-SCHEMA-DEFINITIVO.md)) |
| 4 | **Acceptable use** | Não compartilhar credenciais; não usar para spam (TCPA disclaimer); não usar para produtos não-seguro |
| 5 | **Subscription and payment** | Stripe ou cobrança offline; mensal/anual; cancelamento any time. (v1 sem IAP no app, ver [RISKS.md R13](RISKS.md).) |
| 6 | **Intellectual property** | HitLook é dono do software. Conteúdo do agente (foto, bio) — agente mantém propriedade, concede licença para Live Long exibir. Conteúdo do prospect (respostas) — agente é "data controller", Live Long é "data processor". |
| 7 | **Disclaimer of warranties** | Software "AS IS". **Não garante** que prospect vai converter. **Não garante** uptime 100%. **Cláusula central:** "The Educational Assistant ('Ana') provides general information only and is NOT a substitute for advice from a licensed insurance agent in your state." |
| 8 | **Limitation of liability** | Cap em 12× a taxa mensal paga pelo agente (padrão SaaS B2B). Excluir consequential damages até o limite permitido pela FL law. |
| 9 | **Indemnification** | Agente indemnifica HitLook se usar a plataforma para insurance advice sem licença, ou se viola TCPA ao automatizar disparos. |
| 10 | **Governing law and disputes** | Florida law. Venue em Miami-Dade County. **Arbitration clause** (AAA rules) opcional — discutir com advogado pois pode ser inválida em alguns estados ou contra consumidor. |

### 4.2 Cláusulas específicas que **Whenote tem e Live Long precisa adaptar**

| Whenote | Live Long |
|---------|-----------|
| "Cartas entregues mesmo em encerramento" + Fundo de Continuidade ([`OpenWhen/planning/LEGAL.md §1`](../../OpenWhen/planning/LEGAL.md)) | **N/A** — Live Long não tem promessa de delivery futura |
| Cláusula de descontinuação 90 dias | **Sim, mas curta** — 30 dias é suficiente; B2B SaaS standard |
| Cláusula de IA/moderation | **Substituída por** cláusula de IA/educational + insurance disclaimer |

### 4.3 Cláusulas **novas** específicas de insurance / B2B

- **Service Provider Agreement (SPA)** com o agente — Live Long é
  "Service Provider" sob CCPA (não revende dados). SPA pode ser embutido nos
  ToU ou separado para B2B Enterprise.
- **BAA (Business Associate Agreement)** — só se acidentalmente tocar HIPAA
  data (saúde via Ana). Para v1, prevenir coleta em vez de assinar BAA.
- **Insurance license attestation** — agente declara "I am licensed in
  [state]" no signup. Hoje **não existe** — adicionar campo no
  `createSellerAccount` callable + UI do admin.

---

## 5. Retenção de dados — proposta

Inspirada em [`OpenWhen/planning/DATA_RETENTION_POLICY.md`](../../OpenWhen/planning/DATA_RETENTION_POLICY.md),
adaptada ao contexto B2B insurance.

| Categoria | Retenção | Por quê | Como expurgar |
|-----------|----------|---------|---------------|
| Agente — perfil ativo | Enquanto assinatura ativa | Operacional | Quando agente cancela: 30 dias grace → deletar conta + cascata |
| Agente — após cancelamento | 30 dias (grace) + 6 anos para fins fiscais/audit | FL statute of limitations contratos + IRS retention | Soft-delete + audit log |
| Prospect — lead **não convertido** | **24 meses** (alinhado a [`docs/07-RISKS.md`](../docs/07-RISKS.md) §8) | Permitir agente re-trabalhar lead frio | Scheduled CF `purgeOldLeads` |
| Prospect — lead **convertido (apólice fechada)** | Conforme **state insurance law** — tipicamente **5-7 anos** após término da apólice | NAIC Model + FL §626.748 | Manual — agente reporta conversão |
| Prospect — quando solicita exclusão (CCPA) | Excluir em até 45 dias | CCPA §1798.105 | Manual via `privacy@hitlook.us` ou Cloud Function dedicada |
| Conversa com Ana | **Não persistir** (já é o caso) | Reduzir surface | N/A |
| Logs Cloud Functions | 30 dias (Google default) | Debug | Auto |
| Logs Cloudflare Worker | 30 dias | Debug | Auto |
| Audit logs de privacidade (deletions, exports) | 3 anos hasheados (sem PII) | Provar compliance se questionado | Manter |

🟡 **DECISÃO PENDENTE — Diego/Renan:** lead convertido fica **com o agente
ou com o tenant**? Se o agente sair da M4LIFE, os leads dele vão com ele
ou ficam com Renan? Implicação contratual + privacy: prospect deu consent
para "M4LIFE agent", não para "agente independente".

---

## 6. Disclaimer regulatório — onde exibir

Mapeado em [APPLE_RELEASE.md §2.4](APPLE_RELEASE.md) e
[RISKS.md R1](RISKS.md). Texto sugerido (EN — adaptar PT/ES):

```
This is an educational tool. It does not provide insurance advice.
All recommendations must come from a licensed insurance agent in your
state.
```

**3 locais obrigatórios:**

1. **Splash do prospect** — primeira tela vista.
2. **Header da Ana** — abaixo de "M4LIFE Assistant • Online".
3. **Antes do botão "Falar com consultor"** no resultado.

**Adicionais recomendados:**

4. **Política de Privacidade §7** (insurance regulatory disclosure).
5. **App Store description** — em até 3 linhas.
6. **Email transactional** (`notifyAgentOnNewLead`) — rodapé, EN/PT/ES.
7. **Tela de admin do agente** — disclaimer "You are responsible for
   compliance with your state insurance license requirements."

---

## 7. Direitos dos titulares — implementação prática

Equivalente a [`OpenWhen/planning/OPERATIONAL_PRIVACY_RUNBOOKS.md`](../../OpenWhen/planning/OPERATIONAL_PRIVACY_RUNBOOKS.md).

### 7.1 Right to Know (CCPA §1798.110)

Prospect ou agente solicita "what data do you have on me".

**Procedimento manual (v1):**

1. Email para `privacy@hitlook.us`.
2. Verificação de identidade (responder do email associado, ou para
   prospect: confirmar telefone + agentId).
3. Diego/Yuri exporta via Firebase Console (manual).
4. Envia em até **45 dias** (CCPA prazo).
5. Loga em spreadsheet de DSAR.

**Automação v1.2:** Cloud Function callable `exportMyData` que:
- Para agente: agrega `users/{uid}`, `sellers/{id}`, `agents/{uid|slug}`,
  fotos.
- Para prospect: agrega `leads.where(telefone == X)` em todas as collections.
- Retorna JSON assinado por 7 dias.

### 7.2 Right to Delete (CCPA §1798.105)

Mesmo fluxo do §7.1, mas em vez de exportar, executa delete.

**v1 manual:**

1. Email para `privacy@hitlook.us`.
2. Verifica identidade.
3. Diego/Yuri exclui via Firebase Console.
4. Audit log: `deletionLogs/{hashedUid}` com `deletedAt`, `requestedBy`, hash do email.
5. Responde em 45 dias confirmando.

**Exceções permitidas pela CCPA §1798.105(d):**
- Manter dados necessários para concluir transação solicitada (lead em
  follow-up ativo) — explicar no response.
- Manter dados para compliance (audit logs hasheados — sem PII).

### 7.3 Right to Opt-out of Sale/Share

Live Long **não vende**, mas se tiver Facebook Pixel ou Google Ads tag
no futuro, "sharing" pode aplicar.

**v1:** declarar "We do not sell or share". Sem botão necessário.

**v1.1 quando ligar Analytics:** "Do Not Sell or Share My Personal Information"
link rodapé (CCPA requirement).

### 7.4 Right to Limit Use of Sensitive PI (CPRA)

Aplica se Live Long usa sensitive PI (idade, financial info) para finalidade
**outra** que a coleta original. Hoje a finalidade é **única** (qualificar
lead) → não precisa do botão.

### 7.5 SLA de resposta

- **CCPA/CPRA:** 45 dias (45 + 45 extensão se justificado).
- **GDPR (se acionar):** 30 dias (30 + 60 extensão).
- **FIPA breach:** 30 dias para notificar.

---

## 8. Subprocessadores — inventário obrigatório

CCPA exige listar terceiros que recebem PI. Privacy Policy §6.

| Subprocessador | O que processa | Localização | Sub-subprocessadores |
|----------------|----------------|-------------|----------------------|
| **Google LLC** (Firebase) | Auth, Firestore, Storage, Hosting, Functions | US (multi-region) | GCP subprocessors list |
| **Anthropic, PBC** | Conversas Ana (não persiste no FB) | US | AWS (US) |
| **Cloudflare, Inc.** | Worker proxy, DNS | Global | — |
| **Apple Inc.** (futuro) | Sign in with Apple, App Store, TestFlight | US | — |
| **Stripe, Inc.** (futuro) | Cobrança do agente | US | — |
| **Trigger Email extension (SMTP)** | Envio do email "Novo lead" | Depende do SMTP — Workspace ou SendGrid | Configurar em produção |

**Ação operacional:** manter este inventário **atualizado** e mostrar publicamente
em `/privacy.html` — CCPA §1798.130(a)(5) exige "categories of third
parties with whom we share".

---

## 9. Breach notification — playbook FIPA + CCPA

Inspirado em [`OpenWhen/planning/OPERATIONAL_PRIVACY_RUNBOOKS.md §3`](../../OpenWhen/planning/OPERATIONAL_PRIVACY_RUNBOOKS.md).

### 9.1 Detecção

Sinais possíveis:
- Alerta de billing Anthropic/Firebase fora do padrão (R5 em [RISKS.md](RISKS.md)).
- Crashlytics report de tentativa de acesso negado em massa.
- Email de pesquisador ou usuário relatando vazamento.
- Alerta App Check de "unverified requests" alto.

### 9.2 Containment (24h)

1. Desabilitar a feature/endpoint afetado.
2. Revogar API keys impactadas (Anthropic, Stripe).
3. Force-logout de todos os agentes se Firestore comprometido
   (`admin.auth().revokeRefreshTokens(uid)` em batch).
4. Snapshot de logs.

### 9.3 Assessment (48h)

- Quantos affected individuals?
- Tipo de dados expostos?
- Risco de harm? (PII básico vs financial vs medical)

### 9.4 Notification (até 30 dias)

**Por lei (FL FIPA §501.171):**

- ≥ 1 FL resident afetado → **Florida AG** (`http://myfloridalegal.com`).
- ≥ 500 FL residents → AG **+** consumer reporting agencies.
- Notificar affected individuals "without unreasonable delay" e dentro de
  30 dias.

**Por CCPA:** "in the most expedient time possible and without
unreasonable delay".

**Template de notificação** — ver Whenote OPERATIONAL Anexo C como referência;
adaptar para inglês legal US.

### 9.5 Audit log

Manter **3 anos** record do incident, com:
- Data de descoberta
- Vetor de ataque
- Dados expostos
- Affected count
- Notificações enviadas
- Remediação

---

## 10. Estrutura de empresa (LLC / corporate veil)

🟡 **DECISÃO PENDENTE.** Whenote tem [`OpenWhen/planning/DELAWARE.md`](../../OpenWhen/planning/DELAWARE.md)
documentando incorporação. Live Long precisa fazer o mesmo.

**Por quê para o release:**

- App Store Connect — empresa precisa ser entidade jurídica para conta
  developer business.
- ToU — "HitLook LLC" precisa existir para ser parte do contrato.
- Liability — sem LLC, Diego responde pessoalmente por qualquer claim.

**Opções:**

| Estrutura | Pros | Contras |
|-----------|------|---------|
| **Delaware LLC** | Padrão SaaS US, fácil de gerir, anonimato relativo, sem state tax intra-DE | Anual ~$300 (filing) + registered agent ~$100/ano |
| **Florida LLC** | Diego está em FL, mais simples para banking local, conhecido pelo FL DFS | Anual ~$140 |
| **Pessoa física + DBA** | Zero custo | **Não usar** — Apple recusa para tax US, e nenhum corporate veil |

**Recomendação:** **Florida LLC** v1 (Diego já em FL, regula seguros aqui).
Converter para Delaware se um dia houver fundraising.

🟡 **Decisão Diego.** Mas **antes** da primeira submissão Apple — ID fiscal
(EIN) é obrigatório no App Store Connect.

---

## 11. Checklist de ação antes do release

Em ordem de prioridade:

- [ ] **🔴 L1 — Decidir entidade jurídica** (FL LLC vs DE LLC) e obter
      EIN no IRS. ~ 2 semanas (incluindo state filing).
- [ ] **🔴 L2 — Escrever Privacy Policy** em EN/PT/ES seguindo §3.
      ~ 2 dias (Diego ou copywriter; **revisar com advogado**).
- [ ] **🔴 L3 — Escrever Terms of Use** em EN/PT/ES seguindo §4.
      ~ 1 dia.
- [ ] **🔴 L4 — Publicar `/privacy.html` e `/terms.html`** em Firebase Hosting.
      ~ 30 min.
- [ ] **🔴 L5 — Disclaimer regulatório em 3 telas do app** ([§6](#6-disclaimer-regulatório--onde-exibir)).
      ~ 2h.
- [ ] **🔴 L6 — Consulta com advogado de insurance regulation FL.**
      Já listado em [`docs/05-CHECKLIST.md`](../docs/05-CHECKLIST.md). 1-2h, $300-500.
      Validar Privacy Policy + ToU + disclaimer.
- [ ] **🟠 L7 — Remover chip "I have a pre-existing condition"** de
      [`chat_screen.dart`](../lib/legacy/screens/chat_screen.dart). 5 min.
- [ ] **🟠 L8 — Field `licenseNumber` no schema `users/{uid}`** para agente
      declarar sua licença estadual. Coletar no `createSellerAccount` UI.
- [ ] **🟠 L9 — Service Provider Agreement embutido nos ToU §6** ou
      separado. Discutir com advogado.
- [ ] **🟡 L10 — Age gate no início do funil do prospect** (data de
      nascimento → bloquear < 18).
- [ ] **🟡 L11 — Email de DSAR** `privacy@hitlook.us` (ou domínio
      decidido). Cloudflare Email Routing como Whenote — gratuito.

---

## 12. Quem consultar — perfil ideal do advogado

Live Long precisa de **um único** advogado com background híbrido raro
nos EUA:

| Especialidade | Por quê |
|---------------|---------|
| **Insurance regulation FL** (Title XXXVII) | Disclaimer da Ana, license attestation, Model 870 |
| **Privacy law US** (CCPA, FIPA) | Privacy Policy, breach response |
| **SaaS contracts** | ToU B2B, SPA com agente, liability cap |
| **Bilíngue PT/EN** | Diego é nativo PT — comunicação eficiente |

**Firms sugeridas (já em [`docs/03-HONEST_ASSESSMENT.md`](../docs/03-HONEST_ASSESSMENT.md) §5):**

- Mound Cotton — insurance defense
- Eversheds Sutherland — insurance regulation, escritório em Miami
- Locke Lord — insurance regulation, Brickell

Para uma consulta de 1-2h validando o package (Privacy + ToU + disclaimer):
$300-700. Para representação contínua, $200-400/h.

**Alternativa enxuta:** plataforma online (Clerky, Stripe Atlas, LegalZoom)
para LLC + EIN + ToU/Privacy template; revisar template com 1h de boutique
firm depois. Custo total: ~$800.

---

## 13. Diferenças finais Live Long vs Whenote — para não confundir

| Tema | Whenote | Live Long |
|------|---------|-----------|
| Direito ao apagamento | GDPR Art. 17, LGPD Art. 18, CCPA — 30/15/45 dias | **CCPA 45 dias** (LGPD/GDPR só se acionado) |
| Idade mínima | 13 (COPPA) com gates por jurisdição | **18** recomendado (insurance product) — gate explícito |
| Localização GPS | Coletada opt-in | **Não coletada** — manter assim |
| Pagamento | Stripe in-app (mobile IAP fallback) | **Stripe fora do app** v1 (B2B SaaS) |
| Promessa de futuro | "Cartas entregues" → Fundo Continuidade | **N/A** — sem promessa temporal |
| IA / moderation | OpenAI moderation (safety) | **Anthropic educational** (insurance disclaimer obrigatório) |
| Risco regulatório principal | App Store guidelines | **State insurance commissioner** + Apple + CCPA |
| Audit log | Privacy events (export, delete, reauth) | **Privacy events + insurance disclosures** (data sharing entre agente e tenant) |

---

## 14. Pendências e revisões

| Item | Pendência | Quando |
|------|-----------|--------|
| Privacy Policy draft EN/PT/ES | A escrever | Antes da submissão Apple |
| Terms of Use draft EN/PT/ES | A escrever | Antes da submissão Apple |
| Revisão por advogado FL | A agendar | Antes da submissão Apple |
| LLC + EIN | A formalizar | **Bloqueia** App Store Connect |
| `licenseNumber` schema field | Discutir com Diego | v1.1 |
| Cloud Function `exportMyData` | A implementar | v1.2 |
| Banner "Do Not Sell" no rodapé | Só quando ligar Analytics | v1.1 |

---

*Documento criado em 2026-05-23. Próxima revisão sugerida após primeira
consulta com advogado.*
