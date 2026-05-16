# 05 — Checklist Operacional

_Abrir toda segunda. Marcar o que terminou. Mover concluídos pro fim do mês._

---

## Esta semana (15-22 maio 2026)

### Vendas (PRIORIDADE MÁXIMA — fazer ANTES de qualquer feature)
- [ ] Marcar reunião 30min com Renan
- [ ] Levar proposta escrita: 5 agentes piloto, $47/mês locked-for-life, garantia 30d
- [ ] Pedir os 5 nomes dos agentes mais ativos da M4LIFE
- [ ] Definir métrica de sucesso do piloto

### Técnico — desbloquear o que está parado
- [ ] `flutter run -d chrome` e validar agent_setup_screen
- [ ] Corrigir erros de compilação
- [ ] Conectar agent_setup ao fluxo de navegação
- [ ] Build + deploy no Firebase Hosting
- [ ] Testar fluxo completo no celular (Safari + Chrome mobile)

### Risco — endereçar antes que vire problema
- [ ] Disclaimer em todas as telas: "Ferramenta educacional. Não fornece aconselhamento de seguros."
- [ ] Pesquisar 3 advogados de insurance regulation na Flórida
- [ ] Marcar consulta de 1h com um deles

---

## Próximas 2 semanas

### Técnico
- [ ] Login agente (Firebase Auth, email+senha)
- [ ] Sessão persistente
- [ ] Painel: lista de leads
- [ ] Detalhe do lead (perfil + respostas + chat Ana)
- [ ] Botão "Abrir WhatsApp" pré-preenchido
- [ ] Rota `/a/[agent_id]` que carrega config
- [ ] Open Graph dinâmico
- [ ] **API key Anthropic em variável de ambiente — NUNCA no código**

### Negócio
- [ ] Cartão dos 5 agentes no Stripe (mesmo que de graça os 30 dias iniciais)
- [ ] Stripe Checkout setup
- [ ] Webhook de assinatura
- [ ] Onboarding call de 1h com os 5 agentes

### Métricas
- [ ] Firebase Analytics ativo
- [ ] Eventos: link_enviado, link_aberto, p1..p5, whatsapp_clicado
- [ ] Dashboard simples (Looker Studio ou Sheets)

---

## Backlog

### Curto prazo (mês 2-3)
- [ ] Customização da página do agente (depoimentos, vídeo)
- [ ] Notificações push/email ao agente
- [ ] Status do lead (novo/contatado/fechado/perdido)
- [ ] Calendly embedded
- [ ] Tela de billing no app
- [ ] Bloqueio se assinatura inativa

### Médio prazo (mês 4-6)
- [ ] Multi-tenant LEVE
- [ ] Painel admin do Renan
- [ ] PWA com instalação no celular
- [ ] Versão em espanhol revisada por nativo
- [ ] Termos e privacidade revistos por advogado

### Longo prazo (mês 6+)
- [ ] Multi-tenant completo
- [ ] Nova vertical (escolher UMA)
- [ ] App nativo
- [ ] Integração com CRMs

---

## Regras

1. Nada novo entra sem mover algo antigo pra concluído ou removido
2. Tarefa parada 4 semanas vai embora
3. Sexta à noite: revisar e atualizar
4. Mais de 5 itens em "esta semana" = nenhum vai entregar. Corte.
