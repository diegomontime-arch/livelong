import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hitlook/legacy/screens/agent_profile.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  AgentProfile _agent = AgentProfile.defaultProfile;
  bool _loading = true;
  List<Map<String, dynamic>> _leads = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Carrega perfil do agente
      final agentDoc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(uid)
          .get();

      if (agentDoc.exists && agentDoc.data() != null) {
        setState(() {
          _agent = AgentProfile.fromMap(uid, agentDoc.data()!);
        });
      }

      // Carrega leads
      final leadsSnapshot = await FirebaseFirestore.instance
          .collection('leads')
          .where('agentId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      setState(() {
        _leads = leadsSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _copyLink() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    var publicId = uid;
    try {
      final userSnap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final companyId = userSnap.data()?['companyId'] as String?;
      final sellerId = userSnap.data()?['sellerId'] as String?;
      if (companyId != null && sellerId != null) {
        final sellerSnap = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('sellers')
            .doc(sellerId)
            .get();
        final slug = sellerSnap.data()?['slug'] as String?;
        if (slug != null && slug.isNotEmpty) publicId = slug;
      }
      final slugFromAgent = (await FirebaseFirestore.instance
              .collection('agents')
              .doc(uid)
              .get())
          .data()?['slug'] as String?;
      if (slugFromAgent != null && slugFromAgent.isNotEmpty) {
        publicId = slugFromAgent;
      }
    } catch (_) {}

    final link = 'https://hitlook-app.web.app/a/$publicId';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copiado com sucesso!'),
        backgroundColor: AppColors.gold,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold))
              : Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.blackCard,
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.gold.withOpacity(0.15),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.blackLight,
                              border: Border.all(
                                color: AppColors.gold.withOpacity(0.4),
                              ),
                            ),
                            child: _agent.fotoUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      _agent.fotoUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      _agent.nome.isNotEmpty
                                          ? _agent.nome[0].toUpperCase()
                                          : 'A',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _agent.nome.isNotEmpty
                                      ? _agent.nome
                                      : 'Meu Painel',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                  ),
                                ),
                                Text(
                                  '${_leads.length} leads recebidos',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.greyLight,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Menu
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert,
                                color: AppColors.gold),
                            color: AppColors.blackCard,
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                onTap: () =>
                                    context.go('/perfil'),
                                child: const Row(
                                  children: [
                                    Icon(Icons.person_outline,
                                        color: AppColors.gold, size: 16),
                                    SizedBox(width: 8),
                                    Text('Editar perfil',
                                        style: TextStyle(
                                            color: AppColors.white)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                onTap: _logout,
                                child: const Row(
                                  children: [
                                    Icon(Icons.logout,
                                        color: AppColors.grey, size: 16),
                                    SizedBox(width: 8),
                                    Text('Sair',
                                        style: TextStyle(
                                            color: AppColors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Card do link
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.gold.withOpacity(0.12),
                              AppColors.gold.withOpacity(0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.gold.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.link,
                                    size: 14, color: AppColors.gold),
                                SizedBox(width: 6),
                                Text(
                                  'SEU LINK PERSONALIZADO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.gold,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'hitlook-app.web.app/a/${FirebaseAuth.instance.currentUser?.uid ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.whitesoft,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _copyLink,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.copy_outlined,
                                              size: 14,
                                              color: AppColors.black),
                                          SizedBox(width: 6),
                                          Text(
                                            'COPIAR LINK',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.black,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => context.go('/perfil'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            AppColors.gold.withOpacity(0.3),
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PERFIL',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.gold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Lista de leads
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                              width: 3,
                              height: 14,
                              color: AppColors.gold),
                          const SizedBox(width: 8),
                          const Text(
                            'LEADS RECEBIDOS',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gold,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: _leads.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: AppColors.grey.withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhum lead ainda',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Copie o link acima e envie para seus contatos',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          AppColors.grey.withOpacity(0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _leads.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final lead = _leads[i];
                                return _LeadCard(lead: lead);
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;

  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    final nome = lead['nome'] ?? 'Nome não informado';
    final telefone = lead['telefone'] ?? '';
    final score = lead['score'] ?? 0;
    final status = lead['status'] ?? 'novo';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'quente':
        statusColor = const Color(0xFFE74C3C);
        statusLabel = 'Quente';
        break;
      case 'contatado':
        statusColor = const Color(0xFFF39C12);
        statusLabel = 'Contatado';
        break;
      case 'fechado':
        statusColor = const Color(0xFF2ECC71);
        statusLabel = 'Fechado';
        break;
      case 'perdido':
        statusColor = AppColors.grey;
        statusLabel = 'Perdido';
        break;
      default:
        statusColor = AppColors.gold;
        statusLabel = 'Novo';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.gold.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withOpacity(0.3),
              ),
            ),
            child: Center(
              child: Text(
                '$score%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                if (telefone.isNotEmpty)
                  Text(
                    telefone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.greyLight,
                    ),
                  ),
              ],
            ),
          ),

          // Status
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
              ),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // WhatsApp
          if (telefone.isNotEmpty)
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_outlined,
                  size: 15,
                  color: Color(0xFF25D366),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
