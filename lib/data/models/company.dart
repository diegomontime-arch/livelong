/// B2B company account under a [Tenant]. Owns sellers and leads.
class Company {
  const Company({
    required this.id,
    required this.tenantId,
    required this.name,
    this.plan = CompanyPlan.starter,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final CompanyPlan plan;
  final bool isActive;
  final DateTime? createdAt;

  factory Company.fromMap(String id, Map<String, dynamic> map) {
    return Company(
      id: id,
      tenantId: map['tenantId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      plan: CompanyPlan.fromString(map['plan'] as String?),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'tenantId': tenantId,
        'name': name,
        'plan': plan.name,
        'isActive': isActive,
        if (createdAt != null) 'createdAt': createdAt,
      };
}

enum CompanyPlan {
  starter,
  growth,
  enterprise;

  static CompanyPlan fromString(String? value) => CompanyPlan.values.firstWhere(
        (p) => p.name == value,
        orElse: () => CompanyPlan.starter,
      );
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  // Firestore Timestamp handled in repository implementations.
  return null;
}
