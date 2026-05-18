/// Qualified prospect captured via the public lead form.
class Lead {
  const Lead({
    required this.id,
    required this.companyId,
    required this.sellerId,
    required this.status,
    this.locale,
    this.score,
    this.answers = const {},
    this.recommendedPlan,
    this.prospectName,
    this.prospectPhone,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String sellerId;
  final LeadStatus status;
  final String? locale;
  final int? score;
  final Map<String, dynamic> answers;
  final String? recommendedPlan;
  final String? prospectName;
  final String? prospectPhone;
  final DateTime? createdAt;

  factory Lead.fromMap(String id, Map<String, dynamic> map) {
    return Lead(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      sellerId: map['sellerId'] as String? ?? map['agentId'] as String? ?? '',
      status: LeadStatus.fromString(map['status'] as String?),
      locale: map['locale'] as String?,
      score: (map['score'] as num?)?.toInt(),
      answers: Map<String, dynamic>.from(map['answers'] as Map? ?? {}),
      recommendedPlan: map['recommendedPlan'] as String?,
      prospectName: map['prospectName'] as String? ?? map['name'] as String?,
      prospectPhone: map['prospectPhone'] as String? ?? map['phone'] as String?,
      createdAt: map['createdAt'] is DateTime ? map['createdAt'] as DateTime : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'sellerId': sellerId,
        'status': status.name,
        if (locale != null) 'locale': locale,
        if (score != null) 'score': score,
        if (answers.isNotEmpty) 'answers': answers,
        if (recommendedPlan != null) 'recommendedPlan': recommendedPlan,
        if (prospectName != null) 'prospectName': prospectName,
        if (prospectPhone != null) 'prospectPhone': prospectPhone,
        if (createdAt != null) 'createdAt': createdAt,
      };
}

enum LeadStatus {
  newLead,
  qualified,
  contacted,
  won,
  lost;

  static LeadStatus fromString(String? value) {
    if (value == null || value == 'new') return LeadStatus.newLead;
    return LeadStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => LeadStatus.newLead,
    );
  }
}
