/// App user linked to Firebase Auth and optionally a company/seller.
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.tenantId,
    this.companyId,
    this.sellerId,
    this.role = UserRole.seller,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? tenantId;
  final String? companyId;
  final String? sellerId;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasSellerProfile => companyId != null && sellerId != null;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] as String?,
      displayName: map['displayName'] as String? ?? map['nome'] as String?,
      tenantId: map['tenantId'] as String?,
      companyId: map['companyId'] as String?,
      sellerId: map['sellerId'] as String? ?? map['agentId'] as String?,
      role: UserRole.fromString(map['role'] as String?),
      createdAt: null,
      updatedAt: null,
    );
  }

  Map<String, dynamic> toMap() => {
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        if (tenantId != null) 'tenantId': tenantId,
        if (companyId != null) 'companyId': companyId,
        if (sellerId != null) 'sellerId': sellerId,
        'role': role.name,
      };

  AppUser copyWith({
    String? email,
    String? displayName,
    String? tenantId,
    String? companyId,
    String? sellerId,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      tenantId: tenantId ?? this.tenantId,
      companyId: companyId ?? this.companyId,
      sellerId: sellerId ?? this.sellerId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum UserRole {
  seller,
  admin;

  static UserRole fromString(String? value) => UserRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => UserRole.seller,
      );
}
