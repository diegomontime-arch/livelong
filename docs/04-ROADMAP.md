# 04 — Roadmap 30 / 60 / 90 dias

_Premissa: VALIDAR antes de ESCALAR. Cada fase tem objetivo único e mensurável._

---

## Fase 1 — Validar (dias 1-30)

**Objetivo único:** 5 agentes do M4LIFE pagantes e usando ativamente.

**"Ativamente"** = cada um enviou ≥10 links a prospects nas últimas 2 semanas.

### Técnico
- Compilar agent_setup_screen e deploy
- Login Firebase Auth
- Painel simples com lista de leads
- Botão WhatsApp funcional
- Stripe Checkout
- Firebase Analytics instrumentado (eventos básicos)
- Disclaimer "não é aconselhamento" em todas as telas
- Open Graph básico

### Negócio
- Reunião formal com Renan: proposta de parceria com revenue share
- Cartão de 5 agentes do M4LIFE no Stripe
- Métrica de sucesso definida: cada agente fechar pelo menos 1 venda extra rastreável em 30 dias

### NÃO fazer
- Multi-tenant (M4LIFE hardcoded)
- Expandir pra mexicanos
- Features além das listadas
- Marketing público
- Site institucional do HitLook

---

## Fase 2 — Refinar (dias 31-60)

**Objetivo único:** Provar que os 5 fecham MAIS vendas com HitLook do que sem.

### Técnico
- Dashboard de métricas por agente
- Customização da página do agente (depoimentos, vídeo curto)
- Notificações ao agente quando lead completa (push ou email)
- Histórico de leads
- Edição do perfil do agente

### Negócio
- Entrevista 1-a-1 com cada um dos 5 (30 min) — onde travaram, o que pedem
- Calcular ROI real: comissões geradas vs $47/mês
- Consulta com advogado de insurance regulation em FL
- Definir preço final (transição $47 → $97)

### NÃO fazer
- Buscar novos clientes ainda
- Adicionar idiomas/culturas além de PT-BR
- Stripe PJ — depois

---

## Fase 3 — Escalar (dias 61-90)

**Objetivo único:** 25 agentes pagantes ($1.175 MRR early bird ou $2.425 full price).

### Técnico
- Multi-tenant LEVE: separar config M4LIFE de "genérico"
- Painel admin do tenant (Renan vê agentes dele)
- Funil de upgrade (early bird → padrão)
- Rate limit, retry, observabilidade

### Negócio
- Lançamento oficial da parceria M4LIFE
- Conteúdo 3x/semana no YouTube em PT
- Lista de agências brasileiras na Flórida — outreach manual
- Primeira conferência de seguros

### NÃO fazer
- Verticais novas
- Levantar capital
- App nativo iOS/Android

---

## Metas

| Fim de fase | MRR | Agentes | Apólices extras geradas |
|---|---|---|---|
| 30d | $235 | 5 | ≥ 5 |
| 60d | $470 | 10 | ≥ 15 |
| 90d | $1.175-$2.425 | 25 | ≥ 50 |

## Critério de decisão fim do dia 90

- **MRR > $1.000 e churn < 10%:** dobra. Considera angel round de $100-250k pra Head of Sales nativo em inglês.
- **MRR < $500 e churn > 20%:** para. Reposiciona ou kill the project. Não rema contra a corrente.
- **MRR $500-$1.000:** mais 90 dias de iteração focada.
