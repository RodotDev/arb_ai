/// Configuration model for `arb_ai.yaml` config files.
class ArbAiConfig {
  /// The AI translation provider. Currently supports 'gemini' (native).
  final String provider;

  /// The environment variable name holding the API key.
  /// Defaults to 'ARB_AI_API_KEY'.
  final String apiKeyEnv;

  /// The specific LLM model name to use.
  /// Defaults to 'gemini-2.5-flash'.
  final String model;

  /// An optional custom API base URL.
  final String? baseUrl;

  /// Path to the source ARB template file (typically English).
  /// Defaults to 'lib/l10n/app_en.arb'.
  final String sourceArb;

  /// List of target language codes to translate into (e.g., 'pt', 'pl', 'ar').
  final List<String> targets;

  /// Optional target-language-specific mapping of terms to force specific translations (glossary).
  final Map<String, Map<String, String>> glossary;

  /// Optional list of words/terms that must not be translated.
  final List<String> doNotTranslate;

  /// Optional instruction for translation tone (e.g. 'formal', 'informal').
  final String? tone;

  /// The maximum number of translation keys sent in a single batch to the provider.
  /// Defaults to 100.
  final int batchSize;

  /// Creates an [ArbAiConfig] configuration instance manually.
  const ArbAiConfig({
    required this.provider,
    required this.apiKeyEnv,
    required this.model,
    this.baseUrl,
    required this.sourceArb,
    required this.targets,
    required this.glossary,
    required this.doNotTranslate,
    this.tone,
    this.batchSize = 100,
  });

  /// Creates a default configuration instance.
  factory ArbAiConfig.defaults() {
    return const ArbAiConfig(
      provider: 'gemini',
      apiKeyEnv: 'ARB_AI_API_KEY',
      model: 'gemini-2.5-flash',
      sourceArb: 'lib/l10n/app_en.arb',
      targets: [],
      glossary: {},
      doNotTranslate: [],
      batchSize: 100,
    );
  }

  /// Copies this configuration with optional overrides.
  ArbAiConfig copyWith({
    String? provider,
    String? apiKeyEnv,
    String? model,
    String? baseUrl,
    String? sourceArb,
    List<String>? targets,
    Map<String, Map<String, String>>? glossary,
    List<String>? doNotTranslate,
    String? tone,
    int? batchSize,
  }) {
    return ArbAiConfig(
      provider: provider ?? this.provider,
      apiKeyEnv: apiKeyEnv ?? this.apiKeyEnv,
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
      sourceArb: sourceArb ?? this.sourceArb,
      targets: targets ?? this.targets,
      glossary: glossary ?? this.glossary,
      doNotTranslate: doNotTranslate ?? this.doNotTranslate,
      tone: tone ?? this.tone,
      batchSize: batchSize ?? this.batchSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArbAiConfig &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          apiKeyEnv == other.apiKeyEnv &&
          model == other.model &&
          baseUrl == other.baseUrl &&
          sourceArb == other.sourceArb &&
          targets.toString() == other.targets.toString() &&
          glossary.toString() == other.glossary.toString() &&
          doNotTranslate.toString() == other.doNotTranslate.toString() &&
          tone == other.tone &&
          batchSize == other.batchSize;

  @override
  int get hashCode =>
      provider.hashCode ^
      apiKeyEnv.hashCode ^
      model.hashCode ^
      baseUrl.hashCode ^
      sourceArb.hashCode ^
      targets.hashCode ^
      glossary.hashCode ^
      doNotTranslate.hashCode ^
      tone.hashCode ^
      batchSize.hashCode;
}
