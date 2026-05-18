/// Central route path constants for [GoRouter].
abstract final class RoutePaths {
  static const root = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const sellerProfile = '/perfil';
  static const onboarding = '/onboarding';

  /// Public lead form: `/a/:sellerSlug`
  static const publicSellerPrefix = '/a';
  static String publicSeller(String sellerSlug) => '$publicSellerPrefix/$sellerSlug';
}
