import 'dart:io';
import 'package:arb_ai/src/cli/command_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = ArbAiCommandRunner();
  final exitCode = await runner.run(arguments);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
