import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:arb_ai/arb_ai.dart';

void main() {
  group('TranslationBatcher', () {
    test('chunks empty map to empty list', () {
      final result = TranslationBatcher.chunk({});
      expect(result, isEmpty);
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
      expect(chunked, hasLength(3));
      expect(chunked[0], {'k1': 'v1', 'k2': 'v2'});
      expect(chunked[1], {'k3': 'v3', 'k4': 'v4'});
      expect(chunked[2], {'k5': 'v5'});
    });

    test('throws ArgumentError on invalid maxKeys', () {
      expect(
        () => TranslationBatcher.chunk({'k1': 'v1'}, maxKeys: 0),
        throwsArgumentError,
      );
      expect(
        () => TranslationBatcher.chunk({'k1': 'v1'}, maxKeys: -1),
        throwsArgumentError,
      );
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

      expect(result, isEmpty);
      expect(callCount, 0);
    });

    test(
      'throws StateError when api key environment variable is not present',
      () async {
        final mockClient = MockClient(
          (request) async => http.Response('', 200),
        );
        final provider = GeminiProvider(httpClient: mockClient);

        await expectLater(
          provider.translate(
            strings: {'key': 'value'},
            targetLanguage: 'pt',
            config: config.copyWith(apiKeyEnv: 'NON_EXISTENT_KEY_123'),
          ),
          throwsStateError,
        );
      },
    );

    test(
      'performs successful translation with correct payload structure',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'generativelanguage.googleapis.com');
          expect(
            request.url.path,
            '/v1beta/models/gemini-3.5-flash:generateContent',
          );
          // The API key must be sent via header, never in the URL query string,
          // to avoid leaking it through logged URIs or exception messages.
          expect(request.url.queryParameters.containsKey('key'), isFalse);
          expect(request.headers['x-goog-api-key'], 'mock-api-key');
          expect(request.headers['Content-Type'], 'application/json');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, contains('contents'));
          expect(body, contains('systemInstruction'));
          expect(body, contains('generationConfig'));
          expect(body, contains('safetySettings'));

          // Check prompt contains glossary, tone, and doNotTranslate instructions
          final prompt = body['contents'][0]['parts'][0]['text'] as String;
          expect(prompt, contains('pt'));
          expect(prompt, contains('formal'));
          expect(prompt, contains('Flutter'));
          expect(prompt, contains('hello'));
          expect(prompt, contains('olá'));
          expect(prompt, isNot(contains('hola')));

          // Check responseSchema is configured correctly
          final genConfig = body['generationConfig'] as Map<String, dynamic>;
          expect(genConfig['responseMimeType'], 'application/json');
          final responseSchema =
              genConfig['responseSchema'] as Map<String, dynamic>;
          expect(responseSchema['type'], 'OBJECT');
          expect(responseSchema['required'], contains('welcome'));
          expect(responseSchema['properties']['welcome']['type'], 'STRING');

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

        expect(result, {'welcome': 'Bem-vindo!'});
      },
    );

    test('segregates glossary terms per target language in prompt', () async {
      // Spanish Translation Test
      final mockClientEs = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final prompt = body['contents'][0]['parts'][0]['text'] as String;

        expect(prompt, contains('es'));
        expect(prompt, contains('hello'));
        expect(prompt, contains('hola'));
        expect(prompt, isNot(contains('olá')));

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
      expect(resultEs, {'welcome': '¡Bienvenido!'});

      // No glossary for Polish Test
      final mockClientPl = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final prompt = body['contents'][0]['parts'][0]['text'] as String;

        expect(prompt, contains('pl'));
        expect(
          prompt,
          isNot(contains('Strictly apply the following glossary mappings')),
        );
        expect(prompt, isNot(contains('hello')));

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
      expect(resultPl, {'welcome': 'Witaj!'});
    });

    test(
      'injects contextual metadata into responseSchema and ICU preservation into prompt',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final prompt = body['contents'][0]['parts'][0]['text'] as String;

          // Check that placeholder and ICU preservation instructions are present
          expect(
            prompt,
            contains('Never translate placeholder or variable names.'),
          );
          expect(
            prompt,
            contains(
              'For plural and select expressions, translate ONLY the human-readable',
            ),
          );

          // Check that the metadata is injected directly into responseSchema description
          final genConfig = body['generationConfig'] as Map<String, dynamic>;
          final responseSchema =
              genConfig['responseSchema'] as Map<String, dynamic>;
          final welcomeSchema =
              responseSchema['properties']['welcome'] as Map<String, dynamic>;

          expect(
            welcomeSchema['description'],
            contains('Context: Welcome message shown at homepage.'),
          );
          expect(
            welcomeSchema['description'],
            contains(
              'Placeholders info: {name} (desc: User\'s display name, example: John Doe)',
            ),
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

        expect(result, {'welcome': 'Bem-vindo, {name}!'});
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

      expect(result, {'key': 'value_pt'});
      expect(callCount, 2);
      expect(recordedDelays, hasLength(1));
      expect(recordedDelays[0].inSeconds, 2); // 1 << 1
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

      await expectLater(
        provider.translate(
          strings: {'key': 'value'},
          targetLanguage: 'pt',
          config: config,
        ),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            contains('Failed after 5 retries with status 429'),
          ),
        ),
      );

      expect(callCount, 5);
      expect(recordedDelays, hasLength(4)); // delays after attempts 1, 2, 3, 4
      expect(recordedDelays.map((d) => d.inSeconds), [2, 4, 8, 16]);
    });

    test('throws HttpException on non-200 / non-429 server errors', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final provider = GeminiProvider(httpClient: mockClient);

      await expectLater(
        provider.translate(
          strings: {'key': 'value'},
          targetLanguage: 'pt',
          config: config,
        ),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            contains('Failed with status 500: Internal Server Error'),
          ),
        ),
      );
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

        await expectLater(
          provider.translate(
            strings: {'key': 'value'},
            targetLanguage: 'pt',
            config: config,
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'expands regional targetLanguage code into human-friendly name in prompt',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final prompt = body['contents'][0]['parts'][0]['text'] as String;

          expect(prompt, contains('"pt_BR" (Brazilian Portuguese)'));

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
          expect(prompt, contains('olá_regional'));
          expect(prompt, isNot(contains('olá_base')));

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
          expect(prompt, contains('olá_base'));
          expect(prompt, isNot(contains('olá_regional')));

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
