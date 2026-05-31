/// A CLI and programming library for AI-powered, build-time translation of
/// Flutter ARB (Application Resource Bundle) files using the Gemini API.
///
/// This library provides programmatic access to the key orchestration,
/// smart-diffing, ICU validation, and batching logic of the `arb_ai` package.
///
/// To start orchestrating translations, instantiate [ArbAiOrchestrator]
/// with an [ArbAiConfig] configuration object:
///
/// ```dart
/// import 'package:arb_ai/arb_ai.dart';
///
/// void main() async {
///   final config = ArbAiConfig(
///     provider: 'gemini',
///     sourceArb: 'lib/l10n/app_en.arb',
///     targets: ['es', 'pt'],
///     apiKeyEnv: 'ARB_AI_API_KEY',
///   );
///
///   final orchestrator = ArbAiOrchestrator(config: config);
///   final success = await orchestrator.run();
///   print('Translations completed: $success');
/// }
/// ```
library;

export 'src/config/arb_ai_config.dart';
export 'src/config/config_parser.dart';
export 'src/arb/arb_parser.dart';
export 'src/arb/arb_state_manager.dart';
export 'src/arb/icu_validator.dart';
export 'src/arb/arb_writer.dart';
export 'src/ai/translation_provider.dart';
export 'src/ai/translation_batcher.dart';
export 'src/ai/gemini_provider.dart';
export 'src/orchestrator.dart';
