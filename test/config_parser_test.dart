import 'dart:io';
import 'package:arb_ai/arb_ai.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigParser Tests', () {
    test('parse() with empty yaml returns defaults', () {
      final config = ConfigParser.parse('');
      expect(config.provider, equals('gemini'));
      expect(config.apiKeyEnv, equals('ARB_AI_API_KEY'));
      expect(config.model, equals('gemini-2.5-flash'));
      expect(config.sourceArb, equals('lib/l10n/app_en.arb'));
      expect(config.targets, isEmpty);
      expect(config.glossary, isEmpty);
      expect(config.doNotTranslate, isEmpty);
      expect(config.tone, isNull);
      expect(config.batchSize, equals(100));
    });

    test('parse() with valid overrides parses correctly', () {
      const yaml = '''
provider: openai
api_key_env: CUSTOM_KEY
model: gpt-4
base_url: https://api.openai.com/v1
source_arb: l10n/source.arb
targets:
  - pt
  - es
glossary:
  pt:
    hello: oi
    world: mundo
  es:
    hello: hola
do_not_translate:
  - Flutter
  - Dart
tone: formal
batch_size: 10
''';
      final config = ConfigParser.parse(yaml);
      expect(config.provider, equals('openai'));
      expect(config.apiKeyEnv, equals('CUSTOM_KEY'));
      expect(config.model, equals('gpt-4'));
      expect(config.baseUrl, equals('https://api.openai.com/v1'));
      expect(config.sourceArb, equals('l10n/source.arb'));
      expect(config.targets, equals(['pt', 'es']));
      expect(
        config.glossary,
        equals({
          'pt': {'hello': 'oi', 'world': 'mundo'},
          'es': {'hello': 'hola'},
        }),
      );
      expect(config.doNotTranslate, equals(['Flutter', 'Dart']));
      expect(config.tone, equals('formal'));
      expect(config.batchSize, equals(10));
    });

    test('parse() throws FormatException on invalid provider', () {
      expect(
        () => ConfigParser.parse('provider: claude'),
        throwsA(isA<FormatException>()),
      );
    });

    test('parse() throws FormatException on invalid targets format', () {
      expect(
        () => ConfigParser.parse('targets: pt'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ConfigParser.parse('''
targets:
  - pt
  - 123
'''),
        throwsA(isA<FormatException>()),
      );
    });

    test('parse() throws FormatException on invalid glossary format', () {
      expect(
        () => ConfigParser.parse('''
glossary:
  - hello
  - world
'''),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ConfigParser.parse('''
glossary:
  pt: hello
'''),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ConfigParser.parse('''
glossary:
  pt:
    hello: 123
'''),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ConfigParser.parse('''
glossary:
  pt:
    123: hello
'''),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'parse() throws FormatException on invalid do_not_translate format',
      () {
        expect(
          () => ConfigParser.parse('do_not_translate: Flutter'),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('parseFile() returns default config when file does not exist', () {
      final config = ConfigParser.parseFile(File('does_not_exist.yaml'));
      expect(config.provider, equals('gemini'));
    });

    test('parse() infers sourceArb from l10n.yaml if omitted', () {
      final l10nFile = File('l10n.yaml');
      l10nFile.writeAsStringSync('''
arb-dir: src/localization
template-arb-file: my_app_en.arb
''');
      try {
        final config = ConfigParser.parse('provider: gemini');
        expect(config.sourceArb, equals('src/localization/my_app_en.arb'));
      } finally {
        if (l10nFile.existsSync()) {
          l10nFile.deleteSync();
        }
      }
    });

    test('parse() falls back to defaults when l10n.yaml is missing', () {
      final config = ConfigParser.parse('provider: gemini');
      expect(config.sourceArb, equals('lib/l10n/app_en.arb'));
    });

    test('parse() throws FormatException on invalid batch_size format', () {
      expect(
        () => ConfigParser.parse('batch_size: -5'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ConfigParser.parse('batch_size: hello'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ConfigParser.parse('batch_size: 0'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
