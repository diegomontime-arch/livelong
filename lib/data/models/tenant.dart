/// White-label tenant (e.g. M4LIFE). Controls branding; invisible to end prospects.
class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    this.logoUrl,
    this.primaryColorHex,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? primaryColorHex;
  final bool isActive;

  factory Tenant.fromMap(String id, Map<String, dynamic> map) {
    return Tenant(
      id: id,
      name: map['name'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      primaryColorHex: map['primaryColorHex'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (primaryColorHex != null) 'primaryColorHex': primaryColorHex,
        'isActive': isActive,
      };
}
