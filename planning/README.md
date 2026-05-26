# Live Long / HitLook — Planning

Pasta operacional de planejamento e produção. Inspirada no padrão `planning/` do
projeto Whenote (OpenWhen), serve como **fonte da verdade** para o que falta
para colocar o app pronto para o primeiro release na **Apple App Store**.

A pasta `docs/` (existente) continua sendo a documentação **estratégica**
(visão, modelo de negócio, schema Firestore, etc.). Esta pasta `planning/` é
**operacional**: checklists, auditorias, riscos, troubleshooting.

---

## Índice

| Documento | Para quê |
|-----------|----------|
| [CHECKLIST.md](CHECKLIST.md) | **Master execution checklist** — visão única navegável com IDs estáveis (A1…E7). **Comece aqui se for executar.** |
| [PRODUCTION.md](PRODUCTION.md) | Checklist geral por fases (A → H) para chegar à App Store. Comece aqui se for entender o panorama. |
| [APPLE_RELEASE.md](APPLE_RELEASE.md) | Específico do iOS / Apple — Info.plist, ATT, App Privacy, Sign in with Apple, TestFlight, App Review. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Auditoria de arquitetura Flutter — pontos fortes, dívidas, sugestões inspiradas no Whenote. |
| [FIRESTORE_AUDIT.md](FIRESTORE_AUDIT.md) | Auditoria de queries Firestore — anti-patterns, índices, custos. Lições do refactor de busca de usuários do Whenote. |
| [SECURITY.md](SECURITY.md) | Análise de `firestore.rules`, `storage.rules`, App Check, secrets, OWASP MASVS. |
| [FUNCTIONS_AUDIT.md](FUNCTIONS_AUDIT.md) | Auditoria das Cloud Functions (`anthropicProxy`, `createSellerAccount`, `notifyAgentOnNewLead`). |
| [LEGAL.md](LEGAL.md) | Análise jurídica — CCPA/CPRA, Florida DFS, NAIC, estrutura de Privacy Policy + Terms of Use. **Não substitui advogado**, mas mapeia o terreno. |
| [RISKS.md](RISKS.md) | Mapa de riscos que podem **bloquear o release** (regulatório, segurança, custos). |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Problemas conhecidos e como diagnosticar — formato Whenote. |
| [CHANGELOG.md](CHANGELOG.md) | Diário de mudanças relevantes — começa em maio/2026. |

---

## Convenções

- Linhas de código referenciadas como `lib/foo/bar.dart:42`.
- Decisões com impacto de produção sempre com **data absoluta** (`2026-05-23`), nunca relativa ("ontem").
- Itens críticos no formato `**CRÍTICO:**` no início da frase.
- Quando um item depende de decisão humana de Diego, marcar `🟡 DECISÃO PENDENTE`.

---

## Como usar antes do release

1. Ler [PRODUCTION.md §0](PRODUCTION.md) — `tl;dr` do estado atual.
2. Atacar a fase A (identidade / build) — bloqueante para qualquer submissão.
3. Resolver os 🟡 listados em [RISKS.md](RISKS.md) com Diego e/ou advogado.
4. Validar tudo da fase G (QA dispositivo real) antes de subir build para
   TestFlight.

---

*Criado em 2026-05-23 com base em auditoria completa do repositório `livelong`.
Inspirado no `planning/` do projeto Whenote (mesmos donos: Yuri e Diego).*
