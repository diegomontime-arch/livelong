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
    this.idioma,
    this.nicho,
    this.instagramUrl,
    this.linkedinUrl,
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
  final String? idioma;
  final String? nicho;
  final String? instagramUrl;
  final String? linkedinUrl;

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
      idioma: map['idioma'] as String?,
      nicho: map['nicho'] as String?,
      instagramUrl: map['instagramUrl'] as String?,
      linkedinUrl: map['linkedinUrl'] as String?,
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
        if (idioma != null) 'idioma': idioma,
        if (nicho != null) 'nicho': nicho,
        if (instagramUrl != null) 'instagramUrl': instagramUrl,
        if (linkedinUrl != null) 'linkedinUrl': linkedinUrl,
      };
}

/// Display labels for seller profile fields in admin UI.
abstract final class SellerProfileLabels {
  static const idiomas = {'pt': 'Português', 'es': 'Español', 'en': 'English'};

  static const nichos = {
    'seguro': 'Seguro de Vida',
    'pisos': 'Pisos',
    'solar': 'Solar',
    'mortgage': 'Mortgage',
  };

  static String idioma(String? code) =>
      idiomas[code ?? 'pt'] ?? idiomas['pt']!;

  static String nicho(String? code) =>
      nichos[code ?? 'seguro'] ?? nichos['seguro']!;
}
