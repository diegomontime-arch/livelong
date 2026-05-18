import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/core/errors/app_exception.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/firebase/firestore_mappers.dart';
import 'package:hitlook/data/models/ai_recommendation.dart';
import 'package:hitlook/data/repositories/ai_recommendation_repository.dart';
import 'package:hitlook/services/ai/ai_completion_service.dart';
import 'package:hitlook/services/firebase/firestore_service.dart';

class FirebaseAiRecommendationRepository implements AiRecommendationRepository {
  FirebaseAiRecommendationRepository({
    AiCompletionService? aiCompletionService,
  }) : _ai = aiCompletionService ?? HttpAiCompletionService();

  final AiCompletionService _ai;

  CollectionReference<Map<String, dynamic>> _recommendations(
    String companyId,
    String leadId,
  ) {
    return FirestoreService.collection(
      FirestorePaths.companyLeadRecommendations(companyId, leadId),
    );
  }

  @override
  Future<Result<AiRecommendation>> generateForLead({
    required String companyId,
    required String leadId,
    required String sellerId,
    required String locale,
    required Map<String, dynamic> answers,
    required int score,
    String? prospectName,
  }) async {
    final prompt = _buildPrompt(
      locale: locale,
      answers: answers,
      score: score,
      prospectName: prospectName,
    );

    final completion = await _ai.complete(
      systemPrompt: _systemPrompt(locale),
      messages: [
        {'role': 'user', 'content': prompt},
      ],
    );

    if (completion is Error<String>) {
      return Error(completion.failure);
    }

    final summary = (completion as Success<String>).value;

    return FirestoreMappers.guard(() async {
      final ref = _recommendations(companyId, leadId).doc();
      final payload = {
        'companyId': companyId,
        'leadId': leadId,
        'sellerId': sellerId,
        'summary': summary,
        'recommendedPlan': _extractPlanHint(summary),
        'score': score,
        'locale': locale,
        'rawResponse': summary,
      };

      await ref.set(FirestoreMappers.withCreatedTimestamps(payload));

      await FirestoreService.doc(FirestorePaths.companyLead(companyId, leadId)).set(
        {
          'recommendedPlan': payload['recommendedPlan'],
          'score': score,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final saved = await ref.get();
      return _fromSnapshot(saved.id, saved.data() ?? payload);
    });
  }

  @override
  Future<Result<AiRecommendation>> getLatest({
    required String companyId,
    required String leadId,
  }) {
    return FirestoreMappers.guard(() async {
      final snapshot = await _recommendations(companyId, leadId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw const NotFoundException('Recommendation not found');
      }

      final doc = snapshot.docs.first;
      return _fromSnapshot(doc.id, doc.data());
    });
  }

  @override
  Stream<List<AiRecommendation>> watchByLead({
    required String companyId,
    required String leadId,
  }) {
    return _recommendations(companyId, leadId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromSnapshot(doc.id, doc.data()))
              .toList(),
        );
  }

  AiRecommendation _fromSnapshot(String id, Map<String, dynamic> data) {
    return AiRecommendation.fromMap(id, {
      ...data,
      'createdAt': FirestoreMappers.timestampFrom(data['createdAt']),
    });
  }

  String _buildPrompt({
    required String locale,
    required Map<String, dynamic> answers,
    required int score,
    String? prospectName,
  }) {
    final name = prospectName ?? 'the prospect';
    return '''
Prospect: $name
Locale: $locale
Protection score: $score%
Answers: $answers

Write a concise recommendation summary (3-4 sentences) and suggest one plan type.
Do not name specific insurers or products.
''';
  }

  String _systemPrompt(String locale) {
    final language = switch (locale) {
      'es' => 'Spanish',
      'en' => 'English',
      _ => 'Portuguese',
    };
    return '''
You are Ana, a financial education assistant for Latino families in the US.
Respond in $language.
Never recommend a specific insurer or product by name.
Focus on education and next steps.
''';
  }

  String? _extractPlanHint(String summary) {
    final lower = summary.toLowerCase();
    if (lower.contains('term')) return 'term_life';
    if (lower.contains('whole') || lower.contains('permanent')) {
      return 'whole_life';
    }
    if (lower.contains('universal')) return 'universal_life';
    return null;
  }
}
