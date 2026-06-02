import 'package:arb_ai/arb_ai.dart';
import 'package:test/test.dart';

void main() {
  group('General package tests', () {
    test('default configuration initializes correctly', () {
      final config = ArbAiConfig.defaults();
      expect(config.provider, equals('gemini'));
      expect(config.model, equals('gemini-2.5-flash'));
    });
  });
}
