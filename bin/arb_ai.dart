import 'package:arb_ai/src/cli/command_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = ArbAiCommandRunner();
  await runner.run(arguments);
}
