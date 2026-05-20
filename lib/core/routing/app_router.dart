import 'package:go_router/go_router.dart';

import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/core/routing/route_guards.dart';
import 'package:hitlook/legacy/screens/admin_dashboard_screen.dart';
import 'package:hitlook/legacy/screens/admin_seller_leads_screen.dart';
import 'package:hitlook/legacy/screens/agent_dashboard_screen.dart';
import 'package:hitlook/legacy/screens/agent_login_screen.dart';
import 'package:hitlook/legacy/screens/agent_setup_screen.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';
/// Application router. Legacy screens are wired here until feature UIs land.
///
/// Public lead form uses one URL per entry (`/` or `/a/:sellerSlug`); responsive
/// layout is handled by PublicLeadFlowScaffold, not separate routes.
final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.root,
  redirect: authRedirect,
  routes: [
    GoRoute(
      path: RoutePaths.root,
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: '${RoutePaths.publicSellerPrefix}/:sellerSlug',
      builder: (context, state) {
        final sellerSlug = state.pathParameters['sellerSlug'] ?? '';
        return LanguageScreen(agentId: sellerSlug);
      },
    ),
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
  ],
);
