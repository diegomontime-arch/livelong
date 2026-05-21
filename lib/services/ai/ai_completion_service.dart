import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hitlook/core/config/app_config.dart';
import 'package:hitlook/core/errors/failure.dart';
import 'package:hitlook/core/utils/result.dart';

/// Calls the hosted Anthropic proxy. API keys stay server-side.
abstract interface class AiCompletionService {
  Future<Result<String>> complete({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    int maxTokens,
  });
}

class HttpAiCompletionService implements AiCompletionService {
  HttpAiCompletionService({http.Client? client, String? proxyUrl})
      : _client = client ?? http.Client(),
        _proxyUrl = proxyUrl ?? AppConfig.anthropicProxyUrl;

  final http.Client _client;
  final String _proxyUrl;

  @override
  Future<Result<String>> complete({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    int maxTokens = 600,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(_proxyUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': maxTokens,
          'system': systemPrompt,
          'messages': messages,
        }),
      );

      if (response.statusCode != 200) {
        return Error(NetworkFailure('AI service returned ${response.statusCode}'));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>?;
      final text = content?.isNotEmpty == true
          ? (content!.first as Map<String, dynamic>)['text'] as String?
          : null;

      if (text == null || text.isEmpty) {
        return const Error(UnknownFailure('Empty AI response'));
      }
      return Success(text);
    } catch (e) {
      return Error(NetworkFailure(e.toString()));
    }
  }
}
