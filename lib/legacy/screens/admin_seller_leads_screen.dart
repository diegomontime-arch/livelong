import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/core/utils/whatsapp_utils.dart';
import 'package:hitlook/data/models/lead.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/data/repositories/firebase/firebase_lead_repository.dart';
import 'package:hitlook/data/repositories/firebase/firebase_seller_repository.dart';
import 'package:hitlook/legacy/admin/admin_session.dart';
import 'package:hitlook/legacy/admin/lead_status_ui.dart';
import 'package:hitlook/legacy/admin/seller_metrics.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';
import 'package:hitlook/legacy/widgets/flow_ux.dart';

/// Admin view of leads for a single seller.
class AdminSellerLeadsScreen extends StatefulWidget {
  const AdminSellerLeadsScreen({
    super.key,
    required this.sellerId,
    this.companyId,
  });

  final String sellerId;
  final String? companyId;

  @override
  State<AdminSellerLeadsScreen> createState() => _AdminSellerLeadsScreenState();
}

class _AdminSellerLeadsScreenState extends State<AdminSellerLeadsScreen> {
  final _sellerRepo = FirebaseSellerRepository();
  final _leadRepo = FirebaseLeadRepository();

  AdminSession? _session;
  Seller? _seller;
  String? _companyId;

  static const _statusOptions = [
    LeadStatus.newLead,
    LeadStatus.contacted,
    LeadStatus.closed,
    LeadStatus.lost,
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = await AdminSession.load();
    if (!mounted) return;
    if (session == null || !session.isAdmin) {
      context.go(RoutePaths.dashboard);
      return;
    }

    final companyId = widget.companyId ?? session.companyId;
    setState(() {
      _session = session;
      _companyId = companyId;
    });

    final result = await _sellerRepo.getById(
      companyId: companyId,
      sellerId: widget.sellerId,
    );
    if (!mounted) return;
    if (result is Success<Seller>) {
      setState(() => _seller = result.value);
    }
  }

  void _goBack() {
    final companyId = _companyId;
    if (companyId != null) {
      context.go(RoutePaths.adminCompany(companyId));
    } else {
      context.go(RoutePaths.admin);
    }
  }

  Future<void> _updateStatus(Lead lead, LeadStatus status) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final result = await _leadRepo.updateStatus(
      companyId: companyId,
      leadId: lead.id,
      status: status,
    );

    if (!mounted) return;
    if (result is Error<void>) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failure.message),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final companyId = _companyId;
    final seller = _seller;

    if (session == null || companyId == null) {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.blackCard,
                  border: Border(
                    bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back, color: AppColors.gold),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seller?.displayName ?? 'Agente',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                          if (seller?.slug != null)
                            Text(
                              '/a/${seller!.slug}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.greyLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Lead>>(
                  stream: _leadRepo.watchBySeller(
                    companyId: companyId,
                    sellerId: widget.sellerId,
                  ),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      );
                    }

                    final leads = snap.data ?? [];
                    final metrics = SellerMetrics.fromLeads(leads);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                  child: _chip('Total', metrics.total)),
                              Expanded(
                                  child: _chip('Novos', metrics.newLeads)),
                              Expanded(
                                  child:
                                      _chip('Contatados', metrics.contacted)),
                              Expanded(
                                  child: _chip('Fechados', metrics.closed)),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'LEADS',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gold,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: leads.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Nenhum lead para este agente',
                                    style: TextStyle(color: AppColors.grey),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: leads.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) => _LeadAdminCard(
                                    lead: leads[i],
                                    onStatusChanged: (s) =>
                                        _updateStatus(leads[i], s),
                                  ),
                                ),
                        ),
                      ],
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

  Widget _chip(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.greyLight),
          ),
        ],
      ),
    );
  }
}

class _LeadAdminCard extends StatelessWidget {
  const _LeadAdminCard({
    required this.lead,
    required this.onStatusChanged,
  });

  final Lead lead;
  final ValueChanged<LeadStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final name = lead.prospectName ?? 'Sem nome';
    final phone = lead.prospectPhone ?? '';
    final score = lead.score ?? 0;
    final statusColor = leadStatusColor(lead.status);
    final dateLabel = formatLeadDate(lead.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(
                    '$score%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.greyLight,
                        ),
                      ),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.grey.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                IconButton(
                  onPressed: () {
                    openWhatsApp(
                      phone: phone,
                      message: 'Olá $name, sou o consultor M4LIFE.',
                    );
                  },
                  icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LeadStatus>(
            key: ValueKey('${lead.id}_${lead.status.name}'),
            initialValue: lead.status,
            dropdownColor: AppColors.blackCard,
            style: const TextStyle(color: AppColors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Status',
              labelStyle: const TextStyle(color: AppColors.greyLight, fontSize: 12),
              filled: true,
              fillColor: AppColors.black,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: statusColor.withValues(alpha: 0.35)),
              ),
            ),
            items: _AdminSellerLeadsScreenState._statusOptions
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.labelPt),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onStatusChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
