# 03 — Arquitetura Técnica

## Stack
- Flutter 3.41+ / Dart 3.11+
- Firebase (Auth, Firestore, Storage, Hosting)
- go_router para roteamento
- Anthropic Claude API (claude-sonnet-4-20250514)
- GitHub: diegomontime-arch/livelong

## Estrutura de pastas
lib/
├── main.dart              — bootstrap
├── app.dart               — MaterialApp.router
├── firebase_options.dart  — config Firebase
├── core/
│   ├── config/            — AppConfig, TenantConfig
│   ├── constants/         — RoutePaths, FirestorePaths
│   ├── routing/           — app_router.dart, route_guards.dart
│   ├── theme/             — AppColors
│   └── utils/             — Result<T>
├── data/
│   ├── models/            — Tenant, Company, Seller, Lead, User
│   └── repositories/      — Firebase implementations
├── services/
│   └── firebase/          — Auth, Firestore, Storage wrappers
└── legacy/
    └── screens/           — TELAS REAIS EM USO
        ├── language_screen.dart      — seleção idioma + welcome + onboarding
        ├── questions_screen.dart     — 5 perguntas
        ├── result_screen.dart        — score + plano + calculadora
        ├── chat_screen.dart          — Ana (fora do git — tem API key)
        ├── agent_profile.dart        — modelo AgentProfile + AgentProvider
        ├── agent_login_screen.dart   — login do agente
        ├── agent_setup_screen.dart   — perfil + foto do agente
        ├── agent_dashboard_screen.dart — painel do agente
        ├── admin_dashboard_screen.dart — painel do empresário (Renan)
        └── admin_seller_leads_screen.dart — leads por agente

## Rotas
/ → tela do cliente (idioma)
/a/:sellerSlug → tela do cliente com perfil do agente
/login → login do agente/empresário
/dashboard → painel do agente
/perfil → editar perfil do agente
/admin → painel do empresário (requer role:admin)
/admin/sellers/:sellerId → leads de um agente específico

## Hierarquia de usuários
Diego (dono HitLook) — acesso total
Renan (empresário M4LIFE) — role:admin, vê agentes e leads da empresa
Agente — role:seller, vê só próprios leads
Prospect — não tem conta, só usa o link

## Firestore — Schema atual (dois paralelos)
### Legado (em uso no fluxo público)
agents/{uid} — nome, bio, whatsapp, fotoUrl, userId, slug
leads — coleção raiz — agentId, nome, telefone, score, status

### SaaS novo (admin)
users/{uid} — role, companyId, sellerId, email
companies/{companyId} — dados da empresa
companies/{companyId}/sellers/{sellerId} — displayName, slug, photoUrl
seller_slugs/{slug} — companyId, sellerId
companies/{companyId}/leads/{leadId} — schema novo

## AppColors (preto e dourado M4LIFE)
black = 0xFF000000
blackCard = 0xFF0D0D0D
gold = 0xFFD4AF37
goldDim = 0xFF8B7420
white = 0xFFFFFFFF
whiteWarm = 0xFFF5F0EB
grey = 0xFF555555
greyLight = 0xFF888888

## Visual
- Fundo preto puro
- Dourado como acento — botões, ícones, destaques
- Marca dágua M4LIFE sutil no fundo
- Coruja geométrica dourada no canto inferior direito (assinatura Diego)
- Indicador AI pulsando no canto superior direito
- Layout desktop: duas colunas — pitch esquerda, form direita
- Layout mobile: uma coluna com scroll
