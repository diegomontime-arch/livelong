import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
class AgentProvider {
  static final _db = FirebaseFirestore.instance;

  /// Firebase Auth UIDs are typically 28 characters.
  static bool looksLikeFirebaseUid(String id) =>
      id.length >= 20 && RegExp(r'^[A-Za-z0-9]+$').hasMatch(id);

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

  /// Resolves public link id (slug or UID) to the owner's Auth UID for leads.
  static Future<String> resolveOwnerUid(String agentId) async {
    if (agentId.isEmpty || agentId == 'default') return agentId;
    if (looksLikeFirebaseUid(agentId)) return agentId;

    final profile = await loadAgent(agentId);
    if (profile.userId != null && profile.userId!.isNotEmpty) {
      return profile.userId!;
    }
    if (looksLikeFirebaseUid(profile.id)) return profile.id;

    final slugDoc = await _db.collection('seller_slugs').doc(agentId).get();
    if (slugDoc.exists) {
      final seller = await _loadSellerFromSlugData(slugDoc.data() ?? {});
      if (seller?.userId != null && seller!.userId!.isNotEmpty) {
        return seller.userId!;
      }
    }

    final agentsDoc = await _db.collection('agents').doc(agentId).get();
    final uid = agentsDoc.data()?['userId'] as String?;
    if (uid != null && uid.isNotEmpty) return uid;

    return agentId;
  }

  /// Loads the public seller profile for [agentId] (Firebase UID or public slug).
  static Future<AgentProfile> loadAgent(String agentId) async {
    if (agentId.isEmpty || agentId == 'default') {
      debugPrint('[HitLook:Agent] loadAgent → default (empty id)');
      return AgentProfile.defaultProfile;
    }

    try {
      debugPrint('[HitLook:Agent] ═══ loadAgent("$agentId") ═══');

      if (looksLikeFirebaseUid(agentId)) {
        final profile = await _loadByUid(agentId);
        return _finalizeProfile(profile, agentId);
      }

      final profile = await _loadByPublicSlug(agentId);
      return _finalizeProfile(profile, agentId);
    } catch (e, st) {
      debugPrint('[HitLook:Agent] loadAgent FAILED slug=$agentId: $e\n$st');
      return AgentProfile.defaultProfile;
    }
  }

  static Future<AgentProfile> _loadByUid(String uid) async {
    final profiles = <AgentProfile>[];

    final direct = await _loadAgentsDoc(uid);
    if (direct != null) profiles.add(direct);

    final uidSnap = await _db
        .collection('agents')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final slug = uidSnap.data()?['slug'] as String?;
    if (slug != null && slug.isNotEmpty && slug != uid) {
      final fromSlug = await _loadByPublicSlug(slug);
      profiles.add(fromSlug);
      debugPrint(
        '[HitLook:Agent] uid→slug/$slug nome="${fromSlug.nome}"',
      );
      return _mergeAll(profiles);
    }

    try {
      final viaUser = await _loadViaUserId(uid);
      if (viaUser != null) profiles.add(viaUser);
    } catch (e) {
      debugPrint('[HitLook:Agent] viaUser skipped: $e');
    }

    return _mergeAll(profiles);
  }

  /// seller_slugs/{slug} → companies/.../sellers → agents/{userId} + agents/{slug}
  static Future<AgentProfile> _loadByPublicSlug(String slug) async {
    debugPrint('[HitLook:Agent] (1/5) seller_slugs/$slug');

    final slugSnap = await _getDoc(_db.collection('seller_slugs').doc(slug));
    debugPrint(
      '[HitLook:Agent] (1/5) exists=${slugSnap.exists} data=${slugSnap.data()}',
    );

    if (!slugSnap.exists || slugSnap.data() == null) {
      debugPrint('[HitLook:Agent] (1/5) miss — fallback agents/$slug only');
      final mirror = await _loadAgentsDoc(slug);
      return mirror ?? AgentProfile.defaultProfile;
    }

    final slugData = slugSnap.data()!;
    final companyId = slugData['companyId'] as String?;
    final sellerId = slugData['sellerId'] as String?;
    debugPrint(
      '[HitLook:Agent] (2/5) companies/$companyId/sellers/$sellerId',
    );

    var profile = await _loadSellerFromSlugData(slugData);
    if (profile == null) {
      debugPrint('[HitLook:Agent] (2/5) seller MISSING');
      final mirror = await _loadAgentsDoc(slug);
      return mirror ?? AgentProfile.defaultProfile;
    }

    debugPrint(
      '[HitLook:Agent] (2/5) seller OK nome="${profile.nome}" '
      'userId=${profile.userId} photo=${profile.fotoUrl.isNotEmpty}',
    );

    final uid = profile.userId?.trim() ?? '';
    if (uid.isNotEmpty) {
      debugPrint('[HitLook:Agent] (3/5) agents/$uid (priority merge)');
      final uidDoc = await _loadAgentsDoc(uid);
      debugPrint(
        '[HitLook:Agent] (3/5) agents/$uid exists=${uidDoc != null} '
        'nome="${uidDoc?.nome}" foto=${uidDoc?.fotoUrl.isNotEmpty == true}',
      );
      if (uidDoc != null) profile = _mergeAgentsPriority(profile, uidDoc);
    } else {
      debugPrint('[HitLook:Agent] (3/5) SKIP — seller has no userId');
    }

    debugPrint('[HitLook:Agent] (4/5) agents/$slug mirror');
    final slugMirror = await _loadAgentsDoc(slug);
    debugPrint(
      '[HitLook:Agent] (4/5) mirror nome="${slugMirror?.nome}" '
      'foto=${slugMirror?.fotoUrl.isNotEmpty == true}',
    );
    if (slugMirror != null) profile = _mergeAgentsPriority(profile, slugMirror);

    profile = _withPublicSlugContext(profile, slug);

    debugPrint(
      '[HitLook:Agent] (5/5) RESULT slug=$slug nome="${profile.nome}" '
      'resolved="${profile.resolvedNome}" foto=${profile.fotoUrl.isNotEmpty} '
      'userId=${profile.userId} cardId=${profile.id}',
    );
    return profile;
  }

  /// Public /a/{slug} pages always use slug as card id and a resolved agent name.
  static AgentProfile _withPublicSlugContext(AgentProfile profile, String slug) {
    final nome = profile.resolvedNome;
    return AgentProfile(
      id: slug,
      nome: nome,
      displayName: profile.displayName ?? (nome.isNotEmpty ? nome : null),
      bio: profile.bio,
      whatsapp: profile.whatsapp,
      fotoUrl: profile.fotoUrl,
      idioma: profile.idioma,
      nicho: profile.nicho,
      userId: profile.userId,
      companyId: profile.companyId,
      sellerId: profile.sellerId,
    );
  }

  static AgentProfile _finalizeProfile(AgentProfile profile, String agentId) {
    if (_hasPublicIdentity(profile)) {
      debugPrint(
        '[HitLook:Agent] ✓ finalize OK id=$agentId nome="${profile.nome}" '
        'foto=${profile.fotoUrl.isNotEmpty} userId=${profile.userId}',
      );
      return profile;
    }
    debugPrint(
      '[HitLook:Agent] ✗ finalize DEFAULT id=$agentId '
      '(nome="${profile.nome}" userId=${profile.userId})',
    );
    return AgentProfile.defaultProfile;
  }

  static bool _hasPublicIdentity(AgentProfile profile) {
    if (profile.fotoUrl.trim().isNotEmpty) return true;
    if (profile.resolvedNome.isNotEmpty &&
        !_isDefaultNome(profile.resolvedNome)) {
      return true;
    }
    return profile.userId != null &&
        profile.userId!.isNotEmpty &&
        profile.hasSaaSContext;
  }

  static bool _isDefaultNome(String nome) =>
      nome.isEmpty || nome == AgentProfile.defaultProfile.nome;

  static Future<DocumentSnapshot<Map<String, dynamic>>> _getDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get(const GetOptions(source: Source.server));
    } catch (e) {
      debugPrint('[HitLook:Agent] server read fallback ${ref.path}: $e');
      return await ref.get();
    }
  }

  static Future<AgentProfile?> _loadAgentsDoc(String id) async {
    final doc = await _getDoc(_db.collection('agents').doc(id));
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    debugPrint(
      '[HitLook:Agent] agents/$id fields: nome=${data['nome']} '
      'fotoUrl=${data['fotoUrl'] ?? data['photoUrl']} userId=${data['userId']}',
    );
    return AgentProfile.fromMap(id, data);
  }

  static Future<AgentProfile?> _loadViaUserId(String uid) async {
    DocumentSnapshot<Map<String, dynamic>> userDoc;
    try {
      userDoc = await _db.collection('users').doc(uid).get();
    } catch (e) {
      debugPrint('[HitLook:Agent] users/$uid read denied: $e');
      return null;
    }
    if (!userDoc.exists || userDoc.data() == null) return null;

    final data = userDoc.data()!;
    final companyId = data['companyId'] as String?;
    final sellerId = data['sellerId'] as String?;
    if (companyId == null || sellerId == null) {
      return await _loadAgentsDoc(uid);
    }

    final sellerDoc = await _db
        .collection('companies')
        .doc(companyId)
        .collection('sellers')
        .doc(sellerId)
        .get(const GetOptions(source: Source.server));
    if (!sellerDoc.exists || sellerDoc.data() == null) {
      return await _loadAgentsDoc(uid);
    }

    var profile = AgentProfile.fromSeller(
      sellerDoc.data()?['slug'] as String? ?? sellerId,
      sellerDoc.data()!,
      companyId: companyId,
      sellerId: sellerId,
    );

    final legacy = await _loadAgentsDoc(uid);
    if (legacy != null) profile = _mergeAgentsPriority(profile, legacy);

    final slug = sellerDoc.data()?['slug'] as String?;
    if (slug != null && slug.isNotEmpty && slug != uid) {
      final slugMirror = await _loadAgentsDoc(slug);
      if (slugMirror != null) profile = _mergeAgentsPriority(profile, slugMirror);
    }

    return profile;
  }

  static Future<AgentProfile?> _loadSellerFromSlugData(
    Map<String, dynamic> slugData,
  ) async {
    final companyId = slugData['companyId'] as String?;
    final sellerId = slugData['sellerId'] as String?;
    if (companyId == null || sellerId == null) return null;

    final sellerDoc = await _getDoc(
      _db
          .collection('companies')
          .doc(companyId)
          .collection('sellers')
          .doc(sellerId),
    );
    if (!sellerDoc.exists || sellerDoc.data() == null) return null;
    final data = sellerDoc.data()!;
    final slug = data['slug'] as String? ?? sellerId;
    debugPrint(
      '[HitLook:Agent] seller doc displayName=${data['displayName']} '
      'userId=${data['userId']} photoUrl=${data['photoUrl']}',
    );
    return AgentProfile.fromSeller(
      slug,
      data,
      companyId: companyId,
      sellerId: sellerId,
    );
  }

  /// [agents] doc (uid or slug mirror) overrides empty seller name/photo.
  static AgentProfile _mergeAgentsPriority(
    AgentProfile seller,
    AgentProfile agents,
  ) {
    return AgentProfile(
      id: seller.id,
      nome: _pickNomeFromProfiles(agents, seller),
      displayName: _pickString(agents.displayName, seller.displayName) ??
          _pickNomeFromProfiles(agents, seller),
      bio: _pickNonEmpty(agents.bio, seller.bio),
      whatsapp: _pickNonEmpty(agents.whatsapp, seller.whatsapp),
      fotoUrl: _pickNonEmpty(agents.fotoUrl, seller.fotoUrl),
      idioma: agents.idioma.isNotEmpty ? agents.idioma : seller.idioma,
      nicho: agents.nicho.isNotEmpty ? agents.nicho : seller.nicho,
      userId: _pickString(agents.userId, seller.userId),
      companyId: _pickString(seller.companyId, agents.companyId),
      sellerId: _pickString(seller.sellerId, agents.sellerId),
    );
  }

  static String _pickNomeFromProfiles(AgentProfile a, AgentProfile b) {
    for (final candidate in [
      a.nome,
      a.displayName,
      b.nome,
      b.displayName,
    ]) {
      final t = candidate?.trim() ?? '';
      if (!_isDefaultNome(t)) return t;
    }
    return '';
  }

  static String _pickNonEmpty(String a, String b) {
    if (a.trim().isNotEmpty) return a.trim();
    return b.trim();
  }

  static AgentProfile _merge(AgentProfile primary, AgentProfile legacy) {
    final nome = _pickNomeFromProfiles(primary, legacy);
    return AgentProfile(
      id: primary.id,
      nome: nome,
      displayName: _pickString(primary.displayName, legacy.displayName) ??
          (nome.isNotEmpty ? nome : null),
      bio: primary.bio.isNotEmpty ? primary.bio : legacy.bio,
      whatsapp:
          primary.whatsapp.isNotEmpty ? primary.whatsapp : legacy.whatsapp,
      fotoUrl:
          primary.fotoUrl.isNotEmpty ? primary.fotoUrl : legacy.fotoUrl,
      idioma: primary.idioma,
      nicho: primary.nicho,
      userId: primary.userId ?? legacy.userId,
      companyId: _pickString(primary.companyId, legacy.companyId),
      sellerId: _pickString(primary.sellerId, legacy.sellerId),
    );
  }

  static String? _pickString(String? a, String? b) {
    if (a != null && a.isNotEmpty) return a;
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  static AgentProfile _mergeAll(List<AgentProfile> profiles) {
    if (profiles.isEmpty) return AgentProfile.defaultProfile;
    var result = profiles.first;
    for (var i = 1; i < profiles.length; i++) {
      result = _merge(result, profiles[i]);
    }
    return result;
  }
}

/// Avatar initials: "M4LIFE USA" → M4, "Renan Sampaio" → RS, "Carlos Silva" → CS.
String agentInitials(String nome) {
  final words =
      nome.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'M4';

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

String _formatSlugAsDisplayName(String slug) {
  return slug
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Display name on public pages — agent only, never company branding.
String agentPublicDisplayName(AgentProfile agent, {String? publicSlug}) {
  final resolved = agent.resolvedNome;
  if (resolved.isNotEmpty && resolved != AgentProfile.defaultProfile.nome) {
    return resolved;
  }

  final slug = (publicSlug ?? agent.id).trim();
  if (slug.isNotEmpty &&
      slug != 'default' &&
      !AgentProvider.looksLikeFirebaseUid(slug)) {
    return _formatSlugAsDisplayName(slug);
  }

  debugPrint(
    '[HitLook:Agent] agentPublicDisplayName fallback Consultor '
    '(nome="${agent.nome}" displayName=${agent.displayName} id=${agent.id} slug=$publicSlug)',
  );
  return 'Consultor';
}

// ─── CARD DO AGENTE NA PÁGINA DO CLIENTE ─────────────────
class AgentCard extends StatelessWidget {
  final AgentProfile agent;
  /// URL slug from `/a/:slug` — used when [agent.id] is a Firebase UID.
  final String? publicSlug;

  const AgentCard({super.key, required this.agent, this.publicSlug});

  @override
  Widget build(BuildContext context) {
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
            displayName: agentPublicDisplayName(agent, publicSlug: publicSlug),
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
                  agentPublicDisplayName(agent, publicSlug: publicSlug),
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
