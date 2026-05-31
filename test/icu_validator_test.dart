import 'package:test/test.dart';
import 'package:arb_ai/src/arb/icu_validator.dart';

void main() {
  group('IcuParser quoting (ICU DOUBLE_OPTIONAL)', () {
    test('collapses a doubled apostrophe into a single literal', () {
      final nodes = IcuParser("It''s here").parse();
      expect(nodes, hasLength(1));
      expect((nodes.single as LiteralNode).text, "It's here");
    });

    test('keeps an ordinary apostrophe as a literal', () {
      final nodes = IcuParser("L'utilisateur {name}").parse();
      expect((nodes.first as LiteralNode).text, "L'utilisateur ");
      expect(nodes.whereType<PlaceholderNode>().map((n) => n.name), ['name']);
    });

    test('treats quoted braces as literal text, not a placeholder', () {
      final nodes = IcuParser("Press '{' then '}'").parse();
      expect(nodes.whereType<PlaceholderNode>(), isEmpty);
      expect((nodes.single as LiteralNode).text, 'Press { then }');
    });

    test('escapes a brace inside a plural branch', () {
      final nodes = IcuParser(
        "{count, plural, one{'{'one'}'} other{many}}",
      ).parse();
      final plural = nodes.single as PluralNode;
      expect((plural.categories['one']!.single as LiteralNode).text, '{one}');
    });

    test('leniently runs an unterminated quote to the end of input', () {
      final nodes = IcuParser("oops '{ unclosed").parse();
      expect(nodes.whereType<PlaceholderNode>(), isEmpty);
      expect((nodes.single as LiteralNode).text, 'oops { unclosed');
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
      expect(result.isValid, isTrue);
    });

    test('does not count quoted braces as placeholders', () {
      final result = IcuValidator.validate(
        key: 'braces',
        source: "Use '{' and '}'",
        target: "Utilisez '{' et '}'",
        targetLanguage: 'fr',
      );
      expect(result.isValid, isTrue);
    });

    test('still flags a real extra placeholder next to escaped braces', () {
      final result = IcuValidator.validate(
        key: 'braces',
        source: "Use '{' here",
        target: "Utilisez '{' {oops}",
        targetLanguage: 'fr',
      );
      expect(result.isValid, isFalse);
    });

    test('handles a doubled apostrophe adjacent to a placeholder', () {
      final result = IcuValidator.validate(
        key: 'list',
        source: 'The {name} list',
        target: "La liste d''{name}",
        targetLanguage: 'fr',
      );
      expect(result.isValid, isTrue);
    });
  });
}
