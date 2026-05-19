# 05 — Checklist Operacional (atualizado 19/05/2026)

## PRIORIDADE MÁXIMA — Para mostrar ao Renan

### 1. Confirmar foto do agente no link do cliente
- [ ] Abrir https://hitlook-app.web.app/a/SiG1jKPkftSu72PMZZD2ieHEw472 em modo anônimo
- [ ] Confirmar que foto e nome aparecem no topo
- [ ] Se não aparecer — investigar AgentProvider.loadAgent

### 2. Dar acesso admin ao Renan
- [ ] Renan cria conta em /login com email dele
- [ ] Criar documento users/{uid-do-renan} no Firestore com:
      role: "admin", companyId: "m4life", email: "email-do-renan"
- [ ] Criar documento companies/m4life no Firestore com:
      name: "M4LIFE USA", tenantId: "m4life"
- [ ] Testar acesso ao /admin com conta do Renan

### 3. Resolver Ana (IA)
- [ ] Opção A: Cloudflare Worker como proxy (recomendado — gratuito)
- [ ] Opção B: Resolver permissão Cloud Build no Google Cloud IAM
- [ ] Testar Ana respondendo no celular

### 4. WhatsApp com mensagem pré-preenchida
- [ ] Implementar abertura do WhatsApp com número do agente
- [ ] Mensagem automática com nome do prospect e score

### 5. Deploy e teste final
- [ ] Build + deploy completo
- [ ] Testar fluxo completo no iPhone — idioma → onboarding → perguntas → resultado → WhatsApp
- [ ] Testar painel do Renan — criar agente → gerar link → ver leads

## IMPORTANTE — Resolver antes do lançamento

### Técnico
- [ ] Unificar schema de leads — decisão: usar legado ou SaaS?
- [ ] agentId sempre UID resolvido — nunca slug raw
- [ ] Remover logs de debug (public_lead_agent_id_log.dart)
- [ ] Stripe — $27/mês por agente
- [ ] Open Graph por agente — foto do agente no preview do WhatsApp

### Negócio
- [ ] Renan testa com 5 agentes piloto
- [ ] Definir métricas de sucesso do piloto
- [ ] Consulta jurídica — advogado de insurance regulation FL

## BACKLOG — Depois do piloto

### Mês 2
- [ ] Notificações push/email para o agente quando lead chega
- [ ] Status do lead editável no painel
- [ ] Analytics — leads abertos, completados, convertidos
- [ ] Tela de billing no app

### Mês 3+
- [ ] Portobello America — segundo tenant (esposa)
- [ ] Multi-tenant completo
- [ ] App nativo iOS/Android
- [ ] Plano Equipe — $149/mês até 5 agentes

## Regras do checklist
1. Toda semana — revisar e marcar o que foi feito
2. Máximo 5 itens ativos por semana
3. Toda modificação → build → deploy → git
