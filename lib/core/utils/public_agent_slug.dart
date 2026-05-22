import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:hitlook/core/utils/browser_location_stub.dart'
    if (dart.library.html) 'package:hitlook/core/utils/browser_location_web.dart'
    as browser;

/// Resolves public agent slug: route param → browser URL → GoRouter state.
String resolvePublicAgentId(
  String routeAgentId, {
  GoRouterState? routerState,
}) {
  final fromRoute = routeAgentId.trim();
  if (fromRoute.isNotEmpty && fromRoute != 'default') {
    return fromRoute;
  }

  if (kIsWeb) {
    final fromBrowser = browser.publicSellerSlugFromBrowser();
    if (fromBrowser != null && fromBrowser.isNotEmpty) {
      return fromBrowser;
    }
  }

  final fromRouter = routerState?.pathParameters['sellerSlug']?.trim() ?? '';
  if (fromRouter.isNotEmpty) {
    return fromRouter;
  }

  return 'default';
}

/// Initial [GoRouter] location on web — use real pathname, not `/`.
String routerInitialLocation() {
  if (!kIsWeb) return '/';

  final path = browser.browserPathname();
  final search = browser.browserSearch();
  if (path.startsWith('/a/') && path.length > 3) {
    return search.isNotEmpty ? '$path$search' : path;
  }
  if (path != '/' && path.isNotEmpty) {
    return search.isNotEmpty ? '$path$search' : path;
  }
  return '/';
}
