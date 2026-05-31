// ignore_for_file: avoid_print, unused_local_variable

import 'dart:io';
import 'package:arb_ai/arb_ai.dart';

/// This is an example of how to use `arb_ai` programmatically as a Dart library.
/// While most users will use the CLI (`dart run arb_ai`), you can also integrate 
/// the translation orchestration directly into your own tools or scripts.
void main() async {
  print('--- arb_ai Programmatic Example ---');

  // Ensure the required environment variable for your provider is set.
  if (!Platform.environment.containsKey('ARB_AI_API_KEY')) {
    print('\n[Warning] ARB_AI_API_KEY environment variable is not set.');
    print('The AI provider will likely throw an authentication error if executed.\n');
  }

  // 1. Define the configuration for the translation pipeline.
  // This is equivalent to configuring the `arb_ai.yaml` file.
  const config = ArbAiConfig(
    provider: 'gemini',
    model: 'gemini-3.5-flash',
    sourceArb: 'lib/l10n/app_en.arb',
    targets: ['pt', 'es', 'fr'],
    apiKeyEnv: 'ARB_AI_API_KEY',
    glossary: {},
    doNotTranslate: [],
  );

  print('Source file: ${config.sourceArb}');
  print('Target languages: ${config.targets.join(', ')}');
  print('AI Provider: ${config.provider} (${config.model})');

  // 2. Instantiate the core orchestrator.
  // The orchestrator handles the smart-diffing, parsing, and AI translation batching.
  final orchestrator = ArbAiOrchestrator(config: config);

  try {
    print('\nOrchestrator is ready.');
    print('Uncomment the code below to execute the translation pipeline:');
    
    // 3. Execute the pipeline
    // final success = await orchestrator.run();
    // 
    // if (success) {
    //   print('Translation completed successfully!');
    // } else {
    //   print('Translation finished with some errors.');
    // }

  } catch (e) {
    print('An error occurred: $e');
  }
}
