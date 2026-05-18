import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:hitlook/core/constants/route_paths.dart';

/// Auth and scope redirects for [GoRouter].
String? authRedirect(BuildContext context, GoRouterState state) {
  final isLoggedIn = FirebaseAuth.instance.currentUser != null;
  final path = state.uri.path;

  final protectedPaths = {
    RoutePaths.dashboard,
    RoutePaths.sellerProfile,
  };

  if (protectedPaths.contains(path) && !isLoggedIn) {
    return RoutePaths.login;
  }

  return null;
}
