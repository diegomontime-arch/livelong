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

  const AgentProfile({
    required this.id,
    required this.nome,
    required this.bio,
    required this.whatsapp,
    required this.fotoUrl,
    required this.idioma,
    required this.nicho,
    this.userId,
  });

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
    );
  }

  factory AgentProfile.fromSeller(String slug, Map<String, dynamic> seller) {
    return AgentProfile(
      id: slug,
      nome: seller['displayName'] as String? ?? '',
      bio: seller['bio'] as String? ?? '',
      whatsapp: seller['phone'] as String? ??
          seller['whatsapp'] as String? ??
          '',
      fotoUrl: seller['photoUrl'] as String? ?? '',
      idioma: 'pt',
      nicho: 'seguro',
      userId: seller['userId'] as String?,
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
      final profiles = <AgentProfile>[];

      final viaSlug = await _loadViaSellerSlug(agentId);
      if (viaSlug != null) profiles.add(viaSlug);

      if (looksLikeFirebaseUid(agentId)) {
        final viaUser = await _loadViaUserId(agentId);
        if (viaUser != null) profiles.add(viaUser);
      }

      final direct = await _loadAgentsDoc(agentId);
      if (direct != null) profiles.add(direct);

      var merged = _mergeAll(profiles);
      if (_isConfigured(merged)) return merged;

      // Slug mirror: agents/{slug} when URL used UID but profile lives under slug doc.
      if (looksLikeFirebaseUid(agentId) && merged.userId != null) {
        final userSnap = await _db.collection('users').doc(agentId).get();
        final sellerId = userSnap.data()?['sellerId'] as String?;
        if (sellerId != null && sellerId.isNotEmpty) {
          final slugAgent = await _loadAgentsDoc(sellerId);
          if (slugAgent != null) {
            merged = _merge(merged, slugAgent);
            if (_isConfigured(merged)) return merged;
          }
        }
      }

      return merged.nome.isNotEmpty ? merged : AgentProfile.defaultProfile;
    } catch (_) {
      return AgentProfile.defaultProfile;
    }
  }

  static bool _isConfigured(AgentProfile profile) {
    return profile.nome.isNotEmpty &&
        profile.nome != AgentProfile.defaultProfile.nome;
  }

  static Future<AgentProfile?> _loadAgentsDoc(String id) async {
    final doc = await _db.collection('agents').doc(id).get();
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
        .get();
    if (!sellerDoc.exists || sellerDoc.data() == null) {
      return await _loadAgentsDoc(uid);
    }

    var profile = AgentProfile.fromSeller(
      sellerDoc.data()?['slug'] as String? ?? sellerId,
      sellerDoc.data()!,
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
        .get();
    if (!sellerDoc.exists || sellerDoc.data() == null) return null;
    return AgentProfile.fromSeller(sellerId, sellerDoc.data()!);
  }

  static Future<AgentProfile?> _loadViaSellerSlug(String slug) async {
    final slugDoc = await _db.collection('seller_slugs').doc(slug).get();
    if (!slugDoc.exists || slugDoc.data() == null) return null;

    final profile = await _loadSellerFromSlugData(slugDoc.data()!);
    if (profile == null) return null;

    var merged = AgentProfile(
      id: slug,
      nome: profile.nome,
      bio: profile.bio,
      whatsapp: profile.whatsapp,
      fotoUrl: profile.fotoUrl,
      idioma: profile.idioma,
      nicho: profile.nicho,
      userId: profile.userId,
    );

    final slugMirror = await _loadAgentsDoc(slug);
    if (slugMirror != null) merged = _merge(merged, slugMirror);

    final linkedUid = profile.userId;
    if (linkedUid != null && linkedUid.isNotEmpty) {
      final legacy = await _loadAgentsDoc(linkedUid);
      if (legacy != null) merged = _merge(merged, legacy);
    }

    return merged;
  }

  static AgentProfile _merge(AgentProfile primary, AgentProfile legacy) {
    return AgentProfile(
      id: primary.id,
      nome: primary.nome.isNotEmpty ? primary.nome : legacy.nome,
      bio: primary.bio.isNotEmpty ? primary.bio : legacy.bio,
      whatsapp:
          primary.whatsapp.isNotEmpty ? primary.whatsapp : legacy.whatsapp,
      fotoUrl:
          primary.fotoUrl.isNotEmpty ? primary.fotoUrl : legacy.fotoUrl,
      idioma: primary.idioma,
      nicho: primary.nicho,
      userId: primary.userId ?? legacy.userId,
    );
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
    final initials = agent.nome.isNotEmpty
        ? agent.nome.trim().split(' ').map((w) => w[0]).take(2).join()
        : 'M4';
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
