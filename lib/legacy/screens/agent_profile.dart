import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  const AgentProfile({
    required this.id,
    required this.nome,
    required this.bio,
    required this.whatsapp,
    required this.fotoUrl,
    required this.idioma,
    required this.nicho,
  });

  factory AgentProfile.fromMap(String id, Map<String, dynamic> map) {
    return AgentProfile(
      id: id,
      nome: map['nome'] ?? '',
      bio: map['bio'] ?? '',
      whatsapp: map['whatsapp'] ?? '',
      fotoUrl: map['fotoUrl'] ?? '',
      idioma: map['idioma'] ?? 'pt',
      nicho: map['nicho'] ?? 'seguro',
    );
  }

  // Perfil padrão quando não tem agente configurado
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
  /// Loads the public seller profile for [agentId] (Firebase UID or public slug).
  ///
  /// Profile data may live in legacy `agents/{uid}` and/or SaaS
  /// `seller_slugs` + `companies/.../sellers`. When the link uses a slug,
  /// we merge the SaaS seller with `agents/{userId}` so the photo saved in
  /// "Meu perfil" still appears.
  static Future<AgentProfile> loadAgent(String agentId) async {
    if (agentId.isEmpty || agentId == 'default') {
      return AgentProfile.defaultProfile;
    }

    try {
      final direct = await _loadAgentsDoc(agentId);
      if (direct != null && _isConfigured(direct)) return direct;

      final viaSlug = await _loadViaSellerSlug(agentId);
      if (viaSlug != null) return viaSlug;

      return direct ?? AgentProfile.defaultProfile;
    } catch (e) {
      return AgentProfile.defaultProfile;
    }
  }

  static bool _isConfigured(AgentProfile profile) {
    return profile.nome.isNotEmpty &&
        profile.nome != AgentProfile.defaultProfile.nome;
  }

  static Future<AgentProfile?> _loadAgentsDoc(String id) async {
    final doc = await FirebaseFirestore.instance
        .collection('agents')
        .doc(id)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return AgentProfile.fromMap(id, doc.data()!);
  }

  static Future<AgentProfile?> _loadViaSellerSlug(String slug) async {
    final slugDoc = await FirebaseFirestore.instance
        .collection('seller_slugs')
        .doc(slug)
        .get();
    if (!slugDoc.exists || slugDoc.data() == null) return null;

    final slugData = slugDoc.data()!;
    final companyId = slugData['companyId'] as String?;
    final sellerId = slugData['sellerId'] as String?;
    if (companyId == null || sellerId == null) return null;

    final sellerDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('sellers')
        .doc(sellerId)
        .get();
    if (!sellerDoc.exists || sellerDoc.data() == null) return null;

    final seller = sellerDoc.data()!;
    var profile = AgentProfile(
      id: slug,
      nome: seller['displayName'] as String? ?? '',
      bio: seller['bio'] as String? ?? '',
      whatsapp: seller['phone'] as String? ??
          seller['whatsapp'] as String? ??
          '',
      fotoUrl: seller['photoUrl'] as String? ?? '',
      idioma: 'pt',
      nicho: 'seguro',
    );

    final linkedUid = seller['userId'] as String?;
    if (linkedUid != null && linkedUid.isNotEmpty) {
      final legacy = await _loadAgentsDoc(linkedUid);
      if (legacy != null) profile = _merge(profile, legacy);
    }

    return profile;
  }

  /// Prefer SaaS display fields; fill photo/name from legacy when missing.
  static AgentProfile _merge(AgentProfile primary, AgentProfile legacy) {
    return AgentProfile(
      id: primary.id,
      nome: primary.nome.isNotEmpty ? primary.nome : legacy.nome,
      bio: primary.bio.isNotEmpty ? primary.bio : legacy.bio,
      whatsapp: primary.whatsapp.isNotEmpty ? primary.whatsapp : legacy.whatsapp,
      fotoUrl: primary.fotoUrl.isNotEmpty ? primary.fotoUrl : legacy.fotoUrl,
      idioma: primary.idioma,
      nicho: primary.nicho,
    );
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
          // Foto do agente
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
                      errorBuilder: (_, __, ___) => _initials(),
                    ),
                  )
                : _initials(),
          ),

          const SizedBox(width: 14),

          // Info do agente
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

          // Botão WhatsApp
          if (agent.whatsapp.isNotEmpty)
            GestureDetector(
              onTap: () => _abrirWhatsApp(agent.whatsapp),
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

  void _abrirWhatsApp(String numero) {
    // Abre WhatsApp com o número do agente
    final url = 'https://wa.me/$numero';
    // Implementar url_launcher futuramente
  }
}
