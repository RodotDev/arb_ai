import 'package:arb_ai/arb_ai.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  group('General package tests', () {
    test('default configuration initializes correctly', () {
      final config = ArbAiConfig.defaults();
      check(config.provider).equals('gemini');
      check(config.model).equals('gemini-3.5-flash');
    });

    test('ArbAiConfig equality and hashCode contract', () {
      const config1 = ArbAiConfig(
        provider: 'gemini',
        apiKeyEnv: 'KEY',
        model: 'gemini-3.5-flash',
        sourceArb: 'app_en.arb',
        targets: ['pt', 'es'],
        glossary: {
          'pt': {'hello': 'olá'},
        },
        doNotTranslate: ['Flutter'],
      );

      const config2 = ArbAiConfig(
        provider: 'gemini',
        apiKeyEnv: 'KEY',
        model: 'gemini-3.5-flash',
        sourceArb: 'app_en.arb',
        targets: ['pt', 'es'],
        glossary: {
          'pt': {'hello': 'olá'},
        },
        doNotTranslate: ['Flutter'],
      );

      final configDifferentTargets = config1.copyWith(targets: ['pt', 'fr']);
      final configDifferentGlossary = config1.copyWith(
        glossary: {
          'pt': {'hello': 'oi'},
        },
      );
      final configDifferentDnt = config1.copyWith(doNotTranslate: ['Dart']);

      check(config1 == config2).isTrue();
      check(config1.hashCode).equals(config2.hashCode);

      check(config1 == configDifferentTargets).isFalse();
      check(config1 == configDifferentGlossary).isFalse();
      check(config1 == configDifferentDnt).isFalse();
    });
  });
}
