import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/ai_recommendation.dart';

abstract interface class AiRecommendationRepository {
  Future<Result<AiRecommendation>> generateForLead({
    required String companyId,
    required String leadId,
    required String sellerId,
    required String locale,
    required Map<String, dynamic> answers,
    required int score,
    String? prospectName,
  });

  Future<Result<AiRecommendation>> getLatest({
    required String companyId,
    required String leadId,
  });

  Stream<List<AiRecommendation>> watchByLead({
    required String companyId,
    required String leadId,
  });
}
