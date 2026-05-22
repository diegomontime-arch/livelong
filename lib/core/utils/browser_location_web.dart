import 'dart:html' as html;

String browserPathname() => html.window.location.pathname ?? '/';

String browserSearch() => html.window.location.search ?? '';

/// Parses `/a/{slug}` from the real browser URL (Flutter Web boot fix).
String? publicSellerSlugFromBrowser() {
  final path = browserPathname();
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  // /a/diego-teste → ['a', 'diego-teste']
  if (segments.length >= 2 && segments[0] == 'a') {
    return segments[1];
  }
  return null;
}
