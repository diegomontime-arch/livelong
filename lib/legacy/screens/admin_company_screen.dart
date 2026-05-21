import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:hitlook/core/config/app_config.dart';
import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/data/models/lead.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/legacy/widgets/flow_ux.dart';
import 'package:hitlook/data/repositories/firebase/firebase_lead_repository.dart';
import 'package:hitlook/data/repositories/firebase/firebase_seller_repository.dart';
import 'package:hitlook/legacy/admin/admin_session.dart';
import 'package:hitlook/legacy/admin/admin_seller_avatar.dart';
import 'package:hitlook/legacy/admin/create_seller_sheet.dart';
import 'package:hitlook/legacy/admin/seller_metrics.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

/// Company admin dashboard — agents, metrics, links (Renan / Diego drill-down).
class AdminCompanyScreen extends StatefulWidget {
  const AdminCompanyScreen({
    super.key,
    required this.companyId,
    this.showBackToMaster = false,
  });

  final String companyId;
  final bool showBackToMaster;

  @override
  State<AdminCompanyScreen> createState() => _AdminCompanyScreenState();
}

class _AdminCompanyScreenState extends State<AdminCompanyScreen> {
  final _sellerRepo = FirebaseSellerRepository();
  final _leadRepo = FirebaseLeadRepository();
  AdminSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await AdminSession.load();
    if (!mounted) return;
    if (session == null || !session.isAdmin) {
      context.go(RoutePaths.dashboard);
      return;
    }
    setState(() => _session = session);
  }

  Future<void> _createSeller() async {
    final created = await showCreateSellerSheet(
      context: context,
      companyId: widget.companyId,
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Agente ${created.displayName} criado. Senha: ${AppConfig.defaultSellerPassword}',
          ),
          backgroundColor: AppColors.gold,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _copyLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copiado!'),
        backgroundColor: AppColors.gold,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(
        backgroundColor: AppColors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: _session!.displayName ?? 'Admin',
                showBack: widget.showBackToMaster,
                onBack: () => context.go(RoutePaths.admin),
                onLogout: _logout,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AGENTES · ${widget.companyId.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gold,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _createSeller,
                      icon: const Icon(Icons.add, size: 18, color: AppColors.gold),
                      label: const Text(
                        'ADICIONAR',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<Seller>>(
                  stream: _sellerRepo.watchByCompany(widget.companyId),
                  builder: (context, sellersSnap) {
                    if (sellersSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      );
                    }

                    final sellers = sellersSnap.data ?? [];

                    return StreamBuilder<List<Lead>>(
                      stream: _leadRepo.watchByCompany(widget.companyId),
                      builder: (context, leadsSnap) {
                        final leads = leadsSnap.data ?? [];
                        final metricsBySeller = SellerMetrics.bySeller(leads);
                        final companyMetrics = SellerMetrics.fromLeads(leads);

                        if (sellers.isEmpty) {
                          return _EmptySellers(onCreate: _createSeller);
                        }

                        final rows = sellers
                            .map(
                              (s) => SellerWithMetrics(
                                seller: s,
                                metrics: metricsBySeller[s.id] ??
                                    const SellerMetrics.empty(),
                                lastLeadAt: SellerWithMetrics.lastLeadDateFor(
                                  leads,
                                  s.id,
                                ),
                              ),
                            )
                            .toList();

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            _CompanySummaryCard(metrics: companyMetrics),
                            const SizedBox(height: 16),
                            ...rows.map(
                              (row) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _SellerCard(
                                  row: row,
                                  onCopyLink: () => _copyLink(
                                    row.publicLink(AppConfig.publicWebBaseUrl),
                                  ),
                                  onOpenLeads: () => context.go(
                                    RoutePaths.adminCompanySellerLeads(
                                      widget.companyId,
                                      row.seller.id,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
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

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onLogout,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final VoidCallback onLogout;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        border: Border(bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.gold),
            ),
          const M4LifeLogo(fontSize: 18, showTagline: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAINEL ADMIN',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.gold,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Sair',
            child: IconButton(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: AppColors.gold, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanySummaryCard extends StatelessWidget {
  const _CompanySummaryCard({required this.metrics});

  final SellerMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESUMO DA EMPRESA',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.gold,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Metric(label: 'Total', value: metrics.total)),
              Expanded(child: _Metric(label: 'Novos', value: metrics.newLeads)),
              Expanded(
                  child: _Metric(label: 'Contatados', value: metrics.contacted)),
              Expanded(child: _Metric(label: 'Fechados', value: metrics.closed)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.greyLight),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({
    required this.row,
    required this.onCopyLink,
    required this.onOpenLeads,
  });

  final SellerWithMetrics row;
  final VoidCallback onCopyLink;
  final VoidCallback onOpenLeads;

  @override
  Widget build(BuildContext context) {
    final slug = row.seller.slug ?? row.seller.id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminSellerAvatar(
                displayName: row.seller.displayName,
                photoUrl: row.seller.photoUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.seller.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '/a/$slug',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.greyLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      SellerProfileLabels.idioma(row.seller.idioma),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.grey,
                      ),
                    ),
                    Text(
                      SellerProfileLabels.nicho(row.seller.nicho),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.grey,
                      ),
                    ),
                    Text(
                      row.lastLeadAt != null
                          ? 'Último lead: ${formatLeadDate(row.lastLeadAt)}'
                          : 'Nenhum lead ainda',
                      style: TextStyle(
                        fontSize: 11,
                        color: row.lastLeadAt != null
                            ? AppColors.goldDim
                            : AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _Metric(label: 'Total', value: row.metrics.total)),
              Expanded(
                  child: _Metric(label: 'Novos', value: row.metrics.newLeads)),
              Expanded(
                  child:
                      _Metric(label: 'Contatados', value: row.metrics.contacted)),
              Expanded(
                  child: _Metric(label: 'Fechados', value: row.metrics.closed)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopyLink,
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('COPIAR LINK',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onOpenLeads,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'VER LEADS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySellers extends StatelessWidget {
  const _EmptySellers({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined,
                size: 48, color: AppColors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Nenhum agente cadastrado',
              style: TextStyle(color: AppColors.grey, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.black,
              ),
              child: const Text('ADICIONAR AGENTE'),
            ),
          ],
        ),
      ),
    );
  }
}
