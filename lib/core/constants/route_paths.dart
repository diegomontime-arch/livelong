/// Central route path constants for [GoRouter].
abstract final class RoutePaths {
  static const root = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const admin = '/admin';
  static const sellerProfile = '/perfil';
  static const onboarding = '/onboarding';
  static const settings = '/settings';
  static const legalPrivacy = '/legal/privacy';
  static const legalTerms = '/legal/terms';

  static String adminCompany(String companyId) => '$admin/companies/$companyId';

  static String adminCompanySellerLeads(String companyId, String sellerId) =>
      '$admin/companies/$companyId/sellers/$sellerId';

  /// Legacy path — prefer [adminCompanySellerLeads].
  static String adminSellerLeads(String sellerId) => '$admin/sellers/$sellerId';

  static const splash = '/splash';

  /// Public lead form: `/a/:sellerSlug`
  static const publicSellerPrefix = '/a';
  static String publicSeller(String sellerSlug) => '$publicSellerPrefix/$sellerSlug';
}
