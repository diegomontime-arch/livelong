import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hitlook/core/config/app_config.dart';
import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/legacy/admin/admin_session.dart';
import 'package:hitlook/legacy/screens/admin_company_screen.dart';
import 'package:hitlook/legacy/screens/admin_master_screen.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

/// Routes admins to master (HitLook) or company dashboard.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _redirectIfNeeded();
  }

  Future<void> _redirectIfNeeded() async {
    final session = await AdminSession.load();
    if (!mounted || session == null) return;

    if (session.companyId != AppConfig.masterCompanyId) {
      final target = RoutePaths.adminCompany(session.companyId);
      final router = GoRouter.of(context);
      if (router.state.uri.path != target) {
        context.go(target);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminSession?>(
      future: AdminSession.load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.black,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }

        final session = snap.data;
        if (session == null || !session.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(RoutePaths.dashboard);
          });
          return const SizedBox.shrink();
        }

        if (session.companyId == AppConfig.masterCompanyId) {
          return const AdminMasterScreen();
        }

        return AdminCompanyScreen(companyId: session.companyId);
      },
    );
  }
}
