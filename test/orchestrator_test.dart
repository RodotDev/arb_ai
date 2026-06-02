import 'dart:convert';
import 'dart:io';
import 'package:arb_ai/arb_ai.dart';
import 'package:arb_ai/src/cli/logger.dart';
import 'package:test/test.dart';

class MockTranslationProvider implements TranslationProvider {
  final Function onTranslate;
  final bool failValidation;

  MockTranslationProvider(this.onTranslate, {this.failValidation = false});

  @override
  void validateEnvironment(ArbAiConfig config) {
    if (failValidation) {
      throw StateError('API key not found');
    }
  }

  @override
  Future<Map<String, String>> translate({
    required Map<String, String> strings,
    required String targetLanguage,
    required ArbAiConfig config,
    Map<String, String>? descriptions,
    Map<String, Map<String, dynamic>>? placeholders,
  }) async {
    dynamic result;
    try {
      result = await onTranslate(
        strings,
        targetLanguage,
        config,
        descriptions,
        placeholders,
      );
    } catch (_) {
      result = await onTranslate(strings, targetLanguage, config);
    }
    return Map<String, String>.from(result as Map);
  }
}

/// A silent logger to avoid cluttering test outputs.
class SilentLogger extends Logger {
  const SilentLogger() : super();

  @override
  void info(String message) {}
  @override
  void success(String message) {}
  @override
  void warning(String message) {}
  @override
  void error(String message) {}
  @override
  void debug(String message) {}
}

void main() {
  group('ArbAiOrchestrator Path Resolution', () {
    final orchestrator = ArbAiOrchestrator(
      config: ArbAiConfig.defaults(),
      logger: const SilentLogger(),
    );

    test('getTargetFile resolves standard _en source to target', () {
      final file = orchestrator.getTargetFile(
        '/path/to/app_en.arb',
        'pt',
        'en',
      );
      expect(file.path, equals('/path/to/app_pt.arb'));
    });

    test(
      'getTargetFile resolves source with different underscore locale structure',
      () {
        final file = orchestrator.getTargetFile(
          '/path/to/intl_en_US.arb',
          'pt',
          'en_US',
        );
        expect(file.path, equals('/path/to/intl_pt.arb'));
      },
    );

    test('getTargetFile falls back if source lacks matching locale suffix', () {
      // app.arb with target 'pt' becomes app_pt.arb
      final file = orchestrator.getTargetFile('/path/to/app.arb', 'pt', 'en');
      expect(file.path, equals('/path/to/app_pt.arb'));
    });
  });

  group('ArbAiOrchestrator Pipeline execution', () {
    late Directory tempDir;
    late File sourceFile;
    late File stateFile;
    late ArbAiConfig testConfig;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('orchestrator_test');
      sourceFile = File('${tempDir.path}/app_en.arb');
      stateFile = File('${tempDir.path}/.arb_ai_state.json');

      sourceFile.writeAsStringSync(
        jsonEncode({
          '@@locale': 'en',
          'welcome': 'Welcome, {name}!',
          '@welcome': {
            'description': 'Welcome message',
            'placeholders': {
              'name': {'type': 'String'},
            },
          },
          'inbox': '{count, plural, =0{No messages} other{{count} messages}}',
        }),
      );

      testConfig = ArbAiConfig(
        provider: 'gemini',
        apiKeyEnv: 'MOCK_API_KEY',
        model: 'gemini-3.5-flash',
        sourceArb: sourceFile.path,
        targets: ['pt'],
        glossary: {},
        doNotTranslate: [],
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
      'succeeds immediately and does not translate when targets is empty',
      () async {
        final configWithNoTargets = testConfig.copyWith(targets: []);
        final orchestrator = ArbAiOrchestrator(
          config: configWithNoTargets,
          logger: const SilentLogger(),
        );

        final success = await orchestrator.run();
        expect(success, isTrue);
      },
    );

    test(
      'performs dry-run without hitting provider or writing files',
      () async {
        var providerCalled = false;
        final provider = MockTranslationProvider((
          Map<String, String> strings,
          String targetLanguage,
          ArbAiConfig config,
        ) async {
          providerCalled = true;
          return <String, String>{};
        });

        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          provider: provider,
          logger: const SilentLogger(),
        );

        final success = await orchestrator.run(dryRun: true);
        expect(success, isTrue);
        expect(providerCalled, isFalse);

        final targetFile = orchestrator.getTargetFile(
          sourceFile.path,
          'pt',
          'en',
        );
        expect(targetFile.existsSync(), isFalse);
      },
    );

    test(
      'check mode returns false when translations are missing or outdated',
      () async {
        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          logger: const SilentLogger(),
        );

        final success = await orchestrator.run(check: true);
        expect(success, isFalse); // translations are missing
      },
    );

    test(
      'check mode returns true when all translations are fully in sync',
      () async {
        final targetFile = File('${tempDir.path}/app_pt.arb');
        targetFile.writeAsStringSync(
          jsonEncode({
            '@@locale': 'pt',
            'welcome': 'Bem-vindo, {name}!',
            'inbox':
                '{count, plural, =0{Sem mensagens} other{{count} mensagens}}',
          }),
        );

        // Establish correct hash in state manager
        final stateManager = ArbStateManager(stateFile);
        stateManager.updateState(
          targetLanguage: 'pt',
          key: 'welcome',
          sourceValue: 'Welcome, {name}!',
        );
        stateManager.updateState(
          targetLanguage: 'pt',
          key: 'inbox',
          sourceValue:
              '{count, plural, =0{No messages} other{{count} messages}}',
        );
        stateManager.save();

        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          logger: const SilentLogger(),
        );

        final success = await orchestrator.run(check: true);
        expect(success, isTrue);
      },
    );

    test('fails fast and throws StateError if environment validation fails', () async {
      final provider = MockTranslationProvider(
        (strings, targetLanguage, config, d, p) async => <String, String>{},
        failValidation: true,
      );

      final orchestrator = ArbAiOrchestrator(
        config: testConfig,
        provider: provider,
        logger: const SilentLogger(),
      );

      expect(
        () => orchestrator.run(),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'successfully translates, validates ICU, and writes deterministic output',
      () async {
        final provider = MockTranslationProvider((
          Map<String, String> strings,
          String targetLanguage,
          ArbAiConfig config,
        ) async {
          expect(targetLanguage, equals('pt'));
          expect(strings, contains('welcome'));
          expect(strings, contains('inbox'));

          return <String, String>{
            'welcome': 'Bem-vindo, {name}!',
            'inbox':
                '{count, plural, =0{Sem mensagens} other{{count} mensagens}}',
          };
        });

        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          provider: provider,
          logger: const SilentLogger(),
        );

        final success = await orchestrator.run();
        expect(success, isTrue);

        final targetFile = File('${tempDir.path}/app_pt.arb');
        expect(targetFile.existsSync(), isTrue);

        final targetContent = targetFile.readAsStringSync();
        final targetJson = jsonDecode(targetContent) as Map<String, dynamic>;

        expect(targetJson['@@locale'], equals('pt'));
        expect(targetJson['welcome'], equals('Bem-vindo, {name}!'));
        expect(
          targetJson['inbox'],
          equals('{count, plural, =0{Sem mensagens} other{{count} mensagens}}'),
        );
        // Determinism test: should have no @welcome metadata
        expect(targetJson.containsKey('@welcome'), isFalse);

        // Verify state manager updated state
        final manager = ArbStateManager(stateFile);
        expect(
          manager.isUpToDate(
            targetLanguage: 'pt',
            key: 'welcome',
            sourceValue: 'Welcome, {name}!',
            targetArb: ArbFile.parse(targetContent),
          ),
          isTrue,
        );
      },
    );

    test(
      'retries on validation failure and succeeds if subsequent attempt is valid',
      () async {
        var callCount = 0;
        final provider = MockTranslationProvider((
          strings,
          targetLanguage,
          config,
        ) async {
          callCount++;
          if (callCount == 1) {
            // Return a translation missing placeholder {name}
            return {
              'welcome': 'Bem-vindo!',
              'inbox':
                  '{count, plural, =0{Sem mensagens} other{{count} mensagens}}',
            };
          }
          // Succeed on subsequent call
          return {'welcome': 'Bem-vindo, {name}!'};
        });

        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          provider: provider,
          logger: const SilentLogger(),
        );

        final success = await orchestrator.run();
        expect(success, isTrue);
        expect(callCount, 2);

        final targetFile = File('${tempDir.path}/app_pt.arb');
        final targetJson =
            jsonDecode(targetFile.readAsStringSync()) as Map<String, dynamic>;
        expect(targetJson['welcome'], equals('Bem-vindo, {name}!'));
      },
    );

    test(
      'throws FormatException if ICU validation keeps failing after maximum retries',
      () async {
        var callCount = 0;
        final provider = MockTranslationProvider((
          strings,
          targetLanguage,
          config,
        ) async {
          callCount++;
          return {
            'welcome': 'Bem-vindo!', // missing {name}
            'inbox':
                '{count, plural, =0{Sem mensagens} other{{count} mensagens}}',
          };
        });

        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          provider: provider,
          logger: const SilentLogger(),
        );

        final success = await orchestrator.run();
        expect(success, isFalse);
        expect(callCount, 3); // maxRetries = 3
      },
    );

    test(
      'skips translating non-text resources (like type image) and copies them directly',
      () async {
        // 1. Write source file with a non-text image resource
        sourceFile.writeAsStringSync(
          jsonEncode({
            '@@locale': 'en',
            'welcome': 'Welcome!',
            'logo_path': 'images/logo.png',
            '@logo_path': {
              'type': 'image',
              'description': 'Main brand logo path',
            },
          }),
        );

        var providerCalledWithLogo = false;
        final provider = MockTranslationProvider((
          Map<String, String> strings,
          String targetLanguage,
          ArbAiConfig config,
          Map<String, String>? descriptions,
          Map<String, Map<String, dynamic>>? placeholders,
        ) async {
          if (strings.containsKey('logo_path')) {
            providerCalledWithLogo = true;
          }
          return {'welcome': 'Bem-vindo!'};
        });

        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          provider: provider,
          logger: const SilentLogger(),
        );

        final success = await orchestrator.run();
        expect(success, isTrue);
        expect(
          providerCalledWithLogo,
          isFalse,
        ); // Logo was not translated by the AI

        // 2. Assert logo_path was copied directly to target arb file
        final targetFile = File('${tempDir.path}/app_pt.arb');
        expect(targetFile.existsSync(), isTrue);
        final targetJson =
            jsonDecode(targetFile.readAsStringSync()) as Map<String, dynamic>;

        expect(targetJson['welcome'], equals('Bem-vindo!'));
        expect(
          targetJson['logo_path'],
          equals('images/logo.png'),
        ); // Kept original value
      },
    );

    test(
      'extracts descriptions and placeholders metadata and forwards them to provider',
      () async {
        sourceFile.writeAsStringSync(
          jsonEncode({
            '@@locale': 'en',
            'welcome': 'Welcome, {name}!',
            '@welcome': {
              'description': 'Homepage greeting message',
              'placeholders': {
                'name': {
                  'description': 'User display name',
                  'example': 'Alice',
                },
              },
            },
          }),
        );

        Map<String, String>? receivedDescriptions;
        Map<String, Map<String, dynamic>>? receivedPlaceholders;

        final provider = MockTranslationProvider((
          Map<String, String> strings,
          String targetLanguage,
          ArbAiConfig config,
          Map<String, String>? descriptions,
          Map<String, Map<String, dynamic>>? placeholders,
        ) async {
          receivedDescriptions = descriptions;
          receivedPlaceholders = placeholders;
          return {'welcome': 'Bem-vindo, {name}!'};
        });

        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          provider: provider,
          logger: const SilentLogger(),
        );

        final success = await orchestrator.run();
        expect(success, isTrue);

        expect(receivedDescriptions, isNotNull);
        expect(
          receivedDescriptions!['welcome'],
          equals('Homepage greeting message'),
        );
        expect(receivedPlaceholders, isNotNull);
        expect(
          receivedPlaceholders!['welcome']!['name']['description'],
          equals('User display name'),
        );
        expect(
          receivedPlaceholders!['welcome']!['name']['example'],
          equals('Alice'),
        );
      },
    );
    test('respects batchSize by dividing translation into chunks', () async {
      sourceFile.writeAsStringSync(
        jsonEncode({
          '@@locale': 'en',
          'key1': 'One',
          'key2': 'Two',
          'key3': 'Three',
          'key4': 'Four',
          'key5': 'Five',
        }),
      );

      final configWithBatchSize2 = testConfig.copyWith(batchSize: 2);
      var chunkSizes = <int>[];

      final provider = MockTranslationProvider((
        Map<String, String> strings,
        String targetLanguage,
        ArbAiConfig config,
        Map<String, String>? descriptions,
        Map<String, Map<String, dynamic>>? placeholders,
      ) async {
        chunkSizes.add(strings.length);
        return strings.map((key, value) => MapEntry(key, 'Translated $value'));
      });

      final orchestrator = ArbAiOrchestrator(
        config: configWithBatchSize2,
        provider: provider,
        logger: const SilentLogger(),
      );

      final success = await orchestrator.run();
      expect(success, isTrue);

      expect(chunkSizes.length, equals(3));
      expect(chunkSizes[0], equals(2));
      expect(chunkSizes[1], equals(2));
      expect(chunkSizes[2], equals(1));

      final targetFile = File('${tempDir.path}/app_pt.arb');
      final targetJson =
          jsonDecode(targetFile.readAsStringSync()) as Map<String, dynamic>;
      expect(targetJson['key5'], equals('Translated Five'));
    });

    test(
      'clean option deletes the cached state file and forces re-translation',
      () async {
        var callCount = 0;
        final provider = MockTranslationProvider((s, t, c, d, p) async {
          callCount++;
          return {
            'welcome': 'Bem-vindo, {name}!',
            'inbox':
                '{count, plural, =0{Sem mensagens} other{{count} mensagens}}',
          };
        });

        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          provider: provider,
          logger: const SilentLogger(),
        );

        await orchestrator.run();
        expect(callCount, 1);

        // Run again: should be in-sync
        await orchestrator.run();
        expect(callCount, 1);

        // Run with clean: true: should delete cache, re-translate, and recreate cache
        final stateFile = File('${tempDir.path}/.arb_ai_state.json');
        expect(stateFile.existsSync(), isTrue);

        final success = await orchestrator.run(clean: true);
        expect(success, isTrue);
        expect(callCount, 2); // incremented because cache was deleted
        expect(
          stateFile.existsSync(),
          isTrue,
        ); // Recreated at the end of the run
      },
    );

    test(
      'force option bypasses the state cache and forces re-translation',
      () async {
        var callCount = 0;
        final provider = MockTranslationProvider((
          strings,
          targetLanguage,
          config,
          d,
          p,
        ) async {
          callCount++;
          return {
            'welcome': 'Bem-vindo, {name}!',
            'inbox':
                '{count, plural, =0{Sem mensagens} other{{count} mensagens}}',
          };
        });

        final orchestrator = ArbAiOrchestrator(
          config: testConfig,
          provider: provider,
          logger: const SilentLogger(),
        );

        // First run: translates and creates cache
        var success = await orchestrator.run();
        expect(success, isTrue);
        expect(callCount, 1);

        // Second run: should be in-sync, provider not called
        success = await orchestrator.run();
        expect(success, isTrue);
        expect(callCount, 1); // still 1

        // Third run with force: true: should translate again
        success = await orchestrator.run(force: true);
        expect(success, isTrue);
        expect(callCount, 2); // incremented!
      },
    );
  });
}
