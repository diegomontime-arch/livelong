# 02 — Status Atual

_Última atualização: 15/05/2026_

## Pronto e no ar

- Splash HitLook (lib/main.dart)
- Seleção de idioma PT/ES/EN (lib/language_screen.dart)
- Onboarding (nome, telefone, nascimento)
- 5 perguntas (lib/questions_screen.dart)
- Score animado + plano recomendado (lib/result_screen.dart)
- Calculadora familiar
- Chat com Ana (lib/chat_screen.dart)
- Firebase: Firestore, Auth, Storage, Hosting ativos
- Storage rules criadas
- GitHub: diegomontime-arch/livelong
- Deploy: hitlook-app.web.app

## Em construção

- agent_setup_screen.dart — escrito, **não testado**
- AgentProfile + AgentProvider (agent_profile.dart)

## Pendente

**Bloco 1 — desbloquear (esta semana)**
- [ ] `flutter run -d chrome` e validar
- [ ] Corrigir erros de compilação
- [ ] Conectar agent_setup ao fluxo
- [ ] Build + deploy

**Bloco 2 — auth (próximos 3 dias)**
- [ ] Login Firebase Auth
- [ ] Sessão persistente
- [ ] Roteamento agente vs prospect
- [ ] Logout

**Bloco 3 — painel (próximos 7 dias)**
- [ ] Lista de leads
- [ ] Status (novo/contatado/fechado/perdido)
- [ ] Detalhe do lead
- [ ] Botão WhatsApp

**Bloco 4 — distribuição (próximos 7 dias)**
- [ ] Rota /a/[id]
- [ ] Open Graph dinâmico
- [ ] Compartilhamento nativo

**Bloco 5 — receita (próximos 14 dias)**
- [ ] Stripe Checkout
- [ ] Webhook
- [ ] Tela de billing
- [ ] Bloqueio se inativo

**Bloco 6 — operação (paralelo)**
- [ ] API key Anthropic em variável de ambiente (NÃO no código)
- [ ] Rate limit no chat Ana
- [ ] Firebase Analytics ativo
- [ ] Termos de uso + privacidade
- [ ] Disclaimer "não é aconselhamento"

## Métricas a medir AGORA

Funil completo:
- Links enviados (por agente, por dia)
- Links abertos
- Perguntas completadas
- Cliques no botão WhatsApp
- Reportados como fechados pelo agente

Sem isso, otimização é chute.
