/// Seller (agent) profile within a [Company].
class Seller {
  const Seller({
    required this.id,
    required this.companyId,
    required this.displayName,
    this.slug,
    this.email,
    this.phone,
    this.photoUrl,
    this.bio,
    this.userId,
    this.isActive = true,
  });

  final String id;
  final String companyId;
  final String displayName;
  final String? slug;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? bio;
  final String? userId;
  final bool isActive;

  factory Seller.fromMap(String id, Map<String, dynamic> map) {
    return Seller(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? map['name'] as String? ?? '',
      slug: map['slug'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String? ?? map['whatsapp'] as String?,
      photoUrl: map['photoUrl'] as String?,
      bio: map['bio'] as String?,
      userId: map['userId'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'displayName': displayName,
        if (slug != null) 'slug': slug,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (bio != null) 'bio': bio,
        if (userId != null) 'userId': userId,
        'isActive': isActive,
      };
}
