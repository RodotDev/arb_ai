import '../config/arb_ai_config.dart';

/// Interface defining the behavior for an AI-powered translation provider.
abstract class TranslationProvider {
  /// Translates the given [strings] (key-value pairs) into the [targetLanguage].
  ///
  /// Enforces configuration settings like [ArbAiConfig.glossary],
  /// [ArbAiConfig.doNotTranslate], and [ArbAiConfig.tone] if provided.
  /// Returns a map of translated strings with the exact same keys.
  Future<Map<String, String>> translate({
    required Map<String, String> strings,
    required String targetLanguage,
    required ArbAiConfig config,
    Map<String, String>? descriptions,
    Map<String, Map<String, dynamic>>? placeholders,
  });
}
