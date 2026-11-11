import 'dart:io';
import '../config/arb_ai_config.dart';

/// Looks up the API key in [ArbAiConfig.apiKeyEnv], then in the provider's
/// conventional variable ([fallbackEnv]). Each name is searched in
/// [environment] (the process environment by default) first and in a local
/// `.env` file second.
String? resolveApiKey(
  ArbAiConfig config, {
  String? fallbackEnv,
  Map<String, String>? environment,
}) {
  final env = environment ?? Platform.environment;
  for (final name in {config.apiKeyEnv, ?fallbackEnv}) {
    for (final value in [env[name], _readDotEnv(name)]) {
      if (value != null && value.isNotEmpty) return value;
    }
  }
  return null;
}

/// Same as [resolveApiKey], but throws a [StateError] when no key is found.
String requireApiKey(
  ArbAiConfig config, {
  String? fallbackEnv,
  Map<String, String>? environment,
}) {
  final key = resolveApiKey(
    config,
    fallbackEnv: fallbackEnv,
    environment: environment,
  );
  if (key != null) return key;

  final alternative = fallbackEnv != null && fallbackEnv != config.apiKeyEnv
      ? ' (or "$fallbackEnv")'
      : '';
  throw StateError(
    'API key not found in environment variable "${config.apiKeyEnv}"'
    '$alternative or a local .env file.',
  );
}

String? _readDotEnv(String name) {
  final envFile = File('.env');
  if (!envFile.existsSync()) return null;

  try {
    for (final line in envFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('$name=')) continue;

      var value = trimmed.substring('$name='.length).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      return value;
    }
  } catch (_) {
    // Unreadable .env files are treated as absent.
  }
  return null;
}
