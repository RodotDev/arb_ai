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
