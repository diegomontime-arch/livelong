import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hitlook/core/utils/whatsapp_utils.dart';
import 'package:hitlook/legacy/admin/agent_profile_photo.dart';
import 'package:hitlook/legacy/screens/agent_profile.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';
import 'package:hitlook/legacy/widgets/flow_ux.dart';

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

  Future<void> _loadData({bool refresh = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

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

      if (agentDoc != null && agentDoc.exists && agentDoc.data() != null) {
        if (mounted) {
          setState(() {
            _agent = AgentProfile.fromMap(uid, agentDoc.data()!);
          });
        }
      }

      final publicId = await AgentProvider.resolvePublicLinkId(uid);
      if (mounted) setState(() => _publicLinkId = publicId);

      final leadsSnapshot = await runWithTimeout(
        () => FirebaseFirestore.instance
            .collection('leads')
            .where('agentId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(_pageSize)
            .get(),
      );

      if (leadsSnapshot == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _loadError =
                'Demorou demais para carregar. Verifique sua conexão e tente novamente.';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _leads = leadsSnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          _hasMore = leadsSnapshot.docs.length >= _pageSize;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = isNetworkError(e)
              ? 'Sem conexão com a internet. Puxe para atualizar.'
              : 'Não foi possível carregar seus leads. Tente novamente.';
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
      await FirebaseFirestore.instance.collection('leads').doc(id).update({
        'status': status,
      });
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
      final nome = lead['nome']?.toString() ?? 'Nome não informado';
      final telefone = lead['telefone']?.toString() ?? '';
      final score = lead['score'] ?? 0;
      final status = normalizeLeadStatus(lead['status'] as String?);
      final meta = _statusMeta(status);
      final lang = lead['lang']?.toString() ?? 'pt';
      final nascimento = lead['nascimento']?.toString() ?? '';
      final answers = lead['answers'];

      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.blackCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: meta.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        meta.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: meta.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Score: $score%',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (telefone.isNotEmpty)
                  _LeadDetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Telefone',
                    value: telefone,
                  ),
                if (nascimento.isNotEmpty)
                  _LeadDetailRow(
                    icon: Icons.cake_outlined,
                    label: 'Nascimento',
                    value: nascimento,
                  ),
                _LeadDetailRow(
                  icon: Icons.schedule,
                  label: 'Recebido em',
                  value: formatLeadDate(lead['createdAt']),
                ),
                _LeadDetailRow(
                  icon: Icons.language,
                  label: 'Idioma',
                  value: lang.toUpperCase(),
                ),
                if (answers is Map && answers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Respostas do questionário',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.greyLight,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...answers.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.whiteWarm,
                        ),
                      ),
                    ),
                  ),
                ],
                if (telefone.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        openWhatsApp(
                          phone: telefone,
                          message: buildLeadWhatsAppMessage(
                            lang: lang,
                            score: score is int ? score : int.tryParse('$score') ?? 0,
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Abrir WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[LeadDetail] erro: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
                                    onStatusChanged: (status) =>
                                        _updateLeadStatus(_leads[i], status),
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

class _LeadStatusOption {
  const _LeadStatusOption(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;
}

const _leadStatusOptions = [
  _LeadStatusOption('novo', 'Novo', AppColors.gold),
  _LeadStatusOption('contatado', 'Contatado', Color(0xFFF39C12)),
  _LeadStatusOption('fechado', 'Fechado', Color(0xFF2ECC71)),
  _LeadStatusOption('perdido', 'Perdido', Color(0xFF888888)),
];

/// Maps SaaS/legacy status values to dashboard dropdown values.
String normalizeLeadStatus(String? raw) {
  final s = (raw ?? 'novo').toString().toLowerCase().trim();
  if (s == 'new') return 'novo';
  const valid = {'novo', 'contatado', 'fechado', 'perdido'};
  if (valid.contains(s)) return s;
  return 'novo';
}

_LeadStatusOption _statusMeta(String status) {
  return _leadStatusOptions.firstWhere(
    (o) => o.value == status,
    orElse: () => _leadStatusOptions.first,
  );
}

class _LeadDetailRow extends StatelessWidget {
  const _LeadDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.gold.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.greyLight,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final VoidCallback onTap;
  final ValueChanged<String> onStatusChanged;

  const _LeadCard({
    required this.lead,
    required this.onTap,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final nome = lead['nome'] ?? 'Nome não informado';
    final telefone = lead['telefone']?.toString() ?? '';
    final score = lead['score'] ?? 0;
    final status = normalizeLeadStatus(lead['status'] as String?);
    final meta = _statusMeta(status);
    final lang = lead['lang']?.toString() ?? 'pt';
    final scoreInt = score is int ? score : int.tryParse('$score') ?? 0;

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
                Text(
                  formatLeadDate(lead['createdAt']),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.grey.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: status,
              dropdownColor: AppColors.blackCard,
              borderRadius: BorderRadius.circular(8),
              icon: Icon(Icons.expand_more, size: 18, color: meta.color),
              style: TextStyle(
                fontSize: 11,
                color: meta.color,
                fontWeight: FontWeight.w600,
              ),
              items: _leadStatusOptions
                  .map(
                    (o) => DropdownMenuItem(
                      value: o.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: o.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            o.label,
                            style: TextStyle(color: o.color, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null && v != status) onStatusChanged(v);
              },
            ),
          ),

          const SizedBox(width: 4),

          // WhatsApp
          if (telefone.isNotEmpty)
            GestureDetector(
              onTap: () {
                openWhatsApp(
                  phone: telefone,
                  message: buildLeadWhatsAppMessage(
                    lang: lang,
                    score: scoreInt,
                  ),
                );
              },
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
        ),
      ),
    );
  }
}
