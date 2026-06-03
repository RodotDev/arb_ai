import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';
import 'package:arb_ai/arb_ai.dart';

void main() {
  group('TranslationBatcher', () {
    test('chunks empty map to empty list', () {
      final result = TranslationBatcher.chunk({});
      check(result).isEmpty();
    });

    test('chunks correctly according to maxKeys', () {
      final input = {
        'k1': 'v1',
        'k2': 'v2',
        'k3': 'v3',
        'k4': 'v4',
        'k5': 'v5',
      };

      final chunked = TranslationBatcher.chunk(input, maxKeys: 2);
      check(chunked).length.equals(3);
      check(chunked[0]).deepEquals({'k1': 'v1', 'k2': 'v2'});
      check(chunked[1]).deepEquals({'k3': 'v3', 'k4': 'v4'});
      check(chunked[2]).deepEquals({'k5': 'v5'});
    });

    test('throws ArgumentError on invalid maxKeys', () {
      check(
        () => TranslationBatcher.chunk({'k1': 'v1'}, maxKeys: 0),
      ).throws<ArgumentError>();
      check(
        () => TranslationBatcher.chunk({'k1': 'v1'}, maxKeys: -1),
      ).throws<ArgumentError>();
    });
  });

  group('GeminiProvider', () {
    late String? originalEnvContent;
    final envFile = File('.env');

    setUpAll(() {
      if (envFile.existsSync()) {
        originalEnvContent = envFile.readAsStringSync();
      } else {
        originalEnvContent = null;
      }
      // Write a standard mock .env for tests
      envFile.writeAsStringSync('TEST_ARB_AI_API_KEY=mock-api-key\n');
    });

    tearDownAll(() {
      if (originalEnvContent != null) {
        envFile.writeAsStringSync(originalEnvContent!);
      } else {
        if (envFile.existsSync()) {
          envFile.deleteSync();
        }
      }
    });

    const config = ArbAiConfig(
      provider: 'gemini',
      apiKeyEnv: 'TEST_ARB_AI_API_KEY',
      model: 'gemini-3.5-flash',
      sourceArb: 'lib/l10n/app_en.arb',
      targets: ['pt', 'es'],
      glossary: {
        'pt': {'hello': 'olá'},
        'es': {'hello': 'hola'},
      },
      doNotTranslate: ['Flutter'],
      tone: 'formal',
    );

    test('returns empty map on empty strings input without api call', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('', 200);
      });

      final provider = GeminiProvider(httpClient: mockClient);
      final result = await provider.translate(
        strings: {},
        targetLanguage: 'pt',
        config: config,
      );

      check(result).isEmpty();
      check(callCount).equals(0);
    });

    test(
      'throws StateError when api key environment variable is not present',
      () async {
        final mockClient = MockClient(
          (request) async => http.Response('', 200),
        );
        final provider = GeminiProvider(httpClient: mockClient);

        try {
          await provider.translate(
            strings: {'key': 'value'},
            targetLanguage: 'pt',
            config: config.copyWith(apiKeyEnv: 'NON_EXISTENT_KEY_123'),
          );
          fail('Expected StateError');
        } on StateError catch (_) {
          // Success
        }
      },
    );

    test(
      'performs successful translation with correct payload structure',
      () async {
        final mockClient = MockClient((request) async {
          check(request.url.scheme).equals('https');
          check(request.url.host).equals('generativelanguage.googleapis.com');
          check(
            request.url.path,
          ).equals('/v1beta/models/gemini-3.5-flash:generateContent');

          // The API key must be sent via header, never in the URL query string,
          // to avoid leaking it through logged URIs or exception messages.
          check(request.url.queryParameters.containsKey('key')).isFalse();
          check(request.headers['x-goog-api-key']).equals('mock-api-key');
          check(request.headers['Content-Type']).equals('application/json');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          check(body.keys).contains('contents');
          check(body.keys).contains('systemInstruction');
          check(body.keys).contains('generationConfig');
          check(body.keys).contains('safetySettings');

          // Check prompt contains glossary, tone, and doNotTranslate instructions
          final prompt = body['contents'][0]['parts'][0]['text'] as String;
          check(prompt).contains('pt');
          check(prompt).contains('formal');
          check(prompt).contains('Flutter');
          check(prompt).contains('hello');
          check(prompt).contains('olá');
          check(prompt).not((it) => it.contains('hola'));

          // Check responseSchema is configured correctly
          final genConfig = body['generationConfig'] as Map<String, dynamic>;
          check(genConfig['responseMimeType']).equals('application/json');
          final responseSchema =
              genConfig['responseSchema'] as Map<String, dynamic>;
          check(responseSchema['type']).equals('OBJECT');
          check(
            (responseSchema['required'] as List).cast<String>(),
          ).contains('welcome');
          check(
            responseSchema['properties']['welcome']['type'],
          ).equals('STRING');

          final mockResponseBody = {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({'welcome': 'Bem-vindo!'}),
                    },
                  ],
                },
              },
            ],
          };

          return http.Response(jsonEncode(mockResponseBody), 200);
        });

        final provider = GeminiProvider(httpClient: mockClient);
        final result = await provider.translate(
          strings: {'welcome': 'Welcome!'},
          targetLanguage: 'pt',
          config: config,
        );

        check(result).deepEquals({'welcome': 'Bem-vindo!'});
      },
    );

    test('segregates glossary terms per target language in prompt', () async {
      // Spanish Translation Test
      final mockClientEs = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final prompt = body['contents'][0]['parts'][0]['text'] as String;

        check(prompt).contains('es');
        check(prompt).contains('hello');
        check(prompt).contains('hola');
        check(prompt).not((it) => it.contains('olá'));

        final mockResponseBody = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({'welcome': '¡Bienvenido!'}),
                  },
                ],
              },
            },
          ],
        };
        return http.Response(jsonEncode(mockResponseBody), 200);
      });

      final providerEs = GeminiProvider(httpClient: mockClientEs);
      final resultEs = await providerEs.translate(
        strings: {'welcome': 'Welcome!'},
        targetLanguage: 'es',
        config: config,
      );
      check(resultEs).deepEquals({'welcome': '¡Bienvenido!'});

      // No glossary for Polish Test
      final mockClientPl = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final prompt = body['contents'][0]['parts'][0]['text'] as String;

        check(prompt).contains('pl');
        check(prompt).not(
          (it) => it.contains('Strictly apply the following glossary mappings'),
        );
        check(prompt).not((it) => it.contains('hello'));

        final mockResponseBody = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({'welcome': 'Witaj!'}),
                  },
                ],
              },
            },
          ],
        };
        return http.Response(jsonEncode(mockResponseBody), 200);
      });

      final providerPl = GeminiProvider(httpClient: mockClientPl);
      final resultPl = await providerPl.translate(
        strings: {'welcome': 'Welcome!'},
        targetLanguage: 'pl',
        config: config,
      );
      check(resultPl).deepEquals({'welcome': 'Witaj!'});
    });

    test(
      'injects contextual metadata into responseSchema and ICU preservation into prompt',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final prompt = body['contents'][0]['parts'][0]['text'] as String;

          // Check that placeholder and ICU preservation instructions are present
          check(
            prompt,
          ).contains('Never translate placeholder or variable names.');
          check(prompt).contains(
            'For plural and select expressions, translate ONLY the human-readable',
          );

          // Check that the metadata is injected directly into responseSchema description
          final genConfig = body['generationConfig'] as Map<String, dynamic>;
          final responseSchema =
              genConfig['responseSchema'] as Map<String, dynamic>;
          final welcomeSchema =
              responseSchema['properties']['welcome'] as Map<String, dynamic>;

          check(
            welcomeSchema['description'] as String,
          ).contains('Context: Welcome message shown at homepage.');
          check(welcomeSchema['description'] as String).contains(
            'Placeholders info: {name} (desc: User\'s display name, example: John Doe)',
          );

          final mockResponseBody = {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({'welcome': 'Bem-vindo, {name}!'}),
                    },
                  ],
                },
              },
            ],
          };
          return http.Response(jsonEncode(mockResponseBody), 200);
        });

        final provider = GeminiProvider(httpClient: mockClient);
        final result = await provider.translate(
          strings: {'welcome': 'Welcome, {name}!'},
          targetLanguage: 'pt',
          config: config,
          descriptions: {'welcome': 'Welcome message shown at homepage'},
          placeholders: {
            'welcome': {
              'name': {
                'description': "User's display name",
                'example': 'John Doe',
              },
            },
          },
        );

        check(result).deepEquals({'welcome': 'Bem-vindo, {name}!'});
      },
    );

    test('implements exponential backoff on 429 rate limit error', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('Rate limit exceeded', 429);
        }
        final mockResponseBody = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({'key': 'value_pt'}),
                  },
                ],
              },
            },
          ],
        };
        return http.Response(jsonEncode(mockResponseBody), 200);
      });

      final recordedDelays = <Duration>[];
      final provider = GeminiProvider(
        httpClient: mockClient,
        delay: (duration) async {
          recordedDelays.add(duration);
        },
      );

      final result = await provider.translate(
        strings: {'key': 'value'},
        targetLanguage: 'pt',
        config: config,
      );

      check(result).deepEquals({'key': 'value_pt'});
      check(callCount).equals(2);
      check(recordedDelays).length.equals(1);
      check(recordedDelays[0].inSeconds).equals(2); // 1 << 1
    });

    test('throws HttpException after maximum 429 retries', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('Rate limit exceeded', 429);
      });

      final recordedDelays = <Duration>[];
      final provider = GeminiProvider(
        httpClient: mockClient,
        delay: (duration) async {
          recordedDelays.add(duration);
        },
      );

      try {
        await provider.translate(
          strings: {'key': 'value'},
          targetLanguage: 'pt',
          config: config,
        );
        fail('Expected HttpException');
      } on HttpException catch (e) {
        check(e.message).contains('Failed after 5 retries with status 429');
      }

      check(callCount).equals(5);
      check(
        recordedDelays,
      ).length.equals(4); // delays after attempts 1, 2, 3, 4
      check(
        recordedDelays.map((d) => d.inSeconds).toList(),
      ).deepEquals([2, 4, 8, 16]);
    });

    test('throws HttpException on non-200 / non-429 server errors', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final provider = GeminiProvider(
        httpClient: mockClient,
        delay: (duration) async {},
      );

      try {
        await provider.translate(
          strings: {'key': 'value'},
          targetLanguage: 'pt',
          config: config,
        );
        fail('Expected HttpException');
      } on HttpException catch (e) {
        check(e.message).contains('Failed after 5 retries with status 500');
        check(e.message).contains('Internal Server Error');
      }
    });

    test(
      'throws FormatException on malformed json or missing key in response',
      () async {
        final mockClient = MockClient((request) async {
          final mockResponseBody = {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{invalid json'},
                  ],
                },
              },
            ],
          };
          return http.Response(jsonEncode(mockResponseBody), 200);
        });

        final provider = GeminiProvider(httpClient: mockClient);

        try {
          await provider.translate(
            strings: {'key': 'value'},
            targetLanguage: 'pt',
            config: config,
          );
          fail('Expected FormatException');
        } on FormatException catch (_) {
          // Success
        }
      },
    );

    test(
      'expands regional targetLanguage code into human-friendly name in prompt',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final prompt = body['contents'][0]['parts'][0]['text'] as String;

          check(prompt).contains('"pt_BR" (Brazilian Portuguese)');

          final mockResponseBody = {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({'welcome': 'Bem-vindo!'}),
                    },
                  ],
                },
              },
            ],
          };
          return http.Response(jsonEncode(mockResponseBody), 200);
        });

        final provider = GeminiProvider(httpClient: mockClient);
        await provider.translate(
          strings: {'welcome': 'Welcome!'},
          targetLanguage: 'pt_BR',
          config: config,
        );
      },
    );

    test(
      'performs smart glossary lookup with targetLanguage region and base fallbacks',
      () async {
        final customConfig = config.copyWith(
          glossary: {
            'pt': {'hello': 'olá_base'},
            'pt-br': {'hello': 'olá_regional'},
          },
        );

        // 1. Should use regional exact match (pt_BR matching pt-br)
        final mockClientRegional = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final prompt = body['contents'][0]['parts'][0]['text'] as String;
          check(prompt).contains('olá_regional');
          check(prompt).not((it) => it.contains('olá_base'));

          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({'hello': 'olá_regional'}),
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final providerRegional = GeminiProvider(httpClient: mockClientRegional);
        await providerRegional.translate(
          strings: {'hello': 'hello'},
          targetLanguage: 'pt_BR',
          config: customConfig,
        );

        // 2. Should use base fallback when regional matches nothing (e.g. pt_PT matching pt)
        final mockClientFallback = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final prompt = body['contents'][0]['parts'][0]['text'] as String;
          check(prompt).contains('olá_base');
          check(prompt).not((it) => it.contains('olá_regional'));

          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({'hello': 'olá_base'}),
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final providerFallback = GeminiProvider(httpClient: mockClientFallback);
        await providerFallback.translate(
          strings: {'hello': 'hello'},
          targetLanguage: 'pt_PT',
          config: customConfig,
        );
      },
    );
  });
}
