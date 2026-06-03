import 'dart:io';
import 'package:checks/checks.dart';
import 'package:arb_ai/arb_ai.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigParser Tests', () {
    test('parse() with empty yaml returns defaults', () {
      final config = ConfigParser.parse('');
      check(config.provider).equals('gemini');
      check(config.apiKeyEnv).equals('ARB_AI_API_KEY');
      check(config.model).equals('gemini-3.5-flash');
      check(config.sourceArb).equals('lib/l10n/app_en.arb');
      check(config.targets).isEmpty();
      check(config.glossary).isEmpty();
      check(config.doNotTranslate).isEmpty();
      check(config.tone).isNull();
      check(config.batchSize).equals(100);
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
      check(config.provider).equals('openai');
      check(config.apiKeyEnv).equals('CUSTOM_KEY');
      check(config.model).equals('gpt-4');
      check(config.baseUrl).equals('https://api.openai.com/v1');
      check(config.sourceArb).equals('l10n/source.arb');
      check(config.targets).deepEquals(['pt', 'es']);
      check(config.glossary).deepEquals({
        'pt': {'hello': 'oi', 'world': 'mundo'},
        'es': {'hello': 'hola'},
      });
      check(config.doNotTranslate).deepEquals(['Flutter', 'Dart']);
      check(config.tone).equals('formal');
      check(config.batchSize).equals(10);
    });

    test('parse() throws FormatException on invalid provider', () {
      check(
        () => ConfigParser.parse('provider: claude'),
      ).throws<FormatException>();
    });

    test('parse() throws FormatException on invalid targets format', () {
      check(() => ConfigParser.parse('targets: pt')).throws<FormatException>();
      check(
        () => ConfigParser.parse('''
targets:
  - pt
  - 123
'''),
      ).throws<FormatException>();
    });

    test('parse() throws FormatException on invalid glossary format', () {
      check(
        () => ConfigParser.parse('''
glossary:
  - hello
  - world
'''),
      ).throws<FormatException>();
      check(
        () => ConfigParser.parse('''
glossary:
  pt: hello
'''),
      ).throws<FormatException>();
      check(
        () => ConfigParser.parse('''
glossary:
  pt:
    hello: 123
'''),
      ).throws<FormatException>();
      check(
        () => ConfigParser.parse('''
glossary:
  pt:
    123: hello
'''),
      ).throws<FormatException>();
    });

    test(
      'parse() throws FormatException on invalid do_not_translate format',
      () {
        check(
          () => ConfigParser.parse('do_not_translate: Flutter'),
        ).throws<FormatException>();
      },
    );

    test('parseFile() returns default config when file does not exist', () {
      final config = ConfigParser.parseFile(File('does_not_exist.yaml'));
      check(config.provider).equals('gemini');
    });

    test('parse() infers sourceArb from l10n.yaml if omitted', () {
      final l10nFile = File('l10n.yaml');
      l10nFile.writeAsStringSync('''
arb-dir: src/localization
template-arb-file: my_app_en.arb
''');
      try {
        final config = ConfigParser.parse('provider: gemini');
        check(config.sourceArb).equals('src/localization/my_app_en.arb');
      } finally {
        if (l10nFile.existsSync()) {
          l10nFile.deleteSync();
        }
      }
    });

    test('parse() falls back to defaults when l10n.yaml is missing', () {
      final config = ConfigParser.parse('provider: gemini');
      check(config.sourceArb).equals('lib/l10n/app_en.arb');
    });

    test('parse() throws FormatException on invalid batch_size format', () {
      check(
        () => ConfigParser.parse('batch_size: -5'),
      ).throws<FormatException>();
      check(
        () => ConfigParser.parse('batch_size: hello'),
      ).throws<FormatException>();
      check(
        () => ConfigParser.parse('batch_size: 0'),
      ).throws<FormatException>();
    });
  });
}
