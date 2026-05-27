import 'package:go_router/go_router.dart';

import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/core/routing/route_guards.dart';
import 'package:hitlook/core/utils/public_agent_slug.dart';
import 'package:hitlook/features/legal/presentation/legal_screen.dart';
import 'package:hitlook/features/settings/presentation/settings_screen.dart';
import 'package:hitlook/legacy/screens/admin_company_screen.dart';
import 'package:hitlook/legacy/screens/admin_dashboard_screen.dart';
import 'package:hitlook/legacy/screens/admin_seller_leads_screen.dart';
import 'package:hitlook/legacy/screens/agent_dashboard_screen.dart';
import 'package:hitlook/legacy/screens/agent_login_screen.dart';
import 'package:hitlook/legacy/screens/agent_setup_screen.dart';
import 'package:hitlook/legacy/screens/hitlook_splash_screen.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: routerInitialLocation(),
  redirect: authRedirect,
  routes: [
    GoRoute(
      path: RoutePaths.splash,
      builder: (context, state) {
        final next = state.uri.queryParameters['next'] ?? RoutePaths.root;
        // Path-only: evita perder /a/:slug ao voltar do splash legado.
        final path = Uri.tryParse(next)?.path;
        return HitLookSplashScreen(destination: path ?? next);
      },
    ),
    GoRoute(
      path: RoutePaths.root,
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: '${RoutePaths.publicSellerPrefix}/:sellerSlug',
      builder: (context, state) {
        final sellerSlug = state.pathParameters['sellerSlug'] ?? '';
        return LanguageScreen(agentId: sellerSlug.isNotEmpty ? sellerSlug : 'default');
      },
    ),
    // Login only — agent accounts are created by admin (no public /signup route).
    GoRoute(
      path: RoutePaths.login,
      builder: (context, state) {
        final qp = state.uri.queryParameters;
        return AgentLoginScreen(
          passwordResetOobCode:
              qp['mode'] == 'resetPassword' ? qp['oobCode'] : null,
        );
      },
    ),
    GoRoute(
      path: RoutePaths.dashboard,
      builder: (context, state) => const AgentDashboardScreen(),
    ),
    GoRoute(
      path: RoutePaths.admin,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '${RoutePaths.admin}/companies/:companyId',
      builder: (context, state) {
        final companyId = state.pathParameters['companyId'] ?? '';
        return AdminCompanyScreen(
          companyId: companyId,
          showBackToMaster: true,
        );
      },
    ),
    GoRoute(
      path: '${RoutePaths.admin}/companies/:companyId/sellers/:sellerId',
      builder: (context, state) {
        final companyId = state.pathParameters['companyId'] ?? '';
        final sellerId = state.pathParameters['sellerId'] ?? '';
        return AdminSellerLeadsScreen(
          companyId: companyId,
          sellerId: sellerId,
        );
      },
    ),
    GoRoute(
      path: '${RoutePaths.admin}/sellers/:sellerId',
      builder: (context, state) {
        final sellerId = state.pathParameters['sellerId'] ?? '';
        return AdminSellerLeadsScreen(sellerId: sellerId);
      },
    ),
    GoRoute(
      path: RoutePaths.sellerProfile,
      builder: (context, state) => const AgentSetupScreen(),
    ),
    GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: RoutePaths.legalPrivacy,
      builder: (context, state) {
        final lang = state.uri.queryParameters['lang'] ?? 'en';
        return LegalScreen(document: LegalDocument.privacy, lang: lang);
      },
    ),
    GoRoute(
      path: RoutePaths.legalTerms,
      builder: (context, state) {
        final lang = state.uri.queryParameters['lang'] ?? 'en';
        return LegalScreen(document: LegalDocument.terms, lang: lang);
      },
    ),
  ],
);
