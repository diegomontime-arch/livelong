# 08 — Briefing para Claude / Cowork / Cursor / GPT

Use este documento ao iniciar qualquer sessão de trabalho no HitLook.

## O que é o HitLook
Plataforma SaaS Flutter para qualificação de leads com IA voltada para vendedores latinos nos EUA.
Tenant piloto: M4LIFE USA (empresa de seguros de vida do Renan).
App no ar: https://hitlook-app.web.app
GitHub: https://github.com/diegomontime-arch/livelong
Pasta local: ~/Documents/livelong
Firebase projeto: hitlook-app

## Como funciona
1. Empresário (Renan) cria agentes no painel admin (/admin)
2. Cada agente recebe link personalizado /a/slug-do-agente
3. Agente manda link no WhatsApp para prospects
4. Prospect abre link, vê foto do agente, faz diagnóstico em PT/ES/EN
5. IA qualifica o prospect e gera score de proteção familiar
6. Prospect clica em WhatsApp do agente com mensagem pré-preenchida
7. Lead aparece no painel do agente e do empresário

## Hierarquia
Diego → dono HitLook (acesso total)
Renan → empresário M4LIFE (role:admin, vê agentes e leads da empresa)
Agente → vendedor (vê só próprios leads)
Prospect → não tem conta

## Stack
Flutter 3.41+ / Dart 3.11+
Firebase (Auth, Firestore, Storage, Hosting)
go_router para roteamento
Anthropic Claude API (claude-sonnet-4-20250514)

## Arquivos importantes
Telas reais: lib/legacy/screens/
Router: lib/core/routing/app_router.dart
Rotas: lib/core/constants/route_paths.dart
Admin: lib/legacy/admin/
Tema/cores: lib/legacy/screens/language_screen.dart (AppColors)
Chat IA: lib/legacy/screens/chat_screen.dart (FORA DO GIT — tem API key)

## Rotas
/ → cliente sem agente
/a/:sellerSlug → cliente com perfil do agente
/login → login
/dashboard → painel do agente
/perfil → editar perfil
/admin → painel do empresário (role:admin)
/admin/sellers/:sellerId → leads por agente

## Firestore — dois schemas paralelos (problema pendente)
LEGADO: agents/{uid}, leads (coleção raiz)
SAAS: users/{uid}, companies/{id}/sellers/{id}, seller_slugs/{slug}

## Visual
Preto puro + dourado #D4AF37
Coruja geométrica dourada = assinatura do Diego (aparece em todos os projetos)
Layout desktop duas colunas, mobile uma coluna

## Regra de ouro
Toda modificação → flutter build web --release && firebase deploy --only hosting && git add . && git commit -m "descrição" && git push

## Próximas prioridades (ver 05-CHECKLIST.md)
1. Confirmar foto do agente aparecendo no link do cliente
2. Dar acesso admin ao Renan no Firestore
3. Resolver Ana (IA) — CORS via Cloudflare Worker
4. WhatsApp com mensagem pré-preenchida
5. Stripe pagamento

## Ícones e branding por tenant (multi-tenant)

- Ícones web/PWA são gerados a partir de `assets/tenants/{companyId}/logo.jpg` (ou `.png`).
- Tenant ativo hoje: **m4life** (M4LIFE USA).
- Futuro: `companies/{companyId}.iconUrl` no Firestore; por ora o build usa a pasta local.

Para nova empresa:

1. Adicionar `assets/tenants/{companyId}/logo.jpg`
2. Rodar `python3 scripts/generate_web_icons.py --tenant={companyId}`
3. Ajustar `web/manifest.json` e `web/index.html` se necessário
4. `./save.sh` + deploy

## O que NÃO fazer
- Não criar nova estrutura sem alinhar com o time
- Não subir chat_screen.dart para o git (tem API key)
- Não misturar schema legado com SaaS sem decisão tomada
- Não adicionar features novas antes de validar o fluxo atual
- Sempre fazer build + deploy + git após qualquer mudança
