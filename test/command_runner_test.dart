import 'package:arb_ai/src/cli/command_runner.dart';
import 'package:checks/checks.dart';
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
      check(results['dry-run'] as bool).isTrue();
      check(results['check'] as bool).isTrue();
      check(results['config']).equals('custom.yaml');
    });

    test('applies defaults correctly', () {
      final results = runner.parser.parse([]);
      check(results['dry-run'] as bool).isFalse();
      check(results['check'] as bool).isFalse();
      check(results['config']).equals('arb_ai.yaml');
      check(results['help'] as bool).isFalse();
    });

    test('parses help flag correctly', () {
      final results = runner.parser.parse(['-h']);
      check(results['help'] as bool).isTrue();
    });
  });
}
