import 'dart:convert';
import 'dart:io';

/// Represents a placeholder definition in an ARB file.
class ArbPlaceholder {
  /// The placeholder variable name.
  final String name;

  /// The type of the placeholder (e.g. 'String', 'int', 'num').
  final String? type;

  /// The format of the placeholder (e.g. 'currency', 'decimalPattern').
  final String? format;

  /// An example of the placeholder value.
  final String? example;

  /// The description of the placeholder, for translator context.
  final String? description;

  /// Creates a new [ArbPlaceholder] definition.
  const ArbPlaceholder({
    required this.name,
    this.type,
    this.format,
    this.example,
    this.description,
  });

  /// Parses a placeholder from JSON.
  factory ArbPlaceholder.fromJson(String name, Map<String, dynamic> json) {
    return ArbPlaceholder(
      name: name,
      type: json['type'] as String?,
      format: json['format'] as String?,
      example: json['example'] as String?,
      description: json['description'] as String?,
    );
  }

  /// Converts the placeholder back to JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (type != null) 'type': type,
      if (format != null) 'format': format,
      if (example != null) 'example': example,
      if (description != null) 'description': description,
    };
  }
}

/// Represents the metadata for a translation key in an ARB file.
class ArbKeyMetadata {
  /// The corresponding translation key.
  final String key;

  /// Optional description for context.
  final String? description;

  /// Map of placeholders used by this string.
  final Map<String, ArbPlaceholder> placeholders;

  /// Custom key attributes (like type, context, etc.).
  final Map<String, dynamic> customAttributes;

  /// Creates metadata for an ARB key.
  const ArbKeyMetadata({
    required this.key,
    this.description,
    required this.placeholders,
    required this.customAttributes,
  });

  /// Parses key metadata from JSON.
  factory ArbKeyMetadata.fromJson(String key, Map<String, dynamic> json) {
    final placeholders = <String, ArbPlaceholder>{};
    final placeholdersVal = json['placeholders'];
    if (placeholdersVal is Map<String, dynamic>) {
      for (final entry in placeholdersVal.entries) {
        if (entry.value is Map<String, dynamic>) {
          placeholders[entry.key] = ArbPlaceholder.fromJson(
            entry.key,
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    final custom = <String, dynamic>{};
    for (final entry in json.entries) {
      if (entry.key != 'description' && entry.key != 'placeholders') {
        custom[entry.key] = entry.value;
      }
    }

    return ArbKeyMetadata(
      key: key,
      description: json['description'] as String?,
      placeholders: placeholders,
      customAttributes: custom,
    );
  }

  /// Converts the key metadata back to JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (description != null) 'description': description,
      if (placeholders.isNotEmpty)
        'placeholders': placeholders.map((k, v) => MapEntry(k, v.toJson())),
      ...customAttributes,
    };
  }
}

/// Represents the fully parsed content of an ARB file.
class ArbFile {
  /// The locale of the ARB file (typically from '@@locale').
  final String? locale;

  /// The clean map of translation keys to their string values.
  final Map<String, String> translations;

  /// The map of translation keys to their metadata definitions.
  final Map<String, ArbKeyMetadata> metadata;

  /// The global metadata keys (e.g. '@@locale', '@@context').
  final Map<String, dynamic> globalMetadata;

  /// The full list of keys in their original order in the JSON file.
  final List<String> keyOrder;

  /// Creates an [ArbFile] representation of a parsed ARB file.
  const ArbFile({
    this.locale,
    required this.translations,
    required this.metadata,
    required this.globalMetadata,
    required this.keyOrder,
  });

  /// Parses an ARB content string.
  factory ArbFile.parse(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('ARB file must be a JSON map.');
    }

    final translations = <String, String>{};
    final metadata = <String, ArbKeyMetadata>{};
    final globalMetadata = <String, dynamic>{};
    final keyOrder = <String>[];
    String? locale;

    for (final entry in decoded.entries) {
      final key = entry.key;
      final val = entry.value;

      if (key == '@@locale') {
        locale = val as String?;
        globalMetadata[key] = val;
      } else if (key.startsWith('@@')) {
        globalMetadata[key] = val;
      } else if (key.startsWith('@')) {
        final realKey = key.substring(1);
        if (val is Map<String, dynamic>) {
          metadata[realKey] = ArbKeyMetadata.fromJson(realKey, val);
        } else {
          throw FormatException('Metadata key "$key" must map to a JSON object.');
        }
      } else {
        if (val is String) {
          translations[key] = val;
          keyOrder.add(key);
        } else {
          throw FormatException('Translation key "$key" must map to a String.');
        }
      }
    }

    return ArbFile(
      locale: locale,
      translations: translations,
      metadata: metadata,
      globalMetadata: globalMetadata,
      keyOrder: keyOrder,
    );
  }

  /// Parses an ARB file.
  factory ArbFile.parseFile(File file) {
    if (!file.existsSync()) {
      throw FileSystemException('ARB file does not exist', file.path);
    }
    return ArbFile.parse(file.readAsStringSync());
  }
}
