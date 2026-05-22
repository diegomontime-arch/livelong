import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hitlook/core/utils/whatsapp_utils.dart';
import 'package:hitlook/legacy/admin/agent_profile_photo.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

// ─── MODELO DO AGENTE ────────────────────────────────────
class AgentProfile {
  final String id;
  final String nome;
  final String bio;
  final String whatsapp;
  final String fotoUrl;
  final String idioma;
  final String nicho;
  final String? displayName;
  final String? userId;
  final String? companyId;
  final String? sellerId;

  const AgentProfile({
    required this.id,
    required this.nome,
    required this.bio,
    required this.whatsapp,
    required this.fotoUrl,
    required this.idioma,
    required this.nicho,
    this.displayName,
    this.userId,
    this.companyId,
    this.sellerId,
  });

  /// Best label for UI — never company branding.
  String get resolvedNome {
    final n = nome.trim();
    if (n.isNotEmpty && n != AgentProfile.defaultProfile.nome) return n;
    final d = displayName?.trim() ?? '';
    if (d.isNotEmpty) return d;
    return n;
  }

  bool get hasSaaSContext =>
      companyId != null &&
      companyId!.isNotEmpty &&
      sellerId != null &&
      sellerId!.isNotEmpty;

  factory AgentProfile.fromMap(String id, Map<String, dynamic> map) {
    final display = map['displayName'] as String?;
    final nome = map['nome'] as String? ?? display ?? '';
    return AgentProfile(
      id: id,
      nome: nome,
      displayName: display ?? (nome.isNotEmpty ? nome : null),
      bio: map['bio'] as String? ?? '',
      whatsapp: map['whatsapp'] as String? ??
          map['phone'] as String? ??
          '',
      fotoUrl: map['fotoUrl'] as String? ?? map['photoUrl'] as String? ?? '',
      idioma: map['idioma'] as String? ?? 'pt',
      nicho: map['nicho'] as String? ?? 'seguro',
      userId: map['userId'] as String?,
      companyId: map['companyId'] as String?,
      sellerId: map['sellerId'] as String?,
    );
  }

  factory AgentProfile.fromSeller(
    String slug,
    Map<String, dynamic> seller, {
    String? companyId,
    String? sellerId,
  }) {
    final display = seller['displayName'] as String?;
    final nome =
        display ?? seller['nome'] as String? ?? '';
    return AgentProfile(
      id: slug,
      nome: nome,
      displayName: display ?? (nome.isNotEmpty ? nome : null),
      bio: seller['bio'] as String? ?? '',
      whatsapp: seller['phone'] as String? ??
          seller['whatsapp'] as String? ??
          '',
      fotoUrl: seller['photoUrl'] as String? ?? seller['fotoUrl'] as String? ?? '',
      idioma: seller['idioma'] as String? ?? 'pt',
      nicho: seller['nicho'] as String? ?? 'seguro',
      userId: seller['userId'] as String?,
      companyId: companyId ?? seller['companyId'] as String?,
      sellerId: sellerId ?? seller['sellerId'] as String?,
    );
  }

  static const AgentProfile defaultProfile = AgentProfile(
    id: 'default',
    nome: 'M4LIFE USA',
    bio: 'Especialistas em proteção familiar para a comunidade latina.',
    whatsapp: '',
    fotoUrl: '',
    idioma: 'pt',
    nicho: 'seguro',
    companyId: null,
    sellerId: null,
  );
}

// ─── PROVIDER DO AGENTE ──────────────────────────────────
///
/// Resolução pública em 3 passos (ver docs/11-SCHEMA-DEFINITIVO.md §5).
class AgentProvider {
  static final _db = FirebaseFirestore.instance;

  static const _brandNome = 'M4LIFE USA';

  /// Firebase Auth UIDs are typically 28 characters, alphanumeric only.
  static bool looksLikeFirebaseUid(String id) =>
      id.length >= 20 && RegExp(r'^[A-Za-z0-9]+$').hasMatch(id);

  static bool isPublicSlug(String id) =>
      id.isNotEmpty && id != 'default' && !looksLikeFirebaseUid(id);

  /// Public URL segment for `/a/{id}` — prefers seller slug over Firebase UID.
  static Future<String> resolvePublicLinkId(String uid) async {
    if (uid.isEmpty) return uid;
    try {
      final agentDoc = await _db.collection('agents').doc(uid).get();
      final slug = agentDoc.data()?['slug'] as String?;
      if (slug != null && slug.isNotEmpty) return slug;

      final userSnap = await _db.collection('users').doc(uid).get();
      final companyId = userSnap.data()?['companyId'] as String?;
      final sellerId = userSnap.data()?['sellerId'] as String?;
      if (companyId != null && sellerId != null) {
        final sellerSnap = await _db
            .collection('companies')
            .doc(companyId)
            .collection('sellers')
            .doc(sellerId)
            .get();
        final sellerSlug = sellerSnap.data()?['slug'] as String?;
        if (sellerSlug != null && sellerSlug.isNotEmpty) return sellerSlug;
      }
    } catch (e) {
      debugPrint('[HitLook:Agent] resolvePublicLinkId: $e');
    }
    return uid;
  }

  /// Resolves slug or UID → Firebase Auth UID (para gravar leads).
  static Future<String> resolveOwnerUid(String agentId) async {
    if (agentId.isEmpty || agentId == 'default') return agentId;
    if (looksLikeFirebaseUid(agentId)) return agentId;

    final profile = await loadAgent(agentId);
    if (profile.userId != null && profile.userId!.isNotEmpty) {
      return profile.userId!;
    }
    return agentId;
  }

  /// Carrega perfil para `/a/{slug}` ou `/a/{uid}`.
  static Future<AgentProfile> loadAgent(String agentId) async {
    if (agentId.isEmpty || agentId == 'default') {
      debugPrint('[HitLook:Agent] loadAgent → rota / (default)');
      return AgentProfile.defaultProfile;
    }

    try {
      if (looksLikeFirebaseUid(agentId)) {
        return _loadByAuthUid(agentId);
      }
      return _loadPublicBySlug(agentId);
    } catch (e, st) {
      debugPrint('[HitLook:Agent] loadAgent ERRO id=$agentId: $e\n$st');
      if (isPublicSlug(agentId)) {
        return _profileFromSlugOnly(agentId);
      }
      return AgentProfile.defaultProfile;
    }
  }

  // ─── Link público: 3 passos ───────────────────────────────

  static Future<AgentProfile> _loadPublicBySlug(String slug) async {
    debugPrint('[HitLook:Agent] ▶ loadAgent("$slug")');

    // PASSO 1 — seller_slugs → companies/.../sellers (fonte da verdade)
    final seller = await _step1LoadSeller(slug);
    if (seller == null) {
      debugPrint('[HitLook:Agent] PASSO 1 falhou — tentando agents/$slug');
      final mirror = await _readAgentsDoc(slug);
      if (mirror != null && _hasRealData(mirror)) {
        return _attachPublicSlug(mirror, slug);
      }
      debugPrint('[HitLook:Agent] ■ fallback slug-only');
      return _profileFromSlugOnly(slug);
    }

    // PASSO 2 — agents/{userId} (fotoUrl, nome legado)
    AgentProfile? legacy;
    final uid = seller.userId?.trim() ?? '';
    if (uid.isNotEmpty) {
      legacy = await _step2LoadAgentsUid(uid);
    } else {
      debugPrint('[HitLook:Agent] PASSO 2 pulado — seller sem userId');
    }

    // PASSO 3 — merge
    final profile = _step3Merge(slug, seller, legacy);
    debugPrint(
      '[HitLook:Agent] ■ OK slug=$slug nome="${profile.nome}" '
      'foto=${profile.fotoUrl.isNotEmpty} userId=${profile.userId}',
    );
    return profile;
  }

  /// PASSO 1: `seller_slugs/{slug}` → documento seller.
  static Future<AgentProfile?> _step1LoadSeller(String slug) async {
    debugPrint('[HitLook:Agent] PASSO 1 seller_slugs/$slug');

    final index = await _db.collection('seller_slugs').doc(slug).get();
    if (!index.exists || index.data() == null) {
      debugPrint('[HitLook:Agent] PASSO 1 índice inexistente');
      return null;
    }

    final companyId = index.data()!['companyId'] as String?;
    final sellerId = index.data()!['sellerId'] as String?;
    debugPrint('[HitLook:Agent] PASSO 1 → companyId=$companyId sellerId=$sellerId');

    if (companyId == null || sellerId == null) return null;

    final sellerDoc = await _db
        .collection('companies')
        .doc(companyId)
        .collection('sellers')
        .doc(sellerId)
        .get();

    if (!sellerDoc.exists || sellerDoc.data() == null) {
      debugPrint('[HitLook:Agent] PASSO 1 seller doc ausente');
      return null;
    }

    final data = sellerDoc.data()!;
    final profile = AgentProfile.fromSeller(
      data['slug'] as String? ?? sellerId,
      data,
      companyId: companyId,
      sellerId: sellerId,
    );

    debugPrint(
      '[HitLook:Agent] PASSO 1 OK displayName="${profile.displayName}" '
      'userId=${profile.userId} photoUrl=${profile.fotoUrl.isNotEmpty}',
    );
    return profile;
  }

  /// PASSO 2: `agents/{uid}` — overrides de foto e nome.
  static Future<AgentProfile?> _step2LoadAgentsUid(String uid) async {
    debugPrint('[HitLook:Agent] PASSO 2 agents/$uid');
    final doc = await _readAgentsDoc(uid);
    if (doc == null) {
      debugPrint('[HitLook:Agent] PASSO 2 doc ausente');
      return null;
    }
    debugPrint(
      '[HitLook:Agent] PASSO 2 OK nome="${doc.nome}" fotoUrl=${doc.fotoUrl.isNotEmpty}',
    );
    return doc;
  }

  /// PASSO 3: merge seller + legacy; `id` = slug da URL.
  static AgentProfile _step3Merge(
    String slug,
    AgentProfile seller,
    AgentProfile? legacy,
  ) {
    debugPrint('[HitLook:Agent] PASSO 3 merge');

    final nome = _firstNonEmptyName([
      legacy?.nome,
      legacy?.displayName,
      seller.nome,
      seller.displayName,
      formatSlugAsDisplayName(slug),
    ]);

    final fotoUrl = _firstNonEmpty([
      legacy?.fotoUrl,
      seller.fotoUrl,
    ]);

    final whatsapp = _firstNonEmpty([
      legacy?.whatsapp,
      seller.whatsapp,
    ]);

    return AgentProfile(
      id: slug,
      nome: nome,
      displayName: seller.displayName ?? legacy?.displayName ?? nome,
      bio: _firstNonEmpty([legacy?.bio, seller.bio]),
      whatsapp: whatsapp,
      fotoUrl: fotoUrl,
      idioma: legacy?.idioma.isNotEmpty == true ? legacy!.idioma : seller.idioma,
      nicho: legacy?.nicho.isNotEmpty == true ? legacy!.nicho : seller.nicho,
      userId: _firstNonEmptyString([seller.userId, legacy?.userId]),
      companyId: seller.companyId,
      sellerId: seller.sellerId,
    );
  }

  // ─── UID na URL ───────────────────────────────────────────

  static Future<AgentProfile> _loadByAuthUid(String uid) async {
    debugPrint('[HitLook:Agent] ▶ loadAgent(uid) $uid');

    final legacy = await _step2LoadAgentsUid(uid);
    final slug =
        (await _db.collection('agents').doc(uid).get()).data()?['slug'] as String?;

    if (slug != null && slug.isNotEmpty && isPublicSlug(slug)) {
      return _loadPublicBySlug(slug);
    }

    if (legacy != null && _hasRealData(legacy)) {
      debugPrint('[HitLook:Agent] ■ OK uid nome="${legacy.nome}"');
      return legacy;
    }

    debugPrint('[HitLook:Agent] ■ uid sem dados — perfil vazio');
    return AgentProfile(
      id: uid,
      nome: '',
      bio: '',
      whatsapp: '',
      fotoUrl: '',
      idioma: 'pt',
      nicho: 'seguro',
      userId: uid,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────

  static Future<AgentProfile?> _readAgentsDoc(String id) async {
    final snap = await _db.collection('agents').doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return AgentProfile.fromMap(id, snap.data()!);
  }

  static bool _hasRealData(AgentProfile p) =>
      p.fotoUrl.trim().isNotEmpty ||
      p.resolvedNome.isNotEmpty && p.resolvedNome != _brandNome ||
      (p.userId != null && p.userId!.isNotEmpty && p.hasSaaSContext);

  static AgentProfile _attachPublicSlug(AgentProfile p, String slug) {
    final nome = _firstNonEmptyName([p.nome, p.displayName, formatSlugAsDisplayName(slug)]);
    return AgentProfile(
      id: slug,
      nome: nome,
      displayName: p.displayName ?? nome,
      bio: p.bio,
      whatsapp: p.whatsapp,
      fotoUrl: p.fotoUrl,
      idioma: p.idioma,
      nicho: p.nicho,
      userId: p.userId,
      companyId: p.companyId,
      sellerId: p.sellerId,
    );
  }

  /// Fallback documentado: só slug, sem Firestore (nunca M4LIFE USA).
  static AgentProfile _profileFromSlugOnly(String slug) {
    final nome = formatSlugAsDisplayName(slug);
    return AgentProfile(
      id: slug,
      nome: nome,
      displayName: nome,
      bio: '',
      whatsapp: '',
      fotoUrl: '',
      idioma: 'pt',
      nicho: 'seguro',
    );
  }

  static String _firstNonEmpty(List<String> values) {
    for (final v in values) {
      final t = v.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static String? _firstNonEmptyString(List<String?> values) {
    for (final v in values) {
      final t = v?.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  static String _firstNonEmptyName(List<String?> values) {
    for (final v in values) {
      final t = v?.trim() ?? '';
      if (t.isNotEmpty && t != _brandNome) return t;
    }
    return '';
  }
}

/// Avatar initials: "M4LIFE USA" → M4, "Renan Sampaio" → RS, "Carlos Silva" → CS.
String agentInitials(String nome) {
  final words =
      nome.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';

  final first = words[0];
  if (RegExp(r'[0-9]').hasMatch(first)) {
    final letters = first.replaceAll(RegExp(r'[^A-Za-z]'), '');
    final numbers = first.replaceAll(RegExp(r'[^0-9]'), '');
    if (letters.isNotEmpty && numbers.isNotEmpty) {
      return '${letters[0].toUpperCase()}${numbers[0]}';
    }
  }

  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

/// "diego-teste" → "Diego Teste"
String formatSlugAsDisplayName(String slug) {
  return slug
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Label do card público — nunca "Consultor" nem "M4LIFE USA" para agente real.
String agentPublicDisplayName(AgentProfile agent, {String? publicSlug}) {
  final slug = _effectivePublicSlug(agent, publicSlug);

  final resolved = agent.resolvedNome;
  if (resolved.isNotEmpty &&
      resolved != AgentProfile.defaultProfile.nome &&
      resolved != AgentProvider._brandNome) {
    return resolved;
  }

  if (slug != null) {
    return formatSlugAsDisplayName(slug);
  }

  if (agent.nome.trim().isNotEmpty && agent.nome.trim() != AgentProvider._brandNome) {
    return agent.nome.trim();
  }

  debugPrint(
    '[HitLook:Agent] displayName fallback vazio '
    '(id=${agent.id} routeSlug=$publicSlug)',
  );
  return 'Agente';
}

String? _effectivePublicSlug(AgentProfile agent, String? publicSlug) {
  for (final candidate in [publicSlug, agent.id]) {
    final s = candidate?.trim() ?? '';
    if (s.isEmpty || s == 'default') continue;
    if (AgentProvider.looksLikeFirebaseUid(s)) continue;
    return s;
  }
  return null;
}

// ─── CARD DO AGENTE NA PÁGINA DO CLIENTE ─────────────────
class AgentCard extends StatelessWidget {
  final AgentProfile agent;
  /// URL slug from `/a/:slug` — used when [agent.id] is a Firebase UID.
  final String? publicSlug;

  const AgentCard({super.key, required this.agent, this.publicSlug});

  String? _slugFromRoute(BuildContext context) {
    final fromRoute = GoRouterState.of(context).pathParameters['sellerSlug'];
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    return publicSlug;
  }

  @override
  Widget build(BuildContext context) {
    final routeSlug = _slugFromRoute(context);
    final displayName = agentPublicDisplayName(agent, publicSlug: routeSlug);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          AgentProfilePhoto(
            displayName: displayName,
            storageUid: agent.userId,
            photoUrl: agent.fotoUrl.isNotEmpty ? agent.fotoUrl : null,
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  agent.bio,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.greyLight,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (agent.whatsapp.isNotEmpty)
            GestureDetector(
              onTap: () => openWhatsApp(
                phone: agent.whatsapp,
                message: 'Olá!',
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF25D366).withOpacity(0.4),
                  ),
                ),
                child: const Icon(
                  Icons.chat_outlined,
                  size: 16,
                  color: Color(0xFF25D366),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
