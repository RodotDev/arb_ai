import 'dart:convert';
import 'dart:io';

/// Deterministic ARB serializer to write clean and Git-friendly target translation files.
class ArbWriter {
  /// Serializes the target translations into a deterministic JSON-formatted ARB string.
  ///
  /// - Sets the '@@locale' parameter at the top.
  /// - Orders translation keys strictly following the order defined in [sourceKeyOrder].
  /// - Enforces a 2-space indentation style.
  /// - Adds a final trailing newline.
  /// - Omits all key metadata (`@key`) to keep target translation files clean.
  static String serialize({
    required String locale,
    required Map<String, String> translations,
    required List<String> sourceKeyOrder,
  }) {
    final data = <String, dynamic>{};
    data['@@locale'] = locale;

    // Add keys in the exact order they exist in the source template
    for (final key in sourceKeyOrder) {
      if (translations.containsKey(key)) {
        data[key] = translations[key]!;
      }
    }

    // Fallback: append any new translation keys that might not exist in the source order
    for (final entry in translations.entries) {
      if (!data.containsKey(entry.key)) {
        data[entry.key] = entry.value;
      }
    }

    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(data)}\n';
  }

  /// Writes deterministic target translations to a target file.
  static void write({
    required File file,
    required String locale,
    required Map<String, String> translations,
    required List<String> sourceKeyOrder,
  }) {
    // Ensure parent directory exists
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final content = serialize(
      locale: locale,
      translations: translations,
      sourceKeyOrder: sourceKeyOrder,
    );
    file.writeAsStringSync(content);
  }
}
