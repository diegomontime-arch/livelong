# 12 — Roadmap de Escalabilidade (atualizado 26/05/2026)

## O que implementar AGORA (antes do segundo tenant)

### 1. Stripe — Pagamento $27/mês por agente
- Integração com Stripe Checkout
- Webhook para ativar/desativar agentes
- Painel de billing no admin
- Planos: Starter (1 agente), Team (5 agentes), Pro (ilimitado)
- **Prioridade: CRÍTICO — sem isso não cobra**

### 2. Firestore Rules — Isolamento multi-tenant
- Garantir que dados da M4LIFE não vazam para Portobello
- Revisar todas as regras de leitura cruzada entre empresas
- Testar com dois tenants ativos
- **Prioridade: CRÍTICO — risco de segurança**

### 3. Firestore Indexes — Performance
- Revisar queries sem índice
- Adicionar índices compostos para leads por empresa
- Testar com volume de 1000+ leads
- **Prioridade: CRÍTICO — vai travar em produção**

### 4. LGPD Básico — Conformidade legal
- Aviso de privacidade antes do formulário do prospect
- Aceite explícito dos termos
- Política de privacidade acessível
- **Prioridade: CRÍTICO — risco legal**

### 5. CSV Export — Feature básica de CRM
- Exportar leads por agente em CSV
- Exportar leads por empresa
- Filtrar por período e status
- **Prioridade: IMPORTANTE — todo cliente vai pedir**

---

## O que implementar com 5+ clientes pagando

### 6. Admin Panel completo
- Gestão de usuários e empresas
- Métricas de uso por tenant
- Suporte e bloqueio de contas
- Faturamento e histórico de pagamentos

### 7. Notificações email automáticas
- Email para agente quando lead chega
- Trigger Email Firebase Extension
- Template com dados completos e guia de abordagem

### 8. Analytics do funil
- Quantos abriram o link
- Quantos completaram o diagnóstico
- Taxa de conversão por agente
- Leads por idioma

### 9. Open Graph dinâmico por agente
- Preview personalizado no WhatsApp
- Foto do agente no preview
- Requer Cloud Function ou SSR

---

## O que implementar com 20+ clientes pagando

### 10. App nativo iOS/Android
- Painel do agente como app nativo
- Push notifications via FCM
- Acesso offline aos leads

### 11. White-label completo
- Logo, cores e domínio por empresa
- Subdomínio próprio: m4life.hitlook.app
- Domínio próprio: m4lifeusa.com aponta para HitLook

### 12. API pública
- Empresas integram HitLook com CRM próprio
- Webhooks para eventos de lead
- Documentação da API

### 13. Marketplace de nichos
- Templates de questionário por setor
- Seguro, pisos, solar, mortgage, imigração
- Empresa configura sem código

---

## Tenants planejados

| Tenant | Nicho | Status |
|---|---|---|
| M4LIFE USA (Renan) | Seguro de vida | Piloto ativo |
| Portobello America (esposa) | Pisos | Próximo |
| Empresa solar | Solar | Backlog |
| Escritório jurídico | Imigração | Backlog |

---

## Modelo de receita projetado

| Clientes | Agentes médios | Receita mensal |
|---|---|---|
| 1 (piloto) | 10 | $270 |
| 5 empresas | 10 cada | $1,350 |
| 20 empresas | 10 cada | $5,400 |
| 100 empresas | 10 cada | $27,000 |

Custo de infraestrutura a $27K/mês de receita: ~$500/mês
Margem: 98%
