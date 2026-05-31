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
    final expandedLang = _expandLanguageName(targetLanguage);
    final promptLangStr = expandedLang.toLowerCase() == targetLanguage.toLowerCase()
        ? '"$targetLanguage"'
        : '"$targetLanguage" ($expandedLang)';

    promptBuffer.writeln('Translate the following application strings into the target language code $promptLangStr.');
    promptBuffer.writeln('Preserve all ICU syntax strictly (plurals, genders, selects).');
    promptBuffer.writeln('Do not translate placeholder names inside curly braces like {name}.');
    promptBuffer.writeln('Do not translate or alter special ARB tag placeholders starting with \'@\' inside curly braces, such as {@<b>} or {@</b>}.');
    promptBuffer.writeln('For plurals, ensure you use the correct CLDR plural categories for the target language (e.g., zero, one, two, few, many, other).');

    // Build schema properties dynamically, injecting key-level descriptions and placeholder metadata directly into the JSON Schema property description for superior contextual focus.
    final schemaProperties = <String, Map<String, dynamic>>{};
    final requiredKeys = <String>[];

    for (final key in strings.keys) {
      final desc = descriptions?[key];
      final keyPlaceholders = placeholders?[key];

      final schemaDescBuffer = StringBuffer();
      if (desc != null && desc.isNotEmpty) {
        schemaDescBuffer.write('Context: $desc.');
      }
      if (keyPlaceholders != null && keyPlaceholders.isNotEmpty) {
        if (schemaDescBuffer.isNotEmpty) schemaDescBuffer.write(' ');
        schemaDescBuffer.write('Placeholders info:');
        keyPlaceholders.forEach((phName, phMetadata) {
          if (phMetadata is Map<String, dynamic>) {
            final phDesc = phMetadata['description'];
            final phExample = phMetadata['example'];
            schemaDescBuffer.write(' {$phName}');
            if (phDesc != null || phExample != null) {
              schemaDescBuffer.write(' (');
              if (phDesc != null) schemaDescBuffer.write('desc: $phDesc');
              if (phExample != null) schemaDescBuffer.write('${phDesc != null ? ", " : ""}example: $phExample');
              schemaDescBuffer.write(')');
            }
            schemaDescBuffer.write(';');
          }
        });
      }

      schemaProperties[key] = {
        'type': 'STRING',
        if (schemaDescBuffer.isNotEmpty) 'description': schemaDescBuffer.toString().trim(),
      };
      requiredKeys.add(key);
    }

    final responseSchema = {
      'type': 'OBJECT',
      'properties': schemaProperties,
      'required': requiredKeys,
    };

    if (config.tone != null && config.tone!.isNotEmpty) {
      promptBuffer.writeln('Use a ${config.tone} tone for the translation.');
    }

    if (config.doNotTranslate.isNotEmpty) {
      promptBuffer.writeln('Do NOT translate the following terms (keep them exactly as they are):');
      for (final term in config.doNotTranslate) {
        promptBuffer.writeln('- $term');
      }
    }

    // Smart glossary fallback lookup
    Map<String, String>? langGlossary;
    final normalizedTarget = targetLanguage.replaceAll('_', '-').toLowerCase();
    for (final entry in config.glossary.entries) {
      final key = entry.key.replaceAll('_', '-').toLowerCase();
      if (key == normalizedTarget) {
        langGlossary = entry.value;
        break;
      }
    }
    // Base language fallback (e.g. if target is pt-BR, try lookup for pt)
    if (langGlossary == null) {
      final baseTarget = targetLanguage.split(RegExp('[_-]'))[0].toLowerCase();
      for (final entry in config.glossary.entries) {
        final key = entry.key.replaceAll('_', '-').toLowerCase();
        if (key == baseTarget) {
          langGlossary = entry.value;
          break;
        }
      }
    }

    if (langGlossary != null && langGlossary.isNotEmpty) {
      promptBuffer.writeln('Strictly apply the following glossary mappings if the term/concept matches:');
      langGlossary.forEach((key, value) {
        promptBuffer.writeln('- "$key" must be translated as "$value"');
      });
    }

    promptBuffer.writeln('\nSource strings (JSON):');
    promptBuffer.writeln(jsonEncode(strings));

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

  /// Expands language codes (especially regional ones like pt_BR or es_419) into human-friendly names.
  static String _expandLanguageName(String langCode) {
    final normalized = langCode.replaceAll('_', '-').toLowerCase();
    switch (normalized) {
      case 'pt':
        return 'Portuguese';
      case 'pt-br':
        return 'Brazilian Portuguese';
      case 'es':
        return 'Spanish';
      case 'es-419':
        return 'Latin American Spanish';
      case 'zh':
        return 'Chinese';
      case 'zh-hans':
        return 'Simplified Chinese';
      case 'zh-hant':
        return 'Traditional Chinese';
      case 'en':
        return 'English';
      case 'en-us':
        return 'American English';
      case 'en-gb':
        return 'British English';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'ru':
        return 'Russian';
      case 'pl':
        return 'Polish';
      case 'ar':
        return 'Arabic';
      default:
        final parts = normalized.split('-');
        if (parts.length > 1) {
          final base = parts[0];
          final region = parts[1].toUpperCase();
          final baseName = _expandLanguageName(base);
          return '$baseName (Region: $region)';
        }
        return langCode;
    }
  }
}
