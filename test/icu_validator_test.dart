import 'package:checks/checks.dart';
import 'package:test/test.dart';
import 'package:arb_ai/src/arb/icu_validator.dart';

void main() {
  group('IcuParser quoting (ICU DOUBLE_OPTIONAL)', () {
    test('collapses a doubled apostrophe into a single literal', () {
      final nodes = IcuParser("It''s here").parse();
      check(nodes).length.equals(1);
      check((nodes.single as LiteralNode).text).equals("It's here");
    });

    test('keeps an ordinary apostrophe as a literal', () {
      final nodes = IcuParser("L'utilisateur {name}").parse();
      check((nodes.first as LiteralNode).text).equals("L'utilisateur ");
      check(
        nodes.whereType<PlaceholderNode>().map((n) => n.name),
      ).deepEquals(['name']);
    });

    test('treats quoted braces as literal text, not a placeholder', () {
      final nodes = IcuParser("Press '{' then '}'").parse();
      check(nodes.whereType<PlaceholderNode>()).isEmpty();
      check((nodes.single as LiteralNode).text).equals('Press { then }');
    });

    test('escapes a brace inside a plural branch', () {
      final nodes = IcuParser(
        "{count, plural, one{'{'one'}'} other{many}}",
      ).parse();
      final plural = nodes.single as PluralNode;
      check(
        (plural.categories['one']!.single as LiteralNode).text,
      ).equals('{one}');
    });

    test('leniently runs an unterminated quote to the end of input', () {
      final nodes = IcuParser("oops '{ unclosed").parse();
      check(nodes.whereType<PlaceholderNode>()).isEmpty();
      check((nodes.single as LiteralNode).text).equals('oops { unclosed');
    });
  });

  group('IcuValidator with quoting', () {
    test('accepts ordinary apostrophes in the target', () {
      final result = IcuValidator.validate(
        key: 'greeting',
        source: 'The user {name} is here',
        target: "L'utilisateur {name} est là",
        targetLanguage: 'fr',
      );
      check(result.isValid).isTrue();
    });

    test('does not count quoted braces as placeholders', () {
      final result = IcuValidator.validate(
        key: 'braces',
        source: "Use '{' and '}'",
        target: "Utilisez '{' et '}'",
        targetLanguage: 'fr',
      );
      check(result.isValid).isTrue();
    });

    test('still flags a real extra placeholder next to escaped braces', () {
      final result = IcuValidator.validate(
        key: 'braces',
        source: "Use '{' here",
        target: "Utilisez '{' {oops}",
        targetLanguage: 'fr',
      );
      check(result.isValid).isFalse();
    });

    test('handles a doubled apostrophe adjacent to a placeholder', () {
      final result = IcuValidator.validate(
        key: 'list',
        source: 'The {name} list',
        target: "La liste d''{name}",
        targetLanguage: 'fr',
      );
      check(result.isValid).isTrue();
    });
  });

  group('IcuValidator plural category validation', () {
    test('flags overlapping categories (=1 and one)', () {
      final result = IcuValidator.validate(
        key: 'cycles',
        source: '{count, plural, =1{1 cycle} other{{count} cycles}}',
        target:
            '{count, plural, =1{1 цикл} one{{count} ciclo} few{{count} цикла} many{{count} циклов} other{{count} цикла}}',
        targetLanguage: 'ru_RU',
      );
      check(result.isValid).isFalse();
      check(
        result.error,
      ).isNotNull().contains('cannot have both "=1" and "one"');
    });

    test('flags overlapping categories (=0 and zero)', () {
      final result = IcuValidator.validate(
        key: 'cycles',
        source: '{count, plural, =0{no cycles} other{{count} cycles}}',
        target:
            '{count, plural, =0{no cycles} zero{zero cycles} other{{count} cycles}}',
        targetLanguage: 'ar',
      );
      check(result.isValid).isFalse();
      check(
        result.error,
      ).isNotNull().contains('cannot have both "=0" and "zero"');
    });

    test('flags overlapping categories (=2 and two)', () {
      final result = IcuValidator.validate(
        key: 'cycles',
        source: '{count, plural, =2{two cycles} other{{count} cycles}}',
        target:
            '{count, plural, =2{two cycles} two{two cycles} other{{count} cycles}}',
        targetLanguage: 'ar',
      );
      check(result.isValid).isFalse();
      check(
        result.error,
      ).isNotNull().contains('cannot have both "=2" and "two"');
    });

    test('flags a dropped zero branch from the source', () {
      const source =
          '{count, plural, =0{Your cart is empty} =1{1 item} other{# items}}';

      final dropped = IcuValidator.validate(
        key: 'cart',
        source: source,
        target: '{count, plural, one{# item} other{# itens}}',
        targetLanguage: 'pt_BR',
      );
      check(dropped.isValid).isFalse();
      check(dropped.error).isNotNull().contains('Missing "=0" branch');

      final kept = IcuValidator.validate(
        key: 'cart',
        source: source,
        target:
            '{count, plural, =0{Sua sacola está vazia} one{# item} other{# itens}}',
        targetLanguage: 'pt_BR',
      );
      check(kept.isValid).isTrue();
    });

    test('accepts the zero category as the zero branch', () {
      // Arabic requires "zero", which cannot coexist with "=0".
      final result = IcuValidator.validate(
        key: 'cart',
        source: '{count, plural, zero{Your cart is empty} other{# items}}',
        target:
            '{count, plural, zero{سلتك فارغة} one{عنصر واحد} two{عنصران} few{# عناصر} many{# عنصرًا} other{# عنصر}}',
        targetLanguage: 'ar',
      );
      check(result.isValid).isTrue();
    });

    test('flags a dropped two branch from the source', () {
      const source = '{count, plural, =2{Both items} other{# items}}';

      final dropped = IcuValidator.validate(
        key: 'items',
        source: source,
        target: '{count, plural, other{# 個}}',
        targetLanguage: 'ja',
      );
      check(dropped.isValid).isFalse();
      check(dropped.error).isNotNull().contains('Missing "=2" branch');

      final kept = IcuValidator.validate(
        key: 'items',
        source: source,
        target: '{count, plural, =2{両方} other{# 個}}',
        targetLanguage: 'ja',
      );
      check(kept.isValid).isTrue();
    });

    test('flags an exact-value message in a category covering more numbers', () {
      // Latvian "zero" also matches 10–20, 30…: "empty" would be wrong there.
      const source =
          '{count, plural, =0{Your cart is empty} other{# items in your cart}}';

      final exactMessage = IcuValidator.validate(
        key: 'cart',
        source: source,
        target:
            '{count, plural, zero{Jūsu grozs ir tukšs} one{# prece} other{# preces}}',
        targetLanguage: 'lv',
      );
      check(exactMessage.isValid).isFalse();
      check(exactMessage.error).isNotNull().contains(
        'The "zero" category matches more than one number',
      );

      final withCount = IcuValidator.validate(
        key: 'cart',
        source: source,
        target: '{count, plural, zero{# preču} one{# prece} other{# preces}}',
        targetLanguage: 'lv',
      );
      check(withCount.isValid).isTrue();

      // Slovenian "two" also matches 102, 202…
      final slovenian = IcuValidator.validate(
        key: 'photos',
        source: '{count, plural, =2{Both photos} other{# photos}}',
        target:
            '{count, plural, one{# fotografija} two{Obe fotografiji} few{# fotografije} other{# fotografij}}',
        targetLanguage: 'sl',
      );
      check(slovenian.isValid).isFalse();
    });

    test('allows countless branches when no branch shows the count', () {
      final result = IcuValidator.validate(
        key: 'delete',
        source: '{count, plural, =1{Delete file?} other{Delete files?}}',
        target:
            '{count, plural, zero{Dzēst failus?} one{Dzēst failu?} other{Dzēst failus?}}',
        targetLanguage: 'lv',
      );
      check(result.isValid).isTrue();
    });

    test('does not require the singular "=1" branch in the target', () {
      final result = IcuValidator.validate(
        key: 'items',
        source: '{count, plural, =1{1 item} other{# items}}',
        target: '{count, plural, other{# 個}}',
        targetLanguage: 'ja',
      );
      check(result.isValid).isTrue();
    });

    test('validates regional languages with base language CLDR rules', () {
      // ru_RU should fallback to ru and require ['one', 'few', 'many', 'other']
      final invalidResult = IcuValidator.validate(
        key: 'cycles',
        source: '{count, plural, =1{1 cycle} other{{count} cycles}}',
        target: '{count, plural, one{{count} цикл} other{{count} цикла}}',
        targetLanguage: 'ru_RU',
      );
      check(invalidResult.isValid).isFalse();
      check(invalidResult.error).isNotNull().contains(
        'Missing required CLDR plural categories for language "ru_RU": few, many',
      );

      final validResult = IcuValidator.validate(
        key: 'cycles',
        source: '{count, plural, =1{1 cycle} other{{count} cycles}}',
        target:
            '{count, plural, one{{count} цикл} few{{count} цикла} many{{count} циклов} other{{count} цикла}}',
        targetLanguage: 'ru_RU',
      );
      check(validResult.isValid).isTrue();
    });
  });
}
