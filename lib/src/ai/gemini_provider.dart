import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/arb_ai_config.dart';
import 'translation_provider.dart';

/// Concrete implementation of [TranslationProvider] that interacts directly with
/// the Google Gemini Native REST API.
class GeminiProvider implements TranslationProvider {
  final http.Client _client;
  final Future<void> Function(Duration) _delay;

  /// Creates a new [GeminiProvider].
  ///
  /// Optionally accepts an [httpClient] and a custom [delay] function (e.g. for testing).
  GeminiProvider({
    http.Client? httpClient,
    Future<void> Function(Duration)? delay,
  })  : _client = httpClient ?? http.Client(),
        _delay = delay ?? Future.delayed;

  @override
  Future<Map<String, String>> translate({
    required Map<String, String> strings,
    required String targetLanguage,
    required ArbAiConfig config,
    Map<String, String>? descriptions,
    Map<String, Map<String, dynamic>>? placeholders,
  }) async {
    if (strings.isEmpty) return {};

    final apiKey = _getApiKey(config.apiKeyEnv);
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'API key not found in environment variable "${config.apiKeyEnv}" or a local .env file.',
      );
    }

    final baseUrl = config.baseUrl ?? 'https://generativelanguage.googleapis.com';
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBase/v1beta/models/${config.model}:generateContent?key=$apiKey');

    // Build the detailed prompt enforcing ICU preservation, glossary, tone, and exclusions
    final promptBuffer = StringBuffer();
    promptBuffer.writeln('Translate the following application strings into the target language code "$targetLanguage".');
    promptBuffer.writeln('Preserve all ICU syntax strictly (plurals, genders, selects).');
    promptBuffer.writeln('Do not translate placeholder names inside curly braces like {name}.');
    promptBuffer.writeln('Do not translate or alter special ARB tag placeholders starting with \'@\' inside curly braces, such as {@<b>} or {@</b>}.');
    promptBuffer.writeln('For plurals, ensure you use the correct CLDR plural categories for the target language (e.g., zero, one, two, few, many, other).');

    // Inject contextual descriptions and placeholder examples/descriptions if available
    final contextBuffer = StringBuffer();
    for (final key in strings.keys) {
      final desc = descriptions?[key];
      final keyPlaceholders = placeholders?[key];

      if ((desc != null && desc.isNotEmpty) || (keyPlaceholders != null && keyPlaceholders.isNotEmpty)) {
        contextBuffer.writeln('- "$key":');
        if (desc != null && desc.isNotEmpty) {
          contextBuffer.writeln('  - Description: $desc');
        }
        if (keyPlaceholders != null && keyPlaceholders.isNotEmpty) {
          keyPlaceholders.forEach((phName, phMetadata) {
            if (phMetadata is Map<String, dynamic>) {
              final phDesc = phMetadata['description'];
              final phExample = phMetadata['example'];
              if (phDesc != null || phExample != null) {
                contextBuffer.write('  - Placeholder "$phName":');
                if (phDesc != null) contextBuffer.write(' Description: $phDesc.');
                if (phExample != null) contextBuffer.write(' Example value: $phExample.');
                contextBuffer.writeln();
              }
            }
          });
        }
      }
    }

    if (contextBuffer.isNotEmpty) {
      promptBuffer.writeln('\nContext & Placeholders metadata for each translation key:');
      promptBuffer.write(contextBuffer.toString());
    }

    if (config.tone != null && config.tone!.isNotEmpty) {
      promptBuffer.writeln('Use a ${config.tone} tone for the translation.');
    }

    if (config.doNotTranslate.isNotEmpty) {
      promptBuffer.writeln('Do NOT translate the following terms (keep them exactly as they are):');
      for (final term in config.doNotTranslate) {
        promptBuffer.writeln('- $term');
      }
    }

    final langGlossary = config.glossary[targetLanguage];
    if (langGlossary != null && langGlossary.isNotEmpty) {
      promptBuffer.writeln('Strictly apply the following glossary mappings if the term/concept matches:');
      langGlossary.forEach((key, value) {
        promptBuffer.writeln('- "$key" must be translated as "$value"');
      });
    }

    promptBuffer.writeln('\nSource strings (JSON):');
    promptBuffer.writeln(jsonEncode(strings));

    // Dynamically build responseSchema to force Gemini to output exactly the same keys
    final schemaProperties = <String, Map<String, String>>{};
    final requiredKeys = <String>[];
    for (final key in strings.keys) {
      schemaProperties[key] = {'type': 'STRING'};
      requiredKeys.add(key);
    }

    final responseSchema = {
      'type': 'OBJECT',
      'properties': schemaProperties,
      'required': requiredKeys,
    };

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': promptBuffer.toString()}
          ]
        }
      ],
      'systemInstruction': {
        'parts': [
          {
            'text':
                'You are an expert software localizer. You strictly translate user-provided JSON strings while mathematically preserving ICU syntax, placeholders, and returning a flat JSON object with the exact same keys.'
          }
        ]
      },
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
        'temperature': 0.1,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
      ]
    };

    final bodyJson = jsonEncode(requestBody);
    final headers = {'Content-Type': 'application/json'};

    http.Response? response;
    int attempt = 0;
    const maxRetries = 5;

    while (attempt < maxRetries) {
      try {
        response = await _client.post(url, headers: headers, body: bodyJson);
        if (response.statusCode == 200) {
          break;
        } else if (response.statusCode == 429) {
          attempt++;
          if (attempt >= maxRetries) {
            throw HttpException(
              'Failed after $maxRetries retries with status 429 (Too Many Requests). Last body: ${response.body}',
              uri: url,
            );
          }
          final backoffSeconds = 1 << attempt; // 2, 4, 8, 16 seconds
          await _delay(Duration(seconds: backoffSeconds));
          continue;
        } else {
          throw HttpException(
            'Failed with status ${response.statusCode}: ${response.body}',
            uri: url,
          );
        }
      } catch (e) {
        if (e is HttpException || e is StateError) {
          rethrow;
        }
        throw HttpException('Network or connection error occurred: $e', uri: url);
      }
    }

    if (response == null || response.statusCode != 200) {
      throw HttpException('Failed to get successful response from Gemini API.', uri: url);
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException('Gemini API returned no candidates in response.');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    if (content == null) {
      throw const FormatException('Gemini API candidate response is missing content.');
    }

    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw const FormatException('Gemini API content response is missing parts.');
    }

    final part = parts[0] as Map<String, dynamic>;
    final text = part['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Gemini API content part response is missing text.');
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
          throw FormatException('Response value for key "$key" is not a string.');
        }
        result[key] = val;
      }
      return result;
    } catch (e) {
      throw FormatException('Failed to parse translation response as a valid JSON map: $e\nResponse text: $text');
    }
  }

  /// Helper to fetch the API key from environment or fallback to a local .env file.
  String? _getApiKey(String keyEnv) {
    final envVal = Platform.environment[keyEnv];
    if (envVal != null && envVal.isNotEmpty) {
      return envVal;
    }

    final envFile = File('.env');
    if (envFile.existsSync()) {
      try {
        final lines = envFile.readAsLinesSync();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('$keyEnv=')) {
            var val = trimmed.substring('$keyEnv='.length).trim();
            if ((val.startsWith('"') && val.endsWith('"')) ||
                (val.startsWith("'") && val.endsWith("'"))) {
              val = val.substring(1, val.length - 1);
            }
            return val;
          }
        }
      } catch (_) {
        // Silently ignore file reading errors
      }
    }

    return null;
  }
}
