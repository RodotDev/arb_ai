import 'package:arb_ai/src/cli/command_runner.dart';
import 'package:test/test.dart';

void main() {
  group('ArbAiCommandRunner Tests', () {
    late ArbAiCommandRunner runner;

    setUp(() {
      runner = ArbAiCommandRunner();
    });

    test('parses options correctly', () async {
      final results = runner.parser.parse([
        '--dry-run',
        '--check',
        '--config',
        'custom.yaml',
      ]);
      expect(results['dry-run'], isTrue);
      expect(results['check'], isTrue);
      expect(results['config'], equals('custom.yaml'));
    });

    test('applies defaults correctly', () {
      final results = runner.parser.parse([]);
      expect(results['dry-run'], isFalse);
      expect(results['check'], isFalse);
      expect(results['config'], equals('arb_ai.yaml'));
      expect(results['help'], isFalse);
    });

    test('parses help flag correctly', () {
      final results = runner.parser.parse(['-h']);
      expect(results['help'], isTrue);
    });
  });
}
