/// AI-generated plan recommendation stored for a lead.
class AiRecommendation {
  const AiRecommendation({
    required this.id,
    required this.companyId,
    required this.leadId,
    required this.sellerId,
    required this.summary,
    this.recommendedPlan,
    this.score,
    this.locale,
    this.rawResponse,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String leadId;
  final String sellerId;
  final String summary;
  final String? recommendedPlan;
  final int? score;
  final String? locale;
  final String? rawResponse;
  final DateTime? createdAt;

  factory AiRecommendation.fromMap(String id, Map<String, dynamic> map) {
    return AiRecommendation(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      leadId: map['leadId'] as String? ?? '',
      sellerId: map['sellerId'] as String? ?? map['agentId'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      recommendedPlan: map['recommendedPlan'] as String?,
      score: (map['score'] as num?)?.toInt(),
      locale: map['locale'] as String?,
      rawResponse: map['rawResponse'] as String?,
      createdAt: null,
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'leadId': leadId,
        'sellerId': sellerId,
        'summary': summary,
        if (recommendedPlan != null) 'recommendedPlan': recommendedPlan,
        if (score != null) 'score': score,
        if (locale != null) 'locale': locale,
        if (rawResponse != null) 'rawResponse': rawResponse,
      };
}
