import 'dart:io';
import 'package:arb_ai/src/cli/command_runner.dart';
import 'package:arb_ai/src/cli/logger.dart';
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

    test('run with --help returns 0 and outputs usage', () async {
      final outBuffer = StringBuffer();
      final testRunner = ArbAiCommandRunner(
        logger: Logger(outputSink: outBuffer),
      );

      final exitCode = await testRunner.run(['--help']);
      check(exitCode).equals(0);
      check(outBuffer.toString()).contains('Usage: dart run arb_ai [options]');
    });

    test('run with invalid arguments returns 64', () async {
      final errBuffer = StringBuffer();
      final testRunner = ArbAiCommandRunner(
        logger: Logger(errorSink: errBuffer),
      );

      final exitCode = await testRunner.run(['--non-existent-flag']);
      check(exitCode).equals(64);
      check(errBuffer.toString()).contains('Error parsing arguments');
    });

    test('run with an invalid configuration reports it and returns 64', () async {
      final configFile = File(
        '${Directory.systemTemp.createTempSync('arb_ai_test').path}/arb_ai.yaml',
      )..writeAsStringSync('provider: claude');
      addTearDown(() => configFile.parent.deleteSync(recursive: true));

      final outBuffer = StringBuffer();
      final errBuffer = StringBuffer();
      final testRunner = ArbAiCommandRunner(
        logger: Logger(outputSink: outBuffer, errorSink: errBuffer),
      );

      final exitCode = await testRunner.run(['--config', configFile.path]);
      check(exitCode).equals(64);
      check(errBuffer.toString())
        ..contains('Configuration Error')
        ..contains("Did you mean 'anthropic'?")
        ..not((it) => it.contains('FormatException'));
      check(outBuffer.toString()).not((it) => it.contains('Usage:'));
    });

    test('run with missing source file returns 1', () async {
      final errBuffer = StringBuffer();
      final testRunner = ArbAiCommandRunner(
        logger: Logger(errorSink: errBuffer),
      );

      final exitCode = await testRunner.run([
        '--config',
        'non_existent_config.yaml',
      ]);
      check(exitCode).equals(1);
    });
  });
}
