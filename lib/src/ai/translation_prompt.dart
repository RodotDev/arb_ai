import '../arb/icu_validator.dart';
import '../config/arb_ai_config.dart';

/// Provider-agnostic prompt pieces shared by every [TranslationProvider].
///
/// Providers only decide *where* each piece goes in their request format.
abstract final class TranslationPrompt {
  /// The localizer persona, without any output-format instructions.
  static const role =
      'You are an expert software localizer specialized in Flutter/Dart ARB '
      'and ICU MessageFormat. You strictly translate user-provided JSON '
      'values while preserving ICU syntax and placeholders';

  /// Translation instructions for [targetLanguage]: ICU rules followed by the
  /// tone, do-not-translate terms and glossary from [config].
  static String instructions({
    required String targetLanguage,
    required ArbAiConfig config,
  }) {
    final buffer = StringBuffer();
    final expandedLang = languageName(targetLanguage);
    final promptLangStr =
        expandedLang.toLowerCase() == targetLanguage.toLowerCase()
        ? '"$targetLanguage"'
        : '"$targetLanguage" ($expandedLang)';

    buffer.writeln(
      'Translate the values of the following application strings into the target '
      'language code $promptLangStr. Write natural, idiomatic UI text (never '
      'word-for-word) and keep terminology consistent across all keys.',
    );
    buffer.writeln('ICU MessageFormat & placeholder rules:');
    buffer.writeln(
      '- Preserve every placeholder exactly, including its type and format '
      'options (e.g. {name}, {count}, {price, number, currency}, {date, date, '
      'short}). Never translate placeholder or variable names.',
    );
    buffer.writeln(
      '- For plural and select expressions, translate ONLY the human-readable '
      'text inside each branch. Keep the selector variable, the category '
      'keywords (zero, one, two, few, many, other, =0, =1, male, female, ...) '
      'and the # symbol unchanged.',
    );
    buffer.writeln(
      '- For plurals, use the CLDR plural categories required by the target '
      'language, always including "other". Do not add any other category '
      'keyword.',
    );
    buffer.writeln(
      '- A source branch for exactly zero ("=0" or "zero") or exactly two '
      '("=2" or "two") carries its own message (e.g. an empty state), so the '
      'translation MUST keep a branch for that value. Write it as "=0" / '
      '"=2", unless the target language requires the "zero" / "two" category: '
      'then put the translated message in that category instead, and if the '
      'category also covers other numbers in the target language, phrase it '
      'with # so it reads correctly for all of them.',
    );
    buffer.writeln(
      '- Do not include both explicit and category-based selectors for the same numeric value '
      'in the target translation (e.g., do not have both "=1" and "one", both "=0" and "zero", '
      'or both "=2" and "two"). If the target language requires the "one" category, do not include '
      '"=1" (use only "one"). If it requires "zero", do not include "=0". If it requires "two", '
      'do not include "=2".',
    );
    final requiredCategories =
        IcuValidator.cldrPluralCategories[targetLanguage] ??
        IcuValidator.cldrPluralCategories[_baseLanguage(targetLanguage)];
    if (requiredCategories != null) {
      // Exact-value branches that do not collide with a required category.
      final allowedExact = [
        if (!requiredCategories.contains('zero')) '"=0"',
        if (!requiredCategories.contains('two')) '"=2"',
      ];
      buffer.writeln(
        '  Specifically for target language code "$targetLanguage", every plural expression MUST '
        'define all of these CLDR category keys and no other category keyword: '
        '${requiredCategories.join(", ")}.'
        '${allowedExact.isEmpty ? '' : ' A branch for ${allowedExact.join(' or ')} kept from the source is the only allowed addition.'}',
      );
    }
    buffer.writeln(
      '- Inside category keyword branches (one, two, few, many, other), write '
      'the count with # instead of a literal digit: a category can cover '
      'several numbers in the target language (e.g. "one" also covers 0 in '
      'French and Portuguese, and 21 in Russian). Literal digits are only '
      'safe in exact-value branches such as "=0" or "=2".',
    );
    buffer.writeln(
      "- If a message contains any {...} expression, escape every literal "
      "apostrophe/single quote by doubling it (' becomes '') per ICU "
      'MessageFormat rules. Leave apostrophes untouched in plain messages '
      'without any {...} expression.',
    );
    buffer.writeln(
      '- Preserve leading and trailing whitespace and line breaks (\\n) exactly '
      'as in the source.',
    );
    buffer.writeln(
      '- Use locale-appropriate punctuation and typography (quotation marks, '
      'spacing) without altering any placeholder or ICU syntax.',
    );

    if (config.tone != null && config.tone!.isNotEmpty) {
      buffer.writeln('Use a ${config.tone} tone for the translation.');
    }

    if (config.doNotTranslate.isNotEmpty) {
      buffer.writeln(
        'Do NOT translate the following terms (keep them exactly as they are):',
      );
      for (final term in config.doNotTranslate) {
        buffer.writeln('- $term');
      }
    }

    final glossary = _glossaryFor(targetLanguage, config);
    if (glossary != null && glossary.isNotEmpty) {
      buffer.writeln(
        'Strictly apply the following glossary mappings if the term/concept matches:',
      );
      glossary.forEach((term, translation) {
        buffer.writeln('- "$term" must be translated as "$translation"');
      });
    }

    return buffer.toString();
  }

  /// Context for a single key: its ARB description, placeholder metadata and
  /// the validation error of a previous attempt. Returns null when there is
  /// nothing to say about the key.
  static String? keyContext({
    String? description,
    Map<String, dynamic>? placeholders,
    String? retryFeedback,
  }) {
    final buffer = StringBuffer();
    if (description != null && description.isNotEmpty) {
      buffer.write('Context: $description.');
    }
    if (placeholders != null && placeholders.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write('Placeholders info:');
      placeholders.forEach((name, metadata) {
        if (metadata is! Map<String, dynamic>) return;
        final details = [
          if (metadata['description'] != null)
            'desc: ${metadata['description']}',
          if (metadata['example'] != null) 'example: ${metadata['example']}',
        ];
        buffer.write(' {$name}');
        if (details.isNotEmpty) buffer.write(' (${details.join(', ')})');
        buffer.write(';');
      });
    }
    if (retryFeedback != null && retryFeedback.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(
        'IMPORTANT: Previous translation attempt failed validation: $retryFeedback. '
        'You MUST fix this error in your new translation.',
      );
    }
    return buffer.isEmpty ? null : buffer.toString().trim();
  }

  /// Expands language codes (especially regional ones like pt_BR or es_419)
  /// into human-friendly names.
  static String languageName(String langCode) {
    final normalized = _normalize(langCode);
    final known = _languageNames[normalized];
    if (known != null) return known;

    final parts = normalized.split('-');
    if (parts.length > 1) {
      return '${languageName(parts[0])} (Region: ${parts[1].toUpperCase()})';
    }
    return langCode;
  }

  /// Finds the glossary for [targetLanguage], falling back to its base
  /// language (e.g. `pt` for `pt_BR`).
  static Map<String, String>? _glossaryFor(
    String targetLanguage,
    ArbAiConfig config,
  ) {
    for (final wanted in [
      _normalize(targetLanguage),
      _baseLanguage(targetLanguage),
    ]) {
      for (final entry in config.glossary.entries) {
        if (_normalize(entry.key) == wanted) return entry.value;
      }
    }
    return null;
  }

  static String _normalize(String langCode) =>
      langCode.replaceAll('_', '-').toLowerCase();

  static String _baseLanguage(String langCode) =>
      langCode.split(RegExp('[_-]'))[0].toLowerCase();

  static const _languageNames = {
    'pt': 'Portuguese',
    'pt-br': 'Brazilian Portuguese',
    'es': 'Spanish',
    'es-419': 'Latin American Spanish',
    'zh': 'Chinese',
    'zh-hans': 'Simplified Chinese',
    'zh-hant': 'Traditional Chinese',
    'en': 'English',
    'en-us': 'American English',
    'en-gb': 'British English',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
    'pl': 'Polish',
    'ar': 'Arabic',
  };
}
