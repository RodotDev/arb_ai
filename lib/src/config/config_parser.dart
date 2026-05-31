import 'dart:io';
import 'package:yaml/yaml.dart';
import 'arb_ai_config.dart';

/// Service class to parse and validate `arb_ai.yaml` configuration.
class ConfigParser {
  /// Parses configuration from a YAML string.
  static ArbAiConfig parse(String yamlContent) {
    final doc = loadYaml(yamlContent);
    if (doc == null) {
      return ArbAiConfig.defaults().copyWith(
        sourceArb: _inferSourceArbFromL10nYaml(),
      );
    }

    if (doc is! YamlMap) {
      throw const FormatException('Configuration root must be a YAML map.');
    }

    final defaults = ArbAiConfig.defaults();
    final defaultSourceArb = _inferSourceArbFromL10nYaml();

    final provider = doc['provider'] as String? ?? defaults.provider;
    if (provider != 'gemini' && provider != 'openai') {
      throw FormatException(
        "Invalid 'provider': '$provider'. Supported providers are 'gemini' and 'openai'.",
      );
    }

    final apiKeyEnv = doc['api_key_env'] as String? ?? defaults.apiKeyEnv;
    final model = doc['model'] as String? ?? defaults.model;
    final baseUrl = doc['base_url'] as String?;
    final sourceArb = doc['source_arb'] as String? ?? defaultSourceArb;

    // Validate targets
    final targetsVal = doc['targets'];
    final targets = <String>[];
    if (targetsVal != null) {
      if (targetsVal is! YamlList) {
        throw const FormatException(
          "'targets' must be a list of language codes.",
        );
      }
      for (final item in targetsVal) {
        if (item is! String) {
          throw FormatException(
            "Every item in 'targets' must be a string, got '$item'.",
          );
        }
        targets.add(item);
      }
    }

    // Validate glossary
    final glossaryVal = doc['glossary'];
    final glossary = <String, Map<String, String>>{};
    if (glossaryVal != null) {
      if (glossaryVal is! YamlMap) {
        throw const FormatException(
          "'glossary' must be a map of language configurations.",
        );
      }
      for (final langEntry in glossaryVal.entries) {
        final langCode = langEntry.key;
        final langMapVal = langEntry.value;
        if (langCode is! String) {
          throw FormatException(
            "Glossary language keys must be strings, got '$langCode'.",
          );
        }
        if (langMapVal is! YamlMap) {
          throw FormatException(
            "Glossary value for language '$langCode' must be a map, got '$langMapVal'.",
          );
        }
        final langMap = <String, String>{};
        for (final entry in langMapVal.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is! String || value is! String) {
            throw FormatException(
              "Glossary entries for language '$langCode' must be string-to-string mappings, got '$key: $value'.",
            );
          }
          langMap[key] = value;
        }
        glossary[langCode] = langMap;
      }
    }

    // Validate doNotTranslate
    final dntVal = doc['do_not_translate'];
    final doNotTranslate = <String>[];
    if (dntVal != null) {
      if (dntVal is! YamlList) {
        throw const FormatException(
          "'do_not_translate' must be a list of strings.",
        );
      }
      for (final item in dntVal) {
        if (item is! String) {
          throw FormatException(
            "Every item in 'do_not_translate' must be a string, got '$item'.",
          );
        }
        doNotTranslate.add(item);
      }
    }

    final tone = doc['tone'] as String?;

    // Validate batch_size
    final batchSizeVal = doc['batch_size'];
    var batchSize = defaults.batchSize;
    if (batchSizeVal != null) {
      if (batchSizeVal is! int || batchSizeVal <= 0) {
        throw const FormatException("'batch_size' must be a positive integer.");
      }
      batchSize = batchSizeVal;
    }

    return ArbAiConfig(
      provider: provider,
      apiKeyEnv: apiKeyEnv,
      model: model,
      baseUrl: baseUrl,
      sourceArb: sourceArb,
      targets: targets,
      glossary: glossary,
      doNotTranslate: doNotTranslate,
      tone: tone,
      batchSize: batchSize,
    );
  }

  /// Parses configuration from a file.
  /// Returns default configuration if the file does not exist.
  static ArbAiConfig parseFile(File file) {
    if (!file.existsSync()) {
      return ArbAiConfig.defaults();
    }
    try {
      final content = file.readAsStringSync();
      return parse(content);
    } catch (e) {
      throw FormatException(
        'Failed to parse configuration file ${file.path}: $e',
      );
    }
  }

  /// Parses configuration from a file path.
  static ArbAiConfig parsePath(String path) {
    return parseFile(File(path));
  }

  static String _inferSourceArbFromL10nYaml() {
    final l10nFile = File('l10n.yaml');
    if (l10nFile.existsSync()) {
      try {
        final content = l10nFile.readAsStringSync();
        final doc = loadYaml(content);
        if (doc is YamlMap) {
          final arbDir = doc['arb-dir'] as String? ?? 'lib/l10n';
          final templateArbFile =
              doc['template-arb-file'] as String? ?? 'app_en.arb';
          final cleanArbDir = arbDir.endsWith('/')
              ? arbDir.substring(0, arbDir.length - 1)
              : arbDir;
          final cleanTemplate = templateArbFile.startsWith('/')
              ? templateArbFile.substring(1)
              : templateArbFile;
          return '$cleanArbDir/$cleanTemplate';
        }
      } catch (_) {
        // Fallback silently if parsing error
      }
    }
    return 'lib/l10n/app_en.arb';
  }
}
