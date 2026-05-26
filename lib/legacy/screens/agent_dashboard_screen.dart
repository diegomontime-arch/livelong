import 'package:flutter/foundation.dart';
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

  void _dashboardLog(String message) {
    debugPrint(message);
    if (kIsWeb) print(message);
  }

  @override
  void initState() {
    super.initState();
    _dashboardLog('[Dashboard] initState — mounting AgentDashboardScreen');
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

  List<Map<String, dynamic>> _snapshotToLeadRows(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
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

  Future<QuerySnapshot<Map<String, dynamic>>> _queryRootLeadsUnordered(
    String uid,
  ) async {
    _dashboardLog('[Dashboard] leads query (unordered): agentId == $uid');
    return FirebaseFirestore.instance
        .collection('leads')
        .where('agentId', isEqualTo: uid)
        .limit(_pageSize)
        .get();
  }

  Future<List<Map<String, dynamic>>> _fetchRootLeads(String uid) async {
    _dashboardLog('[Dashboard] uid=$uid');
    _dashboardLog('[Dashboard] leads query: agentId == uid');

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirebaseFirestore.instance
          .collection('leads')
          .where('agentId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();
      _dashboardLog(
        '[Dashboard] root leads (ordered): ${snapshot.docs.length} docs',
      );
      // orderBy omits documents without createdAt — retry if empty but data may exist.
      if (snapshot.docs.isEmpty) {
        snapshot = await _queryRootLeadsUnordered(uid);
        _dashboardLog(
          '[Dashboard] root leads (unordered retry): ${snapshot.docs.length} docs',
        );
      }
    } on FirebaseException catch (e) {
      _dashboardLog(
        '[Dashboard] root leads ordered error: code=${e.code} message=${e.message}',
      );
      if (e.code != 'failed-precondition') rethrow;
      snapshot = await _queryRootLeadsUnordered(uid);
      _dashboardLog(
        '[Dashboard] root leads (index fallback): ${snapshot.docs.length} docs',
      );
    }

    return _snapshotToLeadRows(snapshot);
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

  /// Compare phone/name ignoring case, diacritics and non-digits — D3.
  /// Previously "José" / "Jose" and "+1 305" / "1305" were treated as
  /// different leads, leaving duplicate rows in the dashboard.
  String _normalizeName(String s) {
    final lowered = s.trim().toLowerCase();
    const accents = 'áàâãäåéèêëíìîïóòôõöúùûüçñ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucn';
    final sb = StringBuffer();
    for (final ch in lowered.split('')) {
      final i = accents.indexOf(ch);
      sb.write(i == -1 ? ch : plain[i]);
    }
    return sb.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizePhone(String s) =>
      s.replaceAll(RegExp(r'\D'), '');

  /// Returns a stable fingerprint `phone|name` for dedup, or null when
  /// there is no phone (we won't try to dedup by name alone).
  String? _leadFingerprint(Map<String, dynamic> lead) {
    final phone = _normalizePhone(leadDisplayPhone(lead));
    if (phone.isEmpty) return null;
    final name = _normalizeName(leadDisplayName(lead));
    return '$phone|$name';
  }

  List<Map<String, dynamic>> _mergeLeadRows(
    List<Map<String, dynamic>> rootLeads,
    List<Map<String, dynamic>> companyLeads,
  ) {
    final byKey = <String, Map<String, dynamic>>{};
    // Build a fingerprint set of root leads once — O(n) — instead of an
    // O(n²) scan per company lead.
    final rootFingerprints = <String>{};
    for (final r in rootLeads) {
      final fp = _leadFingerprint(r);
      if (fp != null) rootFingerprints.add(fp);
    }
    for (final lead in rootLeads) {
      final id = lead['id']?.toString();
      if (id == null || id.isEmpty) continue;
      byKey['root:$id'] = lead;
    }
    for (final lead in companyLeads) {
      final id = lead['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final fp = _leadFingerprint(lead);
      final duplicate = fp != null && rootFingerprints.contains(fp);
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
    _dashboardLog(
      '[Dashboard] uid=${FirebaseAuth.instance.currentUser?.uid}',
    );

    final uid = await _resolveUid();
    if (uid == null) {
      _dashboardLog('[Dashboard] uid resolve failed — not signed in');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Faça login novamente para ver seus leads.';
        });
      }
      return;
    }

    _dashboardLog('[Dashboard] resolved uid=$uid');

    if (refresh) {
      setState(() {
        _loading = true;
        _loadError = null;
        _hasMore = true;
      });
    }

    try {
      // Leads first — do not block on profile / public link resolution.
      final rootLeads = await _fetchRootLeads(uid);
      _dashboardLog('[Dashboard] rootLeads count=${rootLeads.length}');

      var agent = _agent;
      try {
        agent = await AgentProvider.loadAgent(uid);
        _dashboardLog(
          '[Dashboard] agent loaded nome="${agent.nome}" saas=${agent.hasSaaSContext}',
        );
      } catch (e) {
        _dashboardLog('[Dashboard] AgentProvider.loadAgent: $e');
      }

      String publicId = _publicLinkId;
      try {
        publicId = await AgentProvider.resolvePublicLinkId(uid);
      } catch (e) {
        _dashboardLog('[Dashboard] resolvePublicLinkId: $e');
      }

      List<Map<String, dynamic>> companyLeads = const [];
      try {
        companyLeads = await _fetchCompanyLeads(agent);
        _dashboardLog('[Dashboard] companyLeads count=${companyLeads.length}');
      } catch (e) {
        _dashboardLog('[Dashboard] company leads: $e');
      }

      // Run the three independent reads in parallel — D2 in planning/CHECKLIST.md.
      // resolvePublicLinkId(uid), _fetchRootLeads(uid) and _fetchCompanyLeads(agent)
      // were previously sequential, adding ~1 round-trip each on slow networks.
      final results = await Future.wait<dynamic>([
        AgentProvider.resolvePublicLinkId(uid),
        runWithTimeout(() => _fetchRootLeads(uid)),
        _fetchCompanyLeads(agent).catchError((e) {
          debugPrint('[Dashboard] company leads: $e');
          return const <Map<String, dynamic>>[];
        }),
      ]);

      final String? publicId = results[0] as String?;
      final List<Map<String, dynamic>>? rootLeads =
          results[1] as List<Map<String, dynamic>>?;
      final List<Map<String, dynamic>> companyLeads =
          (results[2] as List<Map<String, dynamic>>?) ??
              const <Map<String, dynamic>>[];

      if (mounted) setState(() => _publicLinkId = publicId);

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

      final merged = _mergeLeadRows(rootLeads, companyLeads);
      _dashboardLog('[Dashboard] merged leads count=${merged.length}');

      if (mounted) {
        setState(() {
          _agent = agent;
          _publicLinkId = publicId;
          _leads = merged;
          _hasMore = merged.length >= _pageSize;
          _loading = false;
          _loadError = null;
        });
      }
    } on FirebaseException catch (e, st) {
      _dashboardLog('[Dashboard] FirebaseException: ${e.code} ${e.message}\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.code == 'permission-denied'
              ? 'Sem permissão para ler seus leads. Verifique o login.'
              : 'Erro ao carregar leads (${e.code}). Tente novamente.';
        });
      }
    } catch (e, st) {
      _dashboardLog('[Dashboard] load leads: $e\n$st');
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
      QuerySnapshot<Map<String, dynamic>> snapshot;
      if (lastCreatedAt != null) {
        try {
          snapshot = await FirebaseFirestore.instance
              .collection('leads')
              .where('agentId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .startAfter([lastCreatedAt])
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
      } else {
        snapshot = await FirebaseFirestore.instance
            .collection('leads')
            .where('agentId', isEqualTo: uid)
            .limit(_pageSize)
            .get();
      }

      if (mounted) {
        setState(() {
          final existingIds = _leads.map((l) => l['id']).toSet();
          for (final doc in snapshot.docs) {
            if (!existingIds.contains(doc.id)) {
              _leads.add({'id': doc.id, ...doc.data()});
            }
          }
          _hasMore = snapshot.docs.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (e) {
      _dashboardLog('[Dashboard] loadMore: $e');
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
    _dashboardLog(
      '[Dashboard] build loading=$_loading leads=${_leads.length} error=$_loadError',
    );
    try {
      return _buildContent(context);
    } catch (e, stack) {
      _dashboardLog('[Dashboard] BUILD ERROR: $e');
      _dashboardLog('[Dashboard] STACK: $stack');
      return Scaffold(
        backgroundColor: AppColors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Erro no painel: $e',
              style: const TextStyle(color: AppColors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: SizedBox.expand(
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
                                onTap: () => _logout(),
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
                      child: ColoredBox(
                        color: AppColors.black,
                        child: RefreshIndicator(
                        color: AppColors.gold,
                        backgroundColor: AppColors.blackCard,
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
                                  final lead = _leads[i];
                                  try {
                                    return _LeadCard(
                                      lead: lead,
                                      onTap: () => _showLeadDetail(lead),
                                    );
                                  } catch (e, st) {
                                    _dashboardLog(
                                      '[Dashboard] LeadCard[$i] error: $e\n$st',
                                    );
                                    return const ListTile(
                                      title: Text(
                                        'Lead indisponível',
                                        style: TextStyle(
                                          color: AppColors.greyLight,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                        ),
                      ),
                    ),
                        ],
                      ),
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
    final dateLabel = formatLeadDate(lead['createdAt']);

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.blackCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      dateLabel,
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
                        nome: nome,
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
