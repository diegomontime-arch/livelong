# 07 — Riscos

_Revisar a cada 30 dias. O que pode matar o negócio._

---

## 1 — Regulatório (insurance advice sem licença)

**Probabilidade:** média-alta · **Impacto:** crítico (fim de empresa)

"IA Ana" pode ser classificada como insurance advisory não-licenciada. Cada estado regula diferente. Florida DFS é atento. Reclamação de UM cliente dispara investigação.

**Mitigação:**
- Disclaimer em toda tela
- Ana **EDUCA e COLETA**, nunca **RECOMENDA** sem o agente humano confirmar
- Logs auditáveis das conversas
- Consulta jurídica formal antes dos primeiros 50 agentes
- Termos aceitos por agente E prospect

---

## 2 — Dependência de um cliente (Renan / M4LIFE)

**Probabilidade:** alta · **Impacto:** alto

Hoje o negócio respira pelo Renan. Se ele sair, perde interesse ou bate cabeça com você, piloto morre.

**Mitigação:**
- Contrato escrito de parceria
- Diversificar canais até fim do mês 3 (≥1 cliente fora da rede do Renan)
- Não dar exclusividade total
- Relacionamento direto com agentes M4LIFE, não filtrar por Renan

---

## 3 — Vazamento de API key Anthropic

**Probabilidade:** alta se mal feita · **Impacto:** alto

Key embedada no Flutter frontend = qualquer um extrai e usa. Você paga.

**Mitigação:**
- Chamadas à Anthropic API via Firebase Cloud Function (backend)
- Frontend nunca conhece a key
- Rate limit por usuário autenticado
- Alerta Firebase se uso > $50/dia
- Rotação a cada 90 dias

---

## 4 — Custo Claude API descontrolado

**Probabilidade:** média · **Impacto:** médio-alto

Ana virar "amiga do cliente" — prospects ficam horas conversando.

**Mitigação:**
- Limite de mensagens por sessão (~20)
- Cache de respostas comuns
- System prompt enxuto (token-aware)
- Sonnet pra conversa rica, Haiku pra resposta rápida
- Monitoria diária do custo

---

## 5 — Concorrente americano replica

**Probabilidade:** baixa-média · **Impacto:** médio

Se pegar, insurtech americana pode lançar "para latinos" com mais capital. Vão tropeçar na falta de cultural fit, mas é risco.

**Mitigação:**
- Velocidade de execução
- Profundidade cultural (conteúdo, narrativa, depoimentos em PT)
- Relacionamento com agentes — eles confiam em você, não em corporação americana
- Construir comunidade, não só software

---

## 6 — Solo founder burnout

**Probabilidade:** alta (janela 6-18 meses) · **Impacto:** crítico

Diego tem resiliência militar, mas SaaS sozinho com 1000 detalhes por dia quebra qualquer um. Yuri saiu.

**Mitigação:**
- Limite: 8h/dia + 1 dia de folga por semana
- Treino físico mantido
- Mentor externo — 1 conversa/mês com alguém mais experiente em SaaS
- Cofounder ou primeiro funcionário até mês 6
- Família é a razão do projeto, não o sacrifício dele

---

## 7 — Inglês intermediário limita expansão

**Probabilidade:** certa · **Impacto:** médio

Sales B2B nos EUA, partnerships, fundraising, suporte premium — tudo em inglês fluente.

**Mitigação:**
- Estudo 30 min/dia (Anki + conversa semanal)
- Foco em PT-BR durante ano 1 (mercado suficiente)
- Head of Sales nativo no mês 6-9
- Quando call importante em inglês, leva alguém junto

---

## 8 — LGPD / CCPA — privacidade

**Probabilidade:** média · **Impacto:** alto se ignorado

Coleta dados sensíveis (nome, telefone, idade, situação familiar e financeira) de prospects sem termo de privacidade compliant = problema.

**Mitigação:**
- Termo CCPA-compliant (FL statutes também)
- Botão "excluir meus dados"
- Retenção máxima 24 meses pra prospects não convertidos
- Criptografia em trânsito e repouso (Firebase entrega)
- Não compartilhar dados entre tenants

---

## 9 — Vendor lock-in Firebase

**Probabilidade:** certo a longo prazo · **Impacto:** médio

Hoje Firebase é perfeito. Em 3 anos com volume, custo pode virar problema e migrar é doloroso.

**Mitigação:**
- Repository pattern desde já (camada de abstração de dados)
- Evitar features super-específicas do Firebase quando alternativa portátil existir
- Plano de migração teórico documentado ao passar de $50k MRR

---

## 10 — Você se apaixonar pela tese errada

**Probabilidade:** comum em fundadores · **Impacto:** crítico

Acreditar que o problema é falta de feature/design/marketing — quando o problema real é que o mercado não quer pagar por isso, ou quer outra coisa.

**Mitigação:**
- Dados, não sentimento
- Entrevistas honestas com clientes a cada 30 dias
- Mentor/advisor que pode te dizer "para com isso"
- Critério claro de kill the project (ver `04-ROADMAP.md` final)
- Persistência ≠ teimosia
