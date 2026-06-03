import 'package:arb_ai/arb_ai.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  group('General package tests', () {
    test('default configuration initializes correctly', () {
      final config = ArbAiConfig.defaults();
      check(config.provider).equals('gemini');
      check(config.model).equals('gemini-2.5-flash');
    });
  });
}
