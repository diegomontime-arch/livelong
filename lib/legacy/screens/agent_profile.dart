import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hitlook/core/utils/whatsapp_utils.dart';
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
    this.userId,
    this.companyId,
    this.sellerId,
  });

  bool get hasSaaSContext =>
      companyId != null &&
      companyId!.isNotEmpty &&
      sellerId != null &&
      sellerId!.isNotEmpty;

  factory AgentProfile.fromMap(String id, Map<String, dynamic> map) {
    return AgentProfile(
      id: id,
      nome: map['nome'] as String? ?? map['displayName'] as String? ?? '',
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
    return AgentProfile(
      id: slug,
      nome: seller['displayName'] as String? ?? '',
      bio: seller['bio'] as String? ?? '',
      whatsapp: seller['phone'] as String? ??
          seller['whatsapp'] as String? ??
          '',
      fotoUrl: seller['photoUrl'] as String? ?? '',
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
      return AgentProfile.defaultProfile;
    }

    try {
      debugPrint('[HitLook:Agent] loadAgent start → $agentId');

      if (looksLikeFirebaseUid(agentId)) {
        final profile = await _loadByUid(agentId);
        return _finalizeProfile(profile, agentId);
      }

      final profile = await _loadByPublicSlug(agentId);
      return _finalizeProfile(profile, agentId);
    } catch (e, st) {
      debugPrint('[HitLook:Agent] loadAgent FAILED: $e\n$st');
      return AgentProfile.defaultProfile;
    }
  }

  static Future<AgentProfile> _loadByUid(String uid) async {
    final profiles = <AgentProfile>[];
    final viaUser = await _loadViaUserId(uid);
    if (viaUser != null) profiles.add(viaUser);
    final direct = await _loadAgentsDoc(uid);
    if (direct != null) profiles.add(direct);
    return _mergeAll(profiles);
  }

  /// seller_slugs/{slug} → seller → agents/{userId} + agents/{slug}
  static Future<AgentProfile> _loadByPublicSlug(String slug) async {
    final slugSnap = await _db
        .collection('seller_slugs')
        .doc(slug)
        .get(const GetOptions(source: Source.server));
    debugPrint(
      '[HitLook:Agent] seller_slugs/$slug exists=${slugSnap.exists}',
    );

    if (!slugSnap.exists || slugSnap.data() == null) {
      debugPrint('[HitLook:Agent] slug missing — trying agents/$slug only');
      final mirror = await _loadAgentsDoc(slug);
      return mirror ?? AgentProfile.defaultProfile;
    }

    final slugData = slugSnap.data()!;
    final companyId = slugData['companyId'] as String?;
    final sellerId = slugData['sellerId'] as String?;
    debugPrint(
      '[HitLook:Agent] slug map → companyId=$companyId sellerId=$sellerId',
    );

    var profile = await _loadSellerFromSlugData(slugData);
    if (profile == null) {
      debugPrint('[HitLook:Agent] seller doc missing');
      return AgentProfile.defaultProfile;
    }

    debugPrint(
      '[HitLook:Agent] seller → nome="${profile.nome}" userId=${profile.userId}',
    );

    final uid = profile.userId;
    if (uid != null && uid.isNotEmpty) {
      final uidDoc = await _loadAgentsDoc(uid);
      debugPrint(
        '[HitLook:Agent] agents/$uid → nome="${uidDoc?.nome}" fotoUrl=${uidDoc?.fotoUrl.isNotEmpty == true}',
      );
      if (uidDoc != null) profile = _merge(profile, uidDoc);
    }

    final slugMirror = await _loadAgentsDoc(slug);
    debugPrint(
      '[HitLook:Agent] agents/$slug → nome="${slugMirror?.nome}" fotoUrl=${slugMirror?.fotoUrl.isNotEmpty == true}',
    );
    if (slugMirror != null) profile = _merge(profile, slugMirror);

    debugPrint(
      '[HitLook:Agent] merged → nome="${profile.nome}" fotoUrl=${profile.fotoUrl.isNotEmpty}',
    );
    return profile;
  }

  static AgentProfile _finalizeProfile(AgentProfile profile, String agentId) {
    if (_isConfigured(profile)) {
      debugPrint('[HitLook:Agent] OK configured id=$agentId nome=${profile.nome}');
      return profile;
    }
    debugPrint(
      '[HitLook:Agent] fallback default id=$agentId nome="${profile.nome}"',
    );
    return profile.nome.isNotEmpty ? profile : AgentProfile.defaultProfile;
  }

  static bool _isConfigured(AgentProfile profile) {
    return profile.nome.isNotEmpty &&
        profile.nome != AgentProfile.defaultProfile.nome;
  }

  static bool _isDefaultNome(String nome) =>
      nome.isEmpty || nome == AgentProfile.defaultProfile.nome;

  static Future<AgentProfile?> _loadAgentsDoc(String id) async {
    final doc = await _db
        .collection('agents')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists || doc.data() == null) return null;
    return AgentProfile.fromMap(id, doc.data()!);
  }

  static Future<AgentProfile?> _loadViaUserId(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
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
    if (legacy != null) profile = _merge(profile, legacy);

    final slug = sellerDoc.data()?['slug'] as String?;
    if (slug != null && slug.isNotEmpty && slug != uid) {
      final slugMirror = await _loadAgentsDoc(slug);
      if (slugMirror != null) profile = _merge(profile, slugMirror);
    }

    return profile;
  }

  static Future<AgentProfile?> _loadSellerFromSlugData(
    Map<String, dynamic> slugData,
  ) async {
    final companyId = slugData['companyId'] as String?;
    final sellerId = slugData['sellerId'] as String?;
    if (companyId == null || sellerId == null) return null;

    final sellerDoc = await _db
        .collection('companies')
        .doc(companyId)
        .collection('sellers')
        .doc(sellerId)
        .get(const GetOptions(source: Source.server));
    if (!sellerDoc.exists || sellerDoc.data() == null) return null;
    final slug = sellerDoc.data()?['slug'] as String? ?? sellerId;
    return AgentProfile.fromSeller(
      slug,
      sellerDoc.data()!,
      companyId: companyId,
      sellerId: sellerId,
    );
  }

  static AgentProfile _merge(AgentProfile primary, AgentProfile legacy) {
    return AgentProfile(
      id: primary.id,
      nome: !_isDefaultNome(primary.nome)
          ? primary.nome
          : (!_isDefaultNome(legacy.nome) ? legacy.nome : primary.nome),
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

String _initialsNameForAgent(AgentProfile agent) {
  final isDefaultName = agent.nome.isEmpty ||
      agent.nome == AgentProfile.defaultProfile.nome;

  if (isDefaultName &&
      agent.companyId != null &&
      agent.companyId!.isNotEmpty) {
    return switch (agent.companyId) {
      'm4life' => 'M4LIFE USA',
      'hitlook' => 'HitLook',
      _ => agent.companyId!.toUpperCase(),
    };
  }

  if (isDefaultName) return 'M4LIFE USA';
  return agent.nome;
}

// ─── CARD DO AGENTE NA PÁGINA DO CLIENTE ─────────────────
class AgentCard extends StatelessWidget {
  final AgentProfile agent;

  const AgentCard({super.key, required this.agent});

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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withOpacity(0.4),
                width: 1.5,
              ),
              color: AppColors.blackLight,
            ),
            child: agent.fotoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      agent.fotoUrl,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      errorBuilder: (_, __, ___) => _initials(),
                    ),
                  )
                : _initials(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.nome,
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

  Widget _initials() {
    final initials = agentInitials(_initialsNameForAgent(agent));
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
