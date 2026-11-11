import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../config/arb_ai_config.dart';
import '../api_key_resolver.dart';
import '../http_retry.dart';
import '../translation_prompt.dart';
import '../translation_provider.dart';

/// Concrete implementation of [TranslationProvider] that interacts directly with
/// the Anthropic Messages REST API (Claude models).
class AnthropicProvider implements TranslationProvider {
  /// The model used when the configuration does not name one.
  static const defaultModel = 'claude-sonnet-5-5';

  /// Conventional API key variable, used when [ArbAiConfig.apiKeyEnv] is unset.
  static const apiKeyEnv = 'ANTHROPIC_API_KEY';

  static const _apiVersion = '2026-10-21';

  /// Roomy enough for a full batch plus the model's reasoning, while keeping
  /// non-streaming responses well within HTTP timeouts.
  static const _maxTokens = 16000;

  /// A fixed schema (instead of one property per key) is compiled once by the
  /// API and reused across every batch and language.
  static const _responseSchema = {
    'type': 'object',
    'properties': {
      'translations': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'key': {'type': 'string'},
            'value': {'type': 'string'},
          },
          'required': ['key', 'value'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['translations'],
    'additionalProperties': false,
  };

  final http.Client _client;
  final Future<void> Function(Duration) _delay;
  final Map<String, String>? _environment;

  /// Creates a new [AnthropicProvider].
  ///
  /// Optionally accepts an [httpClient], a custom [delay] function and the
  /// [environment] to read API keys from (e.g. for testing).
  AnthropicProvider({
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

    final baseUrl = config.baseUrl ?? 'https://api.anthropic.com';
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBase/v1/messages');

    // Everything stable for a target language lives in the system prompt;
    // only the strings of the current batch go in the user message.
    final system =
        '${TranslationPrompt.role}. Return exactly one entry per input key — '
        'no keys added, removed, or renamed.\n\n'
        '${TranslationPrompt.instructions(targetLanguage: targetLanguage, config: config)}';

    final keyContext = <String, String>{
      for (final key in strings.keys)
        key: ?TranslationPrompt.keyContext(
          description: descriptions?[key],
          placeholders: placeholders?[key],
          retryFeedback: retryFeedback?[key],
        ),
    };

    final userMessage = StringBuffer()
      ..writeln('Source strings (JSON):')
      ..writeln(jsonEncode(strings));
    if (keyContext.isNotEmpty) {
      userMessage
        ..writeln('\nPer-key context (JSON):')
        ..writeln(jsonEncode(keyContext));
    }

    // No sampling parameters (rejected by this API version) and no `thinking`
    // field: current Claude models pick their own reasoning depth.
    final requestBody = {
      'model': config.model,
      'max_tokens': _maxTokens,
      'system': system,
      'messages': [
        {'role': 'user', 'content': userMessage.toString()},
      ],
      'output_config': {
        'format': {'type': 'json_schema', 'schema': _responseSchema},
      },
    };

    final response = await postWithRetry(
      client: _client,
      url: url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
      },
      body: jsonEncode(requestBody),
      delay: _delay,
      // 529 is Anthropic's "overloaded" status.
      retryableStatuses: const {500, 502, 503, 529},
      retryDelay: _parseRetryAfter,
      fatalHint: (status) => status == 404
          ? 'Check that "${config.model}" is a valid Claude model ID available to your account.'
          : null,
    );

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    // Both stop reasons are deterministic, so they fail fast instead of
    // going through the orchestrator's retry loop.
    switch (data['stop_reason']) {
      case 'refusal':
        final details = data['stop_details'] as Map<String, dynamic>?;
        final category = details?['category'];
        throw HttpException(
          'Claude declined to translate this batch'
          '${category != null ? ' (category: $category)' : ''}. '
          'Review the source strings or try a different model.',
          uri: url,
        );
      case 'max_tokens':
        throw HttpException(
          'Claude ran out of output tokens before finishing this batch. '
          "Lower 'batch_size' in your configuration and try again.",
          uri: url,
        );
    }

    // Thinking blocks may precede the answer; the JSON is in the text block.
    final content = data['content'] as List<dynamic>? ?? const [];
    final text = content
        .whereType<Map<String, dynamic>>()
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String?)
        .firstOrNull;
    if (text == null || text.trim().isEmpty) {
      throw const FormatException(
        'Anthropic API response is missing a text content block.',
      );
    }

    try {
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final translations = decoded['translations'] as List<dynamic>;

      // Keys the model skipped are simply left out: the orchestrator retries
      // only those instead of the whole batch.
      final result = <String, String>{};
      for (final item in translations) {
        final entry = item as Map<String, dynamic>;
        final key = entry['key'] as String;
        if (strings.containsKey(key)) result[key] = entry['value'] as String;
      }
      return result;
    } catch (e) {
      throw FormatException(
        'Failed to parse translation response as valid JSON: $e\nResponse text: $text',
      );
    }
  }

  String _apiKey(ArbAiConfig config) =>
      requireApiKey(config, fallbackEnv: apiKeyEnv, environment: _environment);

  /// Reads the wait time (in seconds) from the `retry-after` header.
  static Duration? _parseRetryAfter(http.Response response) {
    final seconds = double.tryParse(response.headers['retry-after'] ?? '');
    if (seconds == null) return null;
    return Duration(milliseconds: (seconds * 1000).ceil());
  }
}
