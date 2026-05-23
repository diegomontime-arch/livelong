import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hitlook/core/utils/whatsapp_utils.dart';
import 'package:hitlook/legacy/admin/agent_profile_photo.dart';
import 'package:hitlook/legacy/admin/dashboard_lead_status.dart';
import 'package:hitlook/legacy/screens/agent_profile.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';
import 'package:hitlook/legacy/widgets/flow_ux.dart';
import 'package:hitlook/legacy/widgets/lead_detail_sheet.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  AgentProfile _agent = AgentProfile.defaultProfile;
  bool _loading = true;
  bool _loadingMore = false;
  String? _loadError;
  List<Map<String, dynamic>> _leads = [];
  bool _hasMore = true;
  String _publicLinkId = '';
  static const _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String?> _resolveUid() async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) return uid;
    try {
      final user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 6));
      return user?.uid;
    } catch (_) {
      return FirebaseAuth.instance.currentUser?.uid;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRootLeads(String uid) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirebaseFirestore.instance
          .collection('leads')
          .where('agentId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      snapshot = await FirebaseFirestore.instance
          .collection('leads')
          .where('agentId', isEqualTo: uid)
          .limit(_pageSize)
          .get();
    }

    final rows = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
    rows.sort((a, b) {
      final da = leadCreatedAt(a);
      final db = leadCreatedAt(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return rows;
  }

  Future<List<Map<String, dynamic>>> _fetchCompanyLeads(AgentProfile agent) async {
    if (!agent.hasSaaSContext) return const [];

    final companyId = agent.companyId!;
    final sellerId = agent.sellerId!;
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('leads')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('leads')
          .where('sellerId', isEqualTo: sellerId)
          .limit(_pageSize)
          .get();
    }

    return snapshot.docs
        .map(
          (doc) => {
            'id': doc.id,
            'companyId': companyId,
            'companyLead': true,
            ...doc.data(),
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> _mergeLeadRows(
    List<Map<String, dynamic>> rootLeads,
    List<Map<String, dynamic>> companyLeads,
  ) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final lead in rootLeads) {
      final id = lead['id']?.toString();
      if (id == null || id.isEmpty) continue;
      byKey['root:$id'] = lead;
    }
    for (final lead in companyLeads) {
      final id = lead['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final phone = leadDisplayPhone(lead);
      final name = leadDisplayName(lead);
      final duplicate = rootLeads.any(
        (r) =>
            leadDisplayPhone(r) == phone &&
            phone.isNotEmpty &&
            leadDisplayName(r) == name,
      );
      if (!duplicate) {
        byKey['company:$id'] = lead;
      }
    }
    final merged = byKey.values.toList();
    merged.sort((a, b) {
      final da = leadCreatedAt(a);
      final db = leadCreatedAt(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return merged;
  }

  Future<void> _loadData({bool refresh = false}) async {
    final uid = await _resolveUid();
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Faça login novamente para ver seus leads.';
        });
      }
      return;
    }

    if (refresh) {
      setState(() {
        _loading = true;
        _loadError = null;
        _hasMore = true;
      });
    }

    try {
      final agentDoc = await runWithTimeout(
        () => FirebaseFirestore.instance.collection('agents').doc(uid).get(),
      );

      var agent = _agent;
      if (agentDoc != null && agentDoc.exists && agentDoc.data() != null) {
        agent = AgentProfile.fromMap(uid, agentDoc.data()!);
        if (mounted) setState(() => _agent = agent);
      }

      final publicId = await AgentProvider.resolvePublicLinkId(uid);
      if (mounted) setState(() => _publicLinkId = publicId);

      final rootLeads = await runWithTimeout(() => _fetchRootLeads(uid));
      if (rootLeads == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _loadError =
                'Demorou demais para carregar. Verifique sua conexão e tente novamente.';
          });
        }
        return;
      }

      List<Map<String, dynamic>> companyLeads = const [];
      try {
        companyLeads = await _fetchCompanyLeads(agent);
      } catch (e) {
        debugPrint('[Dashboard] company leads: $e');
      }

      final merged = _mergeLeadRows(rootLeads, companyLeads);

      if (mounted) {
        setState(() {
          _leads = merged;
          _hasMore = merged.length >= _pageSize;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e, st) {
      debugPrint('[Dashboard] load leads: $e\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = isNetworkError(e)
              ? 'Sem conexão com a internet. Puxe para atualizar.'
              : 'Erro ao carregar leads. Tente novamente.';
        });
      }
    }
  }

  Future<void> _updateLeadStatus(
    Map<String, dynamic> lead,
    String status,
  ) async {
    final id = lead['id'] as String?;
    if (id == null) return;

    try {
      final companyId = lead['companyId'] as String?;
      final isCompanyLead = lead['companyLead'] == true && companyId != null;
      if (isCompanyLead) {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('leads')
            .doc(id)
            .update({'status': status});
      } else {
        await FirebaseFirestore.instance.collection('leads').doc(id).update({
          'status': status,
        });
      }
      if (!mounted) return;
      setState(() {
        lead['status'] = status;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _leads.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loadingMore = true);
    try {
      final lastCreatedAt = _leads.last['createdAt'];
      final snapshot = await FirebaseFirestore.instance
          .collection('leads')
          .where('agentId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .startAfter([lastCreatedAt])
          .limit(_pageSize)
          .get();

      if (mounted) {
        setState(() {
          _leads.addAll(
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}),
          );
          _hasMore = snapshot.docs.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _copyLink() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final publicId = _publicLinkId.isNotEmpty
        ? _publicLinkId
        : await AgentProvider.resolvePublicLinkId(uid);
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

  void _showLeadDetail(Map<String, dynamic> lead) {
    try {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.blackCard,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => LeadDetailSheet(
          lead: lead,
          onStatusChanged: (status) => _updateLeadStatus(lead, status),
        ),
      );
    } catch (e, st) {
      debugPrint('[LeadDetail] erro: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir os detalhes deste lead. Tente novamente.',
          ),
          backgroundColor: AppColors.blackCard,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: _loading
              ? const FlowLoadingView(message: 'Carregando seu painel...')
              : _loadError != null && _leads.isEmpty
                  ? FlowErrorView(
                      message: _loadError!,
                      onRetry: () => _loadData(refresh: true),
                    )
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
                          AgentProfilePhoto(
                            displayName: _agent.nome.isNotEmpty
                                ? _agent.nome
                                : 'Agente',
                            storageUid: FirebaseAuth.instance.currentUser?.uid,
                            photoUrl:
                                _agent.fotoUrl.isNotEmpty ? _agent.fotoUrl : null,
                            size: 44,
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
                                onTap: () {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (context.mounted) context.go('/perfil');
                                  });
                                },
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
                              'hitlook-app.web.app/a/${_publicLinkId.isNotEmpty ? _publicLinkId : (FirebaseAuth.instance.currentUser?.uid ?? '')}',
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
                      child: RefreshIndicator(
                        color: AppColors.gold,
                        onRefresh: () => _loadData(refresh: true),
                        child: _leads.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 80),
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: AppColors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Center(
                                    child: Text(
                                      'Nenhum lead ainda',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: AppColors.greyLight,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 32),
                                    child: Text(
                                      'Copie seu link personalizado acima e envie para seus contatos no WhatsApp.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount:
                                    _leads.length + (_hasMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  if (i == _leads.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                        child: _loadingMore
                                            ? const CircularProgressIndicator(
                                                color: AppColors.gold,
                                                strokeWidth: 2,
                                              )
                                            : TextButton(
                                                onPressed: _loadMore,
                                                child: const Text(
                                                  'Carregar mais',
                                                  style: TextStyle(
                                                    color: AppColors.gold,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    );
                                  }
                                  return _LeadCard(
                                    lead: _leads[i],
                                    onTap: () => _showLeadDetail(_leads[i]),
                                  );
                                },
                              ),
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
  final VoidCallback onTap;

  const _LeadCard({
    required this.lead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nome = leadDisplayName(lead);
    final telefone = leadDisplayPhone(lead);
    final scoreInt = leadDisplayScore(lead);
    final status = normalizeLeadStatus(lead['status']?.toString());
    final meta = dashboardLeadStatusMeta(status);
    final lang = lead['lang']?.toString() ?? 'pt';

    return Material(
      color: AppColors.blackCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$scoreInt%',
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
                    Text(
                      formatLeadDate(lead['createdAt']),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.grey.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: meta.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (telefone.isNotEmpty) ...[
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () {
                    openWhatsApp(
                      phone: telefone,
                      message: buildLeadWhatsAppMessage(
                        lang: lang,
                        score: scoreInt,
                      ),
                    );
                  },
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
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
            ],
          ),
        ),
      ),
    );
  }
}
