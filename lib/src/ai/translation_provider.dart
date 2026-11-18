import '../config/arb_ai_config.dart';

/// Interface defining the behavior for an AI-powered translation provider.
abstract class TranslationProvider {
  /// Translates the given [strings] (key-value pairs) into the [targetLanguage].
  ///
  /// Enforces configuration settings like [ArbAiConfig.glossary],
  /// [ArbAiConfig.doNotTranslate], and [ArbAiConfig.tone] if provided.
  /// Returns a map of translated strings with the exact same keys.
  ///
  /// Optional ARB metadata, by key: [descriptions], [contexts] (the
  /// `@key.context` hierarchy, e.g. `homePage:Print dialog box`) and
  /// [placeholders]. [fileContext] is the source file's `@@context`, which
  /// applies to every string. [retryFeedback] holds the validation error of a
  /// previous attempt, by key.
  Future<Map<String, String>> translate({
    required Map<String, String> strings,
    required String targetLanguage,
    required ArbAiConfig config,
    Map<String, String>? descriptions,
    Map<String, String>? contexts,
    Map<String, Map<String, dynamic>>? placeholders,
    String? fileContext,
    Map<String, String>? retryFeedback,
  });

  /// Ensures the provider is correctly configured for execution (e.g., checks API keys).
  ///
  /// Throws a [StateError] if validation fails.
  void validateEnvironment(ArbAiConfig config);
}
