# 02 — Estado Atual (atualizado 19/05/2026)

## O que está funcionando

### Fluxo do cliente (COMPLETO E NO AR)
- Seleção de idioma — PT / ES / EN com bandeirinhas
- Layout responsivo — desktop duas colunas, mobile uma coluna
- Card do agente no topo — foto, nome, bio, WhatsApp
- Onboarding — nome, telefone, data de nascimento
- 5 perguntas de qualificação em 3 idiomas
- Score animado de proteção familiar
- Plano educacional recomendado
- Calculadora familiar interativa
- Chat com Ana (IA educacional) — CORS pendente
- Botão falar com consultor via WhatsApp
- Lead salvo no Firestore

### Fluxo do agente (PARCIALMENTE FUNCIONANDO)
- Login com email e senha — Firebase Auth
- Painel com link personalizado — copiar funcionando
- Upload de foto — funcionando
- Cadastro de nome, bio, WhatsApp — funcionando
- Lista de leads recebidos — funcionando

### Fluxo do empresário/admin (CONSTRUÍDO, NÃO TESTADO)
- AdminDashboardScreen — criado pelo Cowork
- Criação de agentes com slug personalizado
- Visualização de leads por agente
- REQUER: documento users/{uid} com role:admin e companyId no Firestore

### Infraestrutura
- Firebase Hosting — hitlook-app.web.app
- Firebase Auth — email/senha ativo
- Firestore — regras configuradas
- Firebase Storage — fotos dos agentes
- GitHub — diegomontime-arch/livelong
- go_router — roteamento configurado

## O que NÃO está funcionando

### Crítico
- Ana (IA) — CORS bloqueia chamadas diretas para Anthropic no browser
- Renan não tem acesso ao painel admin — falta documento no Firestore
- Foto do agente no link do cliente — não confirmado ainda

### Importante
- Stripe — não implementado
- WhatsApp com mensagem pré-preenchida — botão existe mas sem número real
- Open Graph por agente — genérico M4LIFE para todos

### Dívida técnica
- Dois schemas de leads paralelos — leads raiz (legado) e companies/.../leads (SaaS)
- agentId pode ser UID ou slug — inconsistência no dashboard
- chat_screen.dart — API key local, fora do git
- Logs de debug ainda ativos — public_lead_agent_id_log.dart

## Dois schemas paralelos — DECISÃO PENDENTE
O Cowork criou estrutura SaaS nova em paralelo ao legado.
Legado: agents/{uid}, leads raiz com agentId
SaaS novo: companies/{id}/sellers/{id}, seller_slugs, users/{uid}
DECISÃO NECESSÁRIA: unificar em um schema só antes de lançar
