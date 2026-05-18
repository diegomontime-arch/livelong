/// White-label tenant branding resolved at runtime (host, route, or env).
class TenantConfig {
  const TenantConfig({
    required this.id,
    required this.displayName,
    this.logoUrl,
    this.primaryColorHex,
    this.supportEmail,
  });

  final String id;
  final String displayName;
  final String? logoUrl;
  final String? primaryColorHex;
  final String? supportEmail;
}
