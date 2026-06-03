import 'dart:io';
import 'package:checks/checks.dart';
import 'package:test/test.dart';
import 'package:arb_ai/arb_ai.dart';

void main() {
  group('ArbParser', () {
    test('successfully parses valid ARB contents', () {
      const arbContent = '''
{
  "@@locale": "en",
  "@@context": "Spike test",
  "welcomeMessage": "Welcome back, {name}!",
  "@welcomeMessage": {
    "description": "A welcome message",
    "placeholders": {
      "name": {
        "type": "String",
        "example": "John"
      }
    }
  },
  "simpleKey": "Hello World"
}
''';

      final arbFile = ArbFile.parse(arbContent);

      check(arbFile.locale).equals('en');
      check(arbFile.globalMetadata['@@context']).equals('Spike test');
      check(arbFile.translations['welcomeMessage']).equals('Welcome back, {name}!');
      check(arbFile.translations['simpleKey']).equals('Hello World');

      final welcomeMeta = arbFile.metadata['welcomeMessage'];
      check(welcomeMeta).isNotNull();
      check(welcomeMeta!.description).equals('A welcome message');
      check(welcomeMeta.placeholders['name']).isNotNull();
      check(welcomeMeta.placeholders['name']!.type).equals('String');
      check(welcomeMeta.placeholders['name']!.example).equals('John');

      check(arbFile.keyOrder).deepEquals(['welcomeMessage', 'simpleKey']);
    });

    test('throws FormatException on invalid formats', () {
      check(() => ArbFile.parse('invalid json')).throws<FormatException>();
      check(() => ArbFile.parse('[]')).throws<FormatException>();
      check(() => ArbFile.parse('{"key": 123}')).throws<FormatException>(); // key must map to a String
      check(() => ArbFile.parse('{"@key": "should be map"}')).throws<FormatException>();
    });
  });

  group('ArbWriter', () {
    test('serializes deterministically', () {
      final translations = {'key2': 'Value 2', 'key1': 'Value 1'};
      final sourceKeyOrder = ['key1', 'key2'];

      final serialized = ArbWriter.serialize(
        locale: 'pt',
        translations: translations,
        sourceKeyOrder: sourceKeyOrder,
      );

      // Verify that key1 comes before key2 as per sourceKeyOrder,
      // and that the indentation is 2 spaces, and has a trailing newline.
      const expected =
          '{\n'
          '  "@@locale": "pt",\n'
          '  "key1": "Value 1",\n'
          '  "key2": "Value 2"\n'
          '}\n';

      check(serialized).equals(expected);
    });
  });

  group('ArbStateManager (True Smart Diffing)', () {
    late Directory tempDir;
    late File stateFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('arb_ai_state_test');
      stateFile = File('${tempDir.path}/.arb_ai_state.json');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('correctly identifies missing and modified keys', () {
      final manager = ArbStateManager(stateFile);

      // Initialize source strings
      const srcWelcome = 'Welcome back, {name}!';
      const srcInbox = '{count, plural, =0{Zero} other{Other}}';

      // 1. Missing keys: targetArb is null
      check(manager.isUpToDate(
        targetLanguage: 'pt',
        key: 'welcomeMessage',
        sourceValue: srcWelcome,
        targetArb: null,
      )).isFalse();

      // Let's parse a target ArbFile representing the translations
      const targetArbContent = '''
{
  "@@locale": "pt",
  "welcomeMessage": "Bem-vindo de volta, {name}!"
}
''';
      final targetArb = ArbFile.parse(targetArbContent);

      // 2. Missing from state: key exists in target, but state has no record
      check(manager.isUpToDate(
        targetLanguage: 'pt',
        key: 'welcomeMessage',
        sourceValue: srcWelcome,
        targetArb: targetArb,
      )).isFalse();

      // Update state for welcomeMessage
      manager.updateState(
        targetLanguage: 'pt',
        key: 'welcomeMessage',
        sourceValue: srcWelcome,
      );

      // 3. Up to date: key exists in target, state has matching hash
      check(manager.isUpToDate(
        targetLanguage: 'pt',
        key: 'welcomeMessage',
        sourceValue: srcWelcome,
        targetArb: targetArb,
      )).isTrue();

      // 4. Outdated/modified: source string changes
      check(manager.isUpToDate(
        targetLanguage: 'pt',
        key: 'welcomeMessage',
        sourceValue: 'Welcome again, {name}!', // Modified source value
        targetArb: targetArb,
      )).isFalse();

      // 5. Test saving and reloading state
      manager.updateState(
        targetLanguage: 'pt',
        key: 'inboxCount',
        sourceValue: srcInbox,
      );
      manager.save();

      check(stateFile.existsSync()).isTrue();

      final newManager = ArbStateManager(stateFile);
      // It should verify inboxCount is up-to-date if key is in target
      final targetArbWithBoth = ArbFile.parse('''
{
  "@@locale": "pt",
  "welcomeMessage": "Bem-vindo de volta, {name}!",
  "inboxCount": "{count, plural, =0{Zero} other{Outro}}"
}
''');

      check(newManager.isUpToDate(
        targetLanguage: 'pt',
        key: 'inboxCount',
        sourceValue: srcInbox,
        targetArb: targetArbWithBoth,
      )).isTrue();
    });
  });

  group('IcuValidator', () {
    test('passes valid simple translations', () {
      final res = IcuValidator.validate(
        key: 'welcomeMessage',
        source: 'Welcome back, {name}!',
        target: 'Bem-vindo de volta, {name}!',
        targetLanguage: 'pt',
      );
      check(res.isValid).isTrue();
      check(res.error).isNull();
    });

    test('fails when placeholders are missing in target', () {
      final res = IcuValidator.validate(
        key: 'welcomeMessage',
        source: 'Welcome back, {name}!',
        target: 'Bem-vindo de volta!', // Missing {name}
        targetLanguage: 'pt',
      );
      check(res.isValid).isFalse();
      check(res.error).isNotNull().contains('Missing placeholder variables: {name}');
    });

    test('fails when extra placeholders are introduced in target', () {
      final res = IcuValidator.validate(
        key: 'welcomeMessage',
        source: 'Welcome back, {name}!',
        target: 'Bem-vindo de volta, {name} {extra}!', // Added {extra}
        targetLanguage: 'pt',
      );
      check(res.isValid).isFalse();
      check(res.error).isNotNull().contains('Unexpected placeholder variables: {extra}');
    });

    test('fails when variables in complex expressions do not match', () {
      final res = IcuValidator.validate(
        key: 'inboxCount',
        source: '{count, plural, =0{Zero} other{{name}}}',
        target:
            '{name, plural, =0{Zero} other{{count}}}', // name instead of count
        targetLanguage: 'pt',
      );
      check(res.isValid).isFalse();
      check(res.error).isNotNull().contains('Variable mismatch at expression 0');
    });

    test('fails when complex structures do not match', () {
      final res = IcuValidator.validate(
        key: 'inboxCount',
        source: '{count, plural, =0{Zero} other{Other}}',
        target: 'Simple string with {count}', // Literal instead of plural
        targetLanguage: 'pt',
      );
      check(res.isValid).isFalse();
      check(res.error).isNotNull().contains('Structural mismatch');
    });

    test('fails when mandatory other category is missing', () {
      final res = IcuValidator.validate(
        key: 'inboxCount',
        source: '{count, plural, =0{Zero} other{Other}}',
        target: '{count, plural, =0{Zero} =1{Um}}', // Missing 'other'
        targetLanguage: 'pt',
      );
      check(res.isValid).isFalse();
      check(res.error).isNotNull().contains('Missing mandatory "other" category');
    });

    test('enforces target-language CLDR plural rules for Polish', () {
      const source = '{count, plural, =0{Zero} other{Other}}';

      // Polish requires: one, few, many, other
      final invalidPl = IcuValidator.validate(
        key: 'inboxCount',
        source: source,
        target: '{count, plural, one{1} other{other}}', // missing few, many
        targetLanguage: 'pl',
      );
      check(invalidPl.isValid).isFalse();
      check(invalidPl.error).isNotNull().contains(
          'Missing required CLDR plural categories for language "pl": few, many',
        );

      final validPl = IcuValidator.validate(
        key: 'inboxCount',
        source: source,
        target: '{count, plural, one{1} few{few} many{many} other{other}}',
        targetLanguage: 'pl',
      );
      check(validPl.isValid).isTrue();
    });

    test('enforces target-language CLDR plural rules for Arabic', () {
      const source = '{count, plural, =0{Zero} other{Other}}';

      // Arabic requires: zero, one, two, few, many, other
      final invalidAr = IcuValidator.validate(
        key: 'inboxCount',
        source: source,
        target: '{count, plural, one{1} other{other}}',
        targetLanguage: 'ar',
      );
      check(invalidAr.isValid).isFalse();
      check(invalidAr.error).isNotNull().contains(
          'Missing required CLDR plural categories for language "ar": zero, two, few, many',
        );

      final validAr = IcuValidator.validate(
        key: 'inboxCount',
        source: source,
        target:
            '{count, plural, zero{0} one{1} two{2} few{few} many{many} other{other}}',
        targetLanguage: 'ar',
      );
      check(validAr.isValid).isTrue();
    });

    test('enforces target-language CLDR plural rules for Slovenian', () {
      const source = '{count, plural, =0{Zero} other{Other}}';

      // Slovenian requires: one, two, few, other
      final invalidSl = IcuValidator.validate(
        key: 'inboxCount',
        source: source,
        target: '{count, plural, one{1} other{other}}',
        targetLanguage: 'sl',
      );
      check(invalidSl.isValid).isFalse();
      check(invalidSl.error).isNotNull().contains(
          'Missing required CLDR plural categories for language "sl": two, few',
        );

      final validSl = IcuValidator.validate(
        key: 'inboxCount',
        source: source,
        target:
            '{count, plural, one{1} two{2} few{few} other{other}}',
        targetLanguage: 'sl',
      );
      check(validSl.isValid).isTrue();
    });
  });
}

// Dummy top level variable to bypass linting issues if any
const String? buildStepId = null;
