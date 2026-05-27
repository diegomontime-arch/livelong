# 05 — Checklist Operacional (atualizado 26/05/2026)

## CONCLUÍDO

- [x] Fluxo do cliente completo — idioma, onboarding, perguntas, resultado
- [x] Layout responsivo — desktop duas colunas, mobile uma coluna
- [x] Três idiomas — PT, ES, EN
- [x] Score animado de proteção familiar
- [x] Calculadora familiar interativa
- [x] Cards de Benefício em Vida no resultado
- [x] Botão voltar em todas as telas
- [x] Máscara automática na data de nascimento e telefone
- [x] Tela 404 para link inválido
- [x] Loading states em todas as telas
- [x] Splash HitLook nas rotas públicas
- [x] Ana respondendo via Cloudflare Worker
- [x] Login Diego e Renan funcionando
- [x] Painel master Diego com logo HitLook
- [x] Painel admin Renan com cards de agentes
- [x] Criar agente pelo painel admin
- [x] Status do lead editável
- [x] Leads salvando em duas coleções
- [x] Foto e nome do agente no link público
- [x] Foto salvando no Storage e persistindo
- [x] WhatsApp com perfil completo do prospect
- [x] Guia de abordagem no painel do agente
- [x] Mensagem WhatsApp com M4LIFE branding
- [x] Leads aparecendo no dashboard sem tela branca
- [x] Recuperação de senha funcionando
- [x] Cadastro público bloqueado
- [x] Ícones HitLook no app
- [x] Open Graph configurado
- [x] Proteção financeira — alertas Google Cloud e Anthropic
- [x] Auditoria de segurança completa
- [x] chat_screen.dart fora do git
- [x] Script create_agents_m4life.js
- [x] Yuri Lima adicionado no GitHub

---

## PRIORIDADE MÁXIMA — Antes do segundo tenant

- [ ] **Stripe** — pagamento $27/mês por agente
- [ ] **Firestore rules** — isolamento multi-tenant revisado
- [ ] **Firestore indexes** — performance com volume real
- [ ] **LGPD básico** — aviso de privacidade e aceite no formulário
- [ ] **CSV export** — exportar leads por agente

---

## IMPORTANTE — Antes de 5 clientes pagando

- [ ] Notificações email quando lead chega
- [ ] Analytics do funil — abertura, conclusão, conversão
- [ ] Admin panel completo — métricas e gestão
- [ ] Open Graph dinâmico por agente
- [ ] Senha do Renan trocar de 123456
- [ ] Portobello America — segundo tenant

---

## BACKLOG — Com 20+ clientes

- [ ] App nativo iOS/Android
- [ ] Push notifications via FCM
- [ ] White-label completo com subdomínio
- [ ] API pública com webhooks
- [ ] Marketplace de templates por nicho

---

## Regras
1. Toda semana revisar e marcar o que foi feito
2. Máximo 5 itens ativos por semana
3. Toda modificação usar ./save.sh "descrição"
4. Nunca subir chat_screen.dart para o git
5. Sempre git pull antes de começar
