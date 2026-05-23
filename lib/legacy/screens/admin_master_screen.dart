import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/data/models/company.dart';
import 'package:hitlook/data/repositories/firebase/firebase_company_repository.dart';
import 'package:hitlook/data/repositories/firebase/firebase_lead_repository.dart';
import 'package:hitlook/data/repositories/firebase/firebase_seller_repository.dart';
import 'package:hitlook/legacy/admin/admin_session.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

/// HitLook platform master view — all companies (Diego).
class AdminMasterScreen extends StatefulWidget {
  const AdminMasterScreen({super.key});

  @override
  State<AdminMasterScreen> createState() => _AdminMasterScreenState();
}

class _AdminMasterScreenState extends State<AdminMasterScreen> {
  final _companyRepo = FirebaseCompanyRepository();
  final _sellerRepo = FirebaseSellerRepository();
  final _leadRepo = FirebaseLeadRepository();

  AdminSession? _session;

  @override
  void initState() {
    super.initState();
    AdminSession.load().then((s) {
      if (mounted) setState(() => _session = s);
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MasterHeader(
                title: _session?.displayName ?? 'Diego Rocha',
                onLogout: _logout,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'EMPRESAS',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.gold,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Company>>(
                  stream: _companyRepo.watchAll(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      );
                    }

                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Erro ao carregar empresas: ${snap.error}',
                            style: const TextStyle(color: AppColors.greyLight),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final companies = snap.data ?? [];
                    if (companies.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma empresa cadastrada',
                          style: TextStyle(color: AppColors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: companies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _CompanyCard(
                        company: companies[i],
                        sellerRepo: _sellerRepo,
                        leadRepo: _leadRepo,
                        onTap: () => context.go(
                          RoutePaths.adminCompany(companies[i].id),
                        ),
                      ),
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

class _MasterHeader extends StatelessWidget {
  const _MasterHeader({required this.title, required this.onLogout});

  final String title;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        border: Border(bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          const HitLookLogo(fontSize: 22, letterSpacing: 3),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HITLOOK MASTER',
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
                    color: AppColors.whiteWarm,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onLogout,
            tooltip: 'Sair',
            icon: const Icon(Icons.logout, color: AppColors.gold, size: 24),
          ),
        ],
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.company,
    required this.sellerRepo,
    required this.leadRepo,
    required this.onTap,
  });

  final Company company;
  final FirebaseSellerRepository sellerRepo;
  final FirebaseLeadRepository leadRepo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      company.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.whiteWarm,
                      ),
                    ),
                  ),
                  _StatusChip(active: company.isActive),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppColors.gold),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                company.id.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.greyLight),
              ),
              const SizedBox(height: 14),
              StreamBuilder(
                stream: sellerRepo.watchByCompany(company.id),
                builder: (context, sellersSnap) {
                  final agentCount = sellersSnap.data?.length ?? 0;
                  return StreamBuilder(
                    stream: leadRepo.watchByCompany(company.id),
                    builder: (context, leadsSnap) {
                      if (leadsSnap.hasError) {
                        return Row(
                          children: [
                            _Stat(label: 'Agentes', value: '$agentCount'),
                            const SizedBox(width: 24),
                            const _Stat(label: 'Leads', value: '—'),
                          ],
                        );
                      }
                      final leadCount = leadsSnap.data?.length ?? 0;
                      return Row(
                        children: [
                          _Stat(label: 'Agentes', value: '$agentCount'),
                          const SizedBox(width: 24),
                          _Stat(label: 'Leads', value: '$leadCount'),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active
              ? AppColors.gold.withValues(alpha: 0.4)
              : AppColors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        active ? 'ATIVO' : 'INATIVO',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: active ? AppColors.gold : AppColors.greyLight,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.gold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.greyLight),
        ),
      ],
    );
  }
}
