/// Firestore collection and document path helpers for multi-tenant SaaS.
///
/// Hierarchy:
/// - [tenants] — white-label branding (M4LIFE, Portobello, …)
/// - [companies] — B2B accounts under a tenant
/// - sellers and leads scoped under a company
abstract final class FirestorePaths {
  static const tenants = 'tenants';
  static const companies = 'companies';
  static const sellers = 'sellers';
  static const leads = 'leads';
  static const users = 'users';
  static const sellerSlugs = 'seller_slugs';
  static const aiRecommendations = 'ai_recommendations';

  static String tenant(String tenantId) => '$tenants/$tenantId';

  static String user(String userId) => '$users/$userId';

  static String sellerSlug(String slug) => '$sellerSlugs/$slug';

  static String company(String companyId) => '$companies/$companyId';

  static String companySellers(String companyId) =>
      '${company(companyId)}/$sellers';

  static String companySeller(String companyId, String sellerId) =>
      '${companySellers(companyId)}/$sellerId';

  static String companyLeads(String companyId) => '${company(companyId)}/$leads';

  static String companyLead(String companyId, String leadId) =>
      '${companyLeads(companyId)}/$leadId';

  static String companyLeadRecommendations(String companyId, String leadId) =>
      '${companyLead(companyId, leadId)}/$aiRecommendations';

  static String companyLeadRecommendation(
    String companyId,
    String leadId,
    String recommendationId,
  ) =>
      '${companyLeadRecommendations(companyId, leadId)}/$recommendationId';
}
