# 09 — Visão da Plataforma Matrix (HitLook)

## O que é a Matrix

HitLook é o nome do produto. Matrix é o conceito — o motor invisível que sustenta tudo por baixo.

Cada empresa que usa o HitLook é um tenant dentro da Matrix. O cliente final nunca vê o HitLook. Ele vê a marca da empresa — M4LIFE, Portobello, futura empresa X.

## Hierarquia completa

Diego (dono da Matrix/HitLook)
├── M4LIFE USA (Renan — tenant 1)
│   ├── Agente Carlos → link /a/carlos
│   ├── Agente Maria → link /a/maria
│   └── Agente João → link /a/joao
├── Portobello America (esposa — tenant 2)
│   ├── Vendedor 1 → link /a/vendedor1
│   └── Vendedor 2 → link /a/vendedor2
└── Empresa X (futuro tenant 3)

## Como funciona para cada tipo de usuário

### Diego — dono da plataforma
- Acessa painel master do HitLook
- Vê todas as empresas ativas
- Vê receita total, leads gerados, uso de IA
- Cria novas empresas manualmente hoje, self-service no futuro
- Nunca aparece para o cliente final

### Empresário (Renan, esposa, etc)
- Acessa painel da própria empresa
- Cria e gerencia agentes do time
- Vê leads por agente
- Monitora performance de cada agente
- Gera links personalizados para cada agente
- Paga $27/mês por agente

### Agente (vendedor)
- Acessa painel próprio
- Vê só os próprios leads
- Configura foto e perfil
- Copia link personalizado
- Manda link no WhatsApp para prospects

### Prospect (cliente final)
- Não tem conta
- Abre link no celular — vê foto do agente
- Faz diagnóstico em PT/ES/EN
- Recebe score e plano educacional
- Clica para falar com o agente via WhatsApp

## Como adicionar novas empresas

### Hoje (manual)
1. Empresa assina e paga
2. Diego cria documento em companies/{id} no Firestore
3. Diego cria usuário admin da empresa no Firebase Auth
4. Diego configura users/{uid} com role:admin e companyId
5. Empresário faz login e cria os agentes

### Futuro (self-service)
1. Empresa entra em hitlook.app
2. Preenche dados da empresa
3. Paga via Stripe
4. Sistema cria tudo automaticamente
5. Empresário já acessa o painel na hora

### Fase final (app)
1. HitLook vira app na App Store e Google Play
2. Qualquer pessoa baixa e cria sua empresa
3. Completamente self-service
4. Diego só monitora e recebe

## Estrutura de domínios

Fase 1 — agora: hitlook-app.web.app/a/nome-agente
Fase 2 — com 5+ clientes: hitlook.app/a/nome-agente e m4life.hitlook.app
Fase 3 — enterprise: m4lifeusa.com aponta para HitLook

## Expansão por nicho

O motor é o mesmo. O que muda é a configuração.

Seguro de vida → M4LIFE USA → Ana
Pisos → Portobello America → assistente de design
Solar → empresa solar → consultor solar
Mortgage → corretora → consultor financeiro
Imigração → escritório jurídico → assistente jurídico

## Receita projetada

1 empresa, 10 agentes → $270/mês
5 empresas, 10 agentes cada → $1,350/mês
20 empresas, 10 agentes cada → $5,400/mês
100 empresas, 10 agentes cada → $27,000/mês
Custo de infraestrutura nesse volume: ~$500/mês
Margem: 98%

## O número 44

O 44 é a marca pessoal do Diego — símbolo de virada de vida. A coruja geométrica dourada é a assinatura visual em todos os projetos do Diego. Aparece discreta em todas as telas do HitLook.

## Frase central do produto

Seu vendedor manda um link. O cliente responde. A IA qualifica. O vendedor recebe pronto para fechar.
