import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/arb_ai_config.dart';
import '../api_key_resolver.dart';
import '../http_retry.dart';
import '../translation_prompt.dart';
import '../translation_provider.dart';

/// Concrete implementation of [TranslationProvider] that interacts directly with
/// the Google Gemini Native REST API.
class GeminiProvider implements TranslationProvider {
  /// The model used when the configuration does not name one.
  static const defaultModel = 'gemini-3.5-flash';

  /// Conventional API key variable, used when [ArbAiConfig.apiKeyEnv] is unset.
  static const apiKeyEnv = 'GEMINI_API_KEY';

  final http.Client _client;
  final Future<void> Function(Duration) _delay;
  final Map<String, String>? _environment;

  /// Creates a new [GeminiProvider].
  ///
  /// Optionally accepts an [httpClient], a custom [delay] function and the
  /// [environment] to read API keys from (e.g. for testing).
  GeminiProvider({
    http.Client? httpClient,
    Future<void> Function(Duration)? delay,
    this._environment,
  }) : _client = httpClient ?? http.Client(),
       _delay = delay ?? Future.delayed;

  @override
  void validateEnvironment(ArbAiConfig config) => _apiKey(config);

  @override
  Future<Map<String, String>> translate({
    required Map<String, String> strings,
    required String targetLanguage,
    required ArbAiConfig config,
    Map<String, String>? descriptions,
    Map<String, Map<String, dynamic>>? placeholders,
    Map<String, String>? retryFeedback,
  }) async {
    if (strings.isEmpty) return {};

    final apiKey = _apiKey(config);

    final baseUrl =
        config.baseUrl ?? 'https://generativelanguage.googleapis.com';
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    // The API key is sent via the `x-goog-api-key` header (see below) rather
    // than the URL query string, so it never appears in request URIs, logs, or
    // exception messages (e.g. HttpException.toString() includes the uri).
    final url = Uri.parse(
      '$cleanBase/v1beta/models/${config.model}:generateContent',
    );

    final prompt = StringBuffer()
      ..write(
        TranslationPrompt.instructions(
          targetLanguage: targetLanguage,
          config: config,
        ),
      )
      ..writeln('\nSource strings (JSON):')
      ..writeln(jsonEncode(strings));

    // Key-level context goes into each JSON Schema property description,
    // which keeps the model focused on the key it is currently translating.
    final schemaProperties = <String, Map<String, dynamic>>{
      for (final key in strings.keys)
        key: {
          'type': 'STRING',
          'description': ?TranslationPrompt.keyContext(
            description: descriptions?[key],
            placeholders: placeholders?[key],
            retryFeedback: retryFeedback?[key],
          ),
        },
    };

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt.toString()},
          ],
        },
      ],
      'systemInstruction': {
        'parts': [
          {
            'text':
                '${TranslationPrompt.role}, and you return a flat JSON object containing exactly the same keys as the input — no keys added, removed, or renamed, and no commentary.',
          },
        ],
      },
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': schemaProperties,
          'required': strings.keys.toList(),
        },
        'temperature': 0.1,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_NONE',
        },
      ],
    };

    final response = await postWithRetry(
      client: _client,
      url: url,
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
      body: jsonEncode(requestBody),
      delay: _delay,
      retryDelay: (response) => _parseRetryDelay(response.body),
    );

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException(
        'Gemini API returned no candidates in response.',
      );
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    if (content == null) {
      throw const FormatException(
        'Gemini API candidate response is missing content.',
      );
    }

    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw const FormatException(
        'Gemini API content response is missing parts.',
      );
    }

    final part = parts[0] as Map<String, dynamic>;
    final text = part['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const FormatException(
        'Gemini API content part response is missing text.',
      );
    }

    try {
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final result = <String, String>{};
      for (final key in strings.keys) {
        if (!decoded.containsKey(key)) {
          throw FormatException('Response JSON is missing expected key: $key');
        }
        final val = decoded[key];
        if (val is! String) {
          throw FormatException(
            'Response value for key "$key" is not a string.',
          );
        }
        result[key] = val;
      }
      return result;
    } catch (e) {
      throw FormatException(
        'Failed to parse translation response as a valid JSON map: $e\nResponse text: $text',
      );
    }
  }

  String _apiKey(ArbAiConfig config) =>
      requireApiKey(config, fallbackEnv: apiKeyEnv, environment: _environment);

  /// Reads the `retryDelay` (e.g. "12.5s") from Gemini rate limit errors.
  static Duration? _parseRetryDelay(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final error = decoded['error'] as Map<String, dynamic>?;
    final details = error?['details'] as List<dynamic>? ?? const [];

    for (final detail in details) {
      if (detail is! Map<String, dynamic> ||
          detail['@type'] != 'type.googleapis.com/google.rpc.RetryInfo') {
        continue;
      }
      final delayStr = detail['retryDelay'] as String?;
      if (delayStr == null || !delayStr.endsWith('s')) continue;

      final seconds = double.tryParse(
        delayStr.substring(0, delayStr.length - 1),
      );
      if (seconds != null) {
        return Duration(milliseconds: (seconds * 1000).toInt());
      }
    }
    return null;
  }
}
