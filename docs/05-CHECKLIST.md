# 05 — Checklist Operacional (atualizado 19/05/2026)

## CONCLUÍDO

- [x] Fluxo do cliente completo — idioma, onboarding, perguntas, resultado
- [x] Layout responsivo — desktop duas colunas, mobile uma coluna
- [x] Três idiomas — PT, ES, EN
- [x] Score animado de proteção familiar
- [x] Calculadora familiar interativa
- [x] Cards de Benefício em Vida no resultado
- [x] Botão voltar em todas as telas
- [x] Máscara automática na data de nascimento MM/DD/AAAA
- [x] Tela 404 para link inválido
- [x] Loading states em todas as telas
- [x] Pull to refresh no painel
- [x] Paginação de leads
- [x] Empty state no painel
- [x] Data formatada nos leads
- [x] Esqueceu a senha corrigido
- [x] Firebase Hosting — hitlook-app.web.app
- [x] Firebase Auth — email/senha
- [x] Firestore — regras configuradas
- [x] Firebase Storage — fotos dos agentes
- [x] GitHub — diegomontime-arch/livelong
- [x] go_router — roteamento completo
- [x] Documentação completa em docs/
- [x] AdminDashboardScreen — painel do empresário
- [x] Criação de agentes pelo admin
- [x] Visualização de leads por agente
- [x] Leads duplos — `leads` raiz + `companies/{id}/leads`
- [x] WhatsApp com mensagem pré-preenchida (Safari iOS)
- [x] Login Safari iPhone — botão ENTRAR + toques
- [x] Painel master Diego — lista empresas + M4LIFE card
- [x] Rotas públicas com usuário logado (`/a/:slug`)
- [x] Cadastro público bloqueado — só admin cria agentes
- [x] Foto agente — persistência + link público (auditoria 19/05/2026)

## PRIORIDADE MÁXIMA — Próxima sessão

- [ ] Validar foto Diego em `/a/diego-teste` após salvar em produção
- [ ] Resolver Ana via Cloudflare Worker (teste end-to-end)
- [ ] Email ao novo lead (Trigger Email extension)
- [ ] Open Graph dinâmico por agente

## IMPORTANTE — Antes do lançamento

- [ ] Stripe pagamento $27 por agente
- [ ] Renan testa com 5 agentes piloto
- [ ] Consulta jurídica advogado insurance regulation FL
- [ ] Página de vendas do HitLook

## BACKLOG — Depois do piloto

- [ ] Analytics funil completo
- [ ] Portobello America segundo tenant
- [ ] Self-service onboarding para novas empresas
- [ ] App nativo iOS e Android
- [ ] Plano Equipe $149 por mês

## Auditoria SaaS (19/05/2026)

| Área | Status |
|------|--------|
| Prospect — splash, score, calculadora, leads duplos, WhatsApp | OK |
| Agente — login, dashboard, perfil+foto, status lead | OK (validar foto em prod) |
| Admin Renan — M4LIFE, criar agente, leads | OK |
| Master Diego — empresas, drill-down M4LIFE | OK |
| Segurança — rotas, rules, sem signup público | OK |
| Ana IA | Depende Worker + `chat_screen.dart` local |
| API key Anthropic | Só no Worker (não no git) |

## Regras

1. Toda semana revisar e marcar o que foi feito
2. Máximo 5 itens ativos por semana
3. Toda modificação usar `./save.sh "descrição"`
4. Nunca subir `chat_screen.dart` para o git
5. Sempre `git pull` antes de começar
