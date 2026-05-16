# 06 — Modelo de Negócio

## Pricing recomendado

| Plano | Preço | Para quem |
|---|---|---|
| Early Bird (primeiros 50) | $47/mês locked-for-life | Pilotos M4LIFE e early adopters |
| Anual Early Bird | $397/ano (~$33/mês) | Quem topa pagar antes |
| Padrão | $97/mês | Após os primeiros 50 |
| Anual Padrão | $797/ano (~$66/mês) | Compromisso anual |
| Tenant Enterprise | $497-997/mês fixo + $19-29/agente | M4LIFE, Portobello (white label) |

**Por que não $27:** preço baixo demais sinaliza valor baixo, não cobre custos. Detalhes em `03-HONEST_ASSESSMENT.md`.

## Custos por agente / mês

| Item | Custo |
|---|---|
| Firebase Firestore | $0.50–2.00 |
| Firebase Storage | $0.20–0.50 |
| Firebase Hosting | $0.10 |
| Claude API (Ana) | $3–8 |
| Stripe fee (2.9% + $0.30) | $3.10 sobre $97 |
| **Total** | **$7–14/mês** |

Margem bruta a $97 = $83/mês = **85%**.
Margem a $27 = $13 = **48%** (insustentável com suporte).

## Unit economics — meta ano 1

| Métrica | Alvo |
|---|---|
| MRR | $10.000 (~100 agentes) |
| CAC | $50–150 |
| LTV | $1.500–2.500 |
| LTV/CAC | 10x+ |
| Churn mensal | < 8% |
| Payback | 1-2 meses |

## Estrutura com M4LIFE — opções

**A — Afiliado simples:** M4LIFE indica, HitLook paga 20-30% recorrente vitalício de cada agente trazido. Fácil de testar e desfazer.

**B — White label:** M4LIFE paga fee fixa ($497-997/mês) com todos os agentes incluídos até cota X. Acima, $19/agente. Branding M4LIFE total.

**C — Equity:** Renan recebe 5-10% por trazer os primeiros 100 e por ser caso fundador. Vesting 3 anos.

**Recomendação:** começa com A. Migra pra B se M4LIFE pegar e Renan quiser exclusividade. C só se você quiser fundador comercial de verdade.

## Cenários de receita

| Cenário | Agentes (12 meses) | MRR | ARR |
|---|---|---|---|
| Pessimista | 20 | $1.940 | $23k |
| Base | 75 | $7.275 | $87k |
| Otimista | 200 | $19.400 | $233k |
| Ambicioso (24m) | 750 | $72.750 | $873k |
| Sucesso (36m) | 2.000 | $194k | $2.3M |

Para $1M ARR (norte de SaaS B2B early): ~860 agentes pagantes. Factível com canal funcionando.

## Custos fixos atuais

| Item | $/mês |
|---|---|
| Firebase base | 25 |
| Domínio | 1 |
| Email transacional | 0–20 |
| Anthropic mínimo | 10 |
| **Total** | **36–56** |

Break-even em **1 agente a $97**. Mas a meta não é break-even — é construir negócio.

## Indicadores que importam (semanalmente)

- Agentes pagantes ativos
- MRR
- Novos por semana
- Cancelamentos
- NRR (Net Revenue Retention)
- Apólices fechadas reportadas
- Conversão prospect → qualified → fechado por agente

## Vanity metrics pra IGNORAR

- Total de visitas no site
- Total de "links enviados" sem cruzar com "vendas fechadas"
- Followers nas redes
