import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/legacy/admin/admin_session.dart';

bool _isPublicClientPath(String path) {
  if (path == RoutePaths.root) return true;
  return path.startsWith('${RoutePaths.publicSellerPrefix}/');
}

/// Auth and role-based redirects for [GoRouter].
Future<String?> authRedirect(BuildContext context, GoRouterState state) async {
  final qp = state.uri.queryParameters;
  final oobCode = qp['oobCode'];
  final mode = qp['mode'];
  final path = state.uri.path;

  if (path == RoutePaths.splash) return null;

  // Public lead funnel — never redirect logged-in admins/agents away.
  // Splash é visual dentro de [LanguageScreen] — não redirecionar para /splash.
  if (_isPublicClientPath(path)) return null;

  // Password-reset links must land on /login (not / or other routes).
  if (mode == 'resetPassword' &&
      oobCode != null &&
      oobCode.isNotEmpty &&
      state.uri.path != RoutePaths.login) {
    return '${RoutePaths.login}?mode=resetPassword&oobCode=${Uri.encodeComponent(oobCode)}';
  }

  final isLoggedIn = FirebaseAuth.instance.currentUser != null;

  final sellerPaths = {
    RoutePaths.dashboard,
    RoutePaths.sellerProfile,
  };

  final isAdminPath = path == RoutePaths.admin || path.startsWith('${RoutePaths.admin}/');

  if ((sellerPaths.contains(path) || isAdminPath) && !isLoggedIn) {
    return RoutePaths.login;
  }

  if (!isLoggedIn) return null;

  // Already signed in — leave login screen (avoids stuck loading on /login).
  if (path == RoutePaths.login) {
    return AdminSession.postLoginRoute();
  }

  // Dashboard and /perfil: legacy sellers need no `users/{uid}` document.
  if (path == RoutePaths.sellerProfile) {
    return null;
  }

  if (path == RoutePaths.dashboard) {
    final session = await AdminSession.load();
    if (session?.isAdmin == true) return RoutePaths.admin;
    return null;
  }

  final session = await AdminSession.load();

  if (isAdminPath) {
    if (session == null || !session.isAdmin) {
      return RoutePaths.dashboard;
    }
    return null;
  }

  return null;
}
