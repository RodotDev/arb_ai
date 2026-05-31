// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  String? apiKey = Platform.environment['ARB_AI_API_KEY'];
  if (apiKey == null) {
    final envFile = File('.env');
    if (await envFile.exists()) {
      final lines = await envFile.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('ARB_AI_API_KEY=')) {
          apiKey = trimmed.substring('ARB_AI_API_KEY='.length).trim();
          if ((apiKey.startsWith('"') && apiKey.endsWith('"')) ||
              (apiKey.startsWith("'") && apiKey.endsWith("'"))) {
            apiKey = apiKey.substring(1, apiKey.length - 1);
          }
          break;
        }
      }
    }
  }

  if (apiKey == null) {
    print('ARB_AI_API_KEY environment variable or .env file entry is required.');
    exit(1);
  }

  final sourceFile = File('test/fixtures/spike/source_en.json');
  final sourceJson = jsonDecode(await sourceFile.readAsString()) as Map<String, dynamic>;

  // Extract only keys that aren't metadata for the translation payload
  final stringsToTranslate = <String, String>{};
  for (final key in sourceJson.keys) {
    if (!key.startsWith('@')) {
      stringsToTranslate[key] = sourceJson[key] as String;
    }
  }

  // We translate to Portuguese, Polish, and Arabic to test different plural rules
  final targetLanguages = ['pt', 'pl', 'ar'];

  for (final lang in targetLanguages) {
    print('--- Translating to $lang ---');
    await translateToLanguage(lang, stringsToTranslate, apiKey);
  }
}

Future<void> translateToLanguage(
  String languageCode,
  Map<String, String> strings,
  String apiKey,
) async {
  // Use gemini-3.5-flash for high-speed, cost-efficient translations
  const modelName = 'gemini-3.5-flash';
  final url = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
  );

  final prompt = '''
Translate the following application strings into the target language code "$languageCode".
Preserve all ICU syntax strictly (plurals, genders, selects).
Do not translate placeholder names inside curly braces like {name}.
For plurals, ensure you use the correct CLDR plural categories for the target language (e.g., zero, one, two, few, many, other).

Source strings (JSON):
${jsonEncode(strings)}
''';

  // Dynamically build responseSchema to force Gemini to output exactly the same keys as strings
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
          {'text': prompt}
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

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(requestBody),
  );

  if (response.statusCode != 200) {
    print('Error: ${response.statusCode}');
    print(response.body);
    return;
  }

  final responseData = jsonDecode(response.body) as Map<String, dynamic>;
  final candidates = responseData['candidates'] as List<dynamic>;
  if (candidates.isEmpty) {
    print('No candidates returned');
    return;
  }

  final content = candidates[0]['content'] as Map<String, dynamic>;
  final parts = content['parts'] as List<dynamic>;
  if (parts.isEmpty) {
    print('No parts returned');
    return;
  }

  final translatedContent = parts[0]['text'] as String;

  print('Translated JSON for $languageCode:');
  print(translatedContent);
  print('\n');
}

