// ignore_for_file: avoid_print
import 'dart:io';
import 'package:args/args.dart';
import '../config/config_parser.dart';
import '../orchestrator.dart';
import 'logger.dart';

/// Command runner for parsing and executing the `arb_ai` CLI logic.
class ArbAiCommandRunner {
  /// The CLI options argument parser.
  final ArgParser parser = ArgParser();

  /// Creates and configures a new [ArbAiCommandRunner] instance.
  ArbAiCommandRunner() {
    parser
      ..addFlag(
        'dry-run',
        negatable: false,
        help:
            'Simulates the translation process, listing keys and estimating costs without calling APIs or writing files.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help:
            'CI/CD safety check. Exits with code 1 if translations are missing or outdated, 0 otherwise.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help:
            'Bypasses the translation state cache and forces a full translation of all text keys.',
      )
      ..addFlag(
        'clean',
        negatable: false,
        help:
            'Deletes the cached translation state file (.arb_ai_state.json) before running.',
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
  Future<void> run(List<String> args) async {
    const logger = Logger();
    try {
      final results = parser.parse(args);

      if (results['help'] as bool) {
        printUsage();
        return;
      }

      final dryRun = results['dry-run'] as bool;
      final check = results['check'] as bool;
      final force = results['force'] as bool;
      final clean = results['clean'] as bool;
      final configPath = results['config'] as String;

      final configFile = File(configPath);
      if (!configFile.existsSync()) {
        logger.warning(
          'Configuration file not found at "$configPath". Using default configuration.',
        );
      }

      final config = ConfigParser.parseFile(configFile);
      final orchestrator = ArbAiOrchestrator(config: config, logger: logger);

      final success = await orchestrator.run(
        dryRun: dryRun,
        check: check,
        force: force,
        clean: clean,
      );

      if (!success) {
        exit(1);
      }
    } on FormatException catch (e) {
      logger.error('Error parsing arguments: ${e.message}\n');
      printUsage();
      exit(64); // Exit code 64 is standard for command line usage error.
    } catch (e) {
      logger.error('Unhandled error: $e');
      exit(1);
    }
  }
}
