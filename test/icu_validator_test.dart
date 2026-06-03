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
}
