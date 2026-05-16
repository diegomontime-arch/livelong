import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'language_screen.dart';

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
  static Future<AgentProfile> loadAgent(String agentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(agentId)
          .get();

      if (doc.exists && doc.data() != null) {
        return AgentProfile.fromMap(agentId, doc.data()!);
      }
      return AgentProfile.defaultProfile;
    } catch (e) {
      return AgentProfile.defaultProfile;
    }
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
