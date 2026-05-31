// ignore_for_file: avoid_print
import 'dart:io';
import 'package:args/args.dart';

/// Command runner for parsing and executing the `arb_ai` CLI logic.
class ArbAiCommandRunner {
  final ArgParser parser = ArgParser();

  ArbAiCommandRunner() {
    parser
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Simulates the translation process, listing keys and estimating costs without calling APIs or writing files.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help: 'CI/CD safety check. Exits with code 1 if translations are missing or outdated, 0 otherwise.',
      )
      ..addOption(
        'config',
        abbr: 'c',
        defaultsTo: 'arb_ai.yaml',
        help: 'Path to the arb_ai.yaml configuration file.',
      )
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage instructions.',
      );
  }

  /// Displays the usage and instructions for the CLI.
  void printUsage() {
    print('Usage: dart run arb_ai [options]\n');
    print('AI-powered build-time translation of Flutter ARB files.\n');
    print('Options:');
    print(parser.usage);
  }

  /// Entrypoint method to parse arguments and execute the workflow.
  /// In Phase 1, it will print parsed options and help.
  Future<void> run(List<String> args) async {
    try {
      final results = parser.parse(args);

      if (results['help'] as bool) {
        printUsage();
        return;
      }

      final dryRun = results['dry-run'] as bool;
      final check = results['check'] as bool;
      final configPath = results['config'] as String;

      print('Parsed CLI flags:');
      print('  --dry-run: $dryRun');
      print('  --check: $check');
      print('  --config: $configPath');
    } on FormatException catch (e) {
      print('Error parsing arguments: ${e.message}\n');
      printUsage();
      exit(64); // Exit code 64 is standard for command line usage error.
    }
  }
}
