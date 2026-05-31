import 'package:arb_ai/arb_ai.dart';

void main() {
  const yaml = '''
provider: gemini
model: gemini-3.5-flash
targets:
  - pt
  - pl
''';
  final config = ConfigParser.parse(yaml);
  // ignore: avoid_print
  print('Parsed config provider: ${config.provider}');
  // ignore: avoid_print
  print('Parsed config model: ${config.model}');
  // ignore: avoid_print
  print('Parsed config targets: ${config.targets}');
}
