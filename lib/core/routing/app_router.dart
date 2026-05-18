import 'package:go_router/go_router.dart';

import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/core/routing/route_guards.dart';
import 'package:hitlook/legacy/screens/agent_dashboard_screen.dart';
import 'package:hitlook/legacy/screens/agent_login_screen.dart';
import 'package:hitlook/legacy/screens/agent_setup_screen.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

/// Application router. Legacy screens are wired here until feature UIs land.
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
      builder: (context, state) => const AgentLoginScreen(),
    ),
    GoRoute(
      path: RoutePaths.dashboard,
      builder: (context, state) => const AgentDashboardScreen(),
    ),
    GoRoute(
      path: RoutePaths.sellerProfile,
      builder: (context, state) => const AgentSetupScreen(),
    ),
  ],
);
