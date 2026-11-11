import 'providers/anthropic_provider.dart';
import 'providers/gemini_provider.dart';
import 'translation_provider.dart';

/// What the app needs to know about a provider to select and configure it.
class ProviderSpec {
  /// The model used when the configuration does not name one.
  final String defaultModel;

  /// Creates a ready-to-use provider instance.
  final TranslationProvider Function() create;

  /// Creates a [ProviderSpec].
  const ProviderSpec({required this.defaultModel, required this.create});
}

/// The single place that knows every available [TranslationProvider].
///
/// To add a provider, implement it under `providers/` and register it here.
abstract final class ProviderRegistry {
  /// Available providers by their `provider` configuration name.
  static const Map<String, ProviderSpec> providers = {
    'gemini': ProviderSpec(
      defaultModel: GeminiProvider.defaultModel,
      create: GeminiProvider.new,
    ),
    'anthropic': ProviderSpec(
      defaultModel: AnthropicProvider.defaultModel,
      create: AnthropicProvider.new,
    ),
  };

  /// Common names people try that map to a real provider name.
  static const _aliases = {'claude': 'anthropic', 'google': 'gemini'};

  /// Returns the spec for [name], or throws a [FormatException] listing the
  /// supported providers.
  static ProviderSpec of(String name) {
    final spec = providers[name];
    if (spec != null) return spec;

    final suggestion = _aliases[name.toLowerCase()];
    throw FormatException(
      "Invalid 'provider': '$name'. "
      '${suggestion != null ? "Did you mean '$suggestion'? " : ''}'
      "Supported providers are: ${providers.keys.map((p) => "'$p'").join(', ')}.",
    );
  }
}
