import 'dart:io';
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

      expect(arbFile.locale, equals('en'));
      expect(arbFile.globalMetadata['@@context'], equals('Spike test'));
      expect(
        arbFile.translations['welcomeMessage'],
        equals('Welcome back, {name}!'),
      );
      expect(arbFile.translations['simpleKey'], equals('Hello World'));

      final welcomeMeta = arbFile.metadata['welcomeMessage'];
      expect(welcomeMeta, isNotNull);
      expect(welcomeMeta!.description, equals('A welcome message'));
      expect(welcomeMeta.placeholders['name'], isNotNull);
      expect(welcomeMeta.placeholders['name']!.type, equals('String'));
      expect(welcomeMeta.placeholders['name']!.example, equals('John'));

      expect(arbFile.keyOrder, equals(['welcomeMessage', 'simpleKey']));
    });

    test('throws FormatException on invalid formats', () {
      expect(() => ArbFile.parse('invalid json'), throwsFormatException);
      expect(() => ArbFile.parse('[]'), throwsFormatException);
      expect(
        () => ArbFile.parse('{"key": 123}'),
        throwsFormatException,
      ); // key must map to a String
      expect(
        () => ArbFile.parse('{"@key": "should be map"}'),
        throwsFormatException,
      );
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

      expect(serialized, equals(expected));
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
      expect(
        manager.isUpToDate(
          targetLanguage: 'pt',
          key: 'welcomeMessage',
          sourceValue: srcWelcome,
          targetArb: null,
        ),
        isFalse,
      );

      // Let's parse a target ArbFile representing the translations
      const targetArbContent = '''
{
  "@@locale": "pt",
  "welcomeMessage": "Bem-vindo de volta, {name}!"
}
''';
      final targetArb = ArbFile.parse(targetArbContent);

      // 2. Missing from state: key exists in target, but state has no record
      expect(
        manager.isUpToDate(
          targetLanguage: 'pt',
          key: 'welcomeMessage',
          sourceValue: srcWelcome,
          targetArb: targetArb,
        ),
        isFalse,
      );

      // Update state for welcomeMessage
      manager.updateState(
        targetLanguage: 'pt',
        key: 'welcomeMessage',
        sourceValue: srcWelcome,
      );

      // 3. Up to date: key exists in target, state has matching hash
      expect(
        manager.isUpToDate(
          targetLanguage: 'pt',
          key: 'welcomeMessage',
          sourceValue: srcWelcome,
          targetArb: targetArb,
        ),
        isTrue,
      );

      // 4. Outdated/modified: source string changes
      expect(
        manager.isUpToDate(
          targetLanguage: 'pt',
          key: 'welcomeMessage',
          sourceValue: 'Welcome again, {name}!', // Modified source value
          targetArb: targetArb,
        ),
        isFalse,
      );

      // 5. Test saving and reloading state
      manager.updateState(
        targetLanguage: 'pt',
        key: 'inboxCount',
        sourceValue: srcInbox,
      );
      manager.save();

      expect(stateFile.existsSync(), isTrue);

      final newManager = ArbStateManager(stateFile);
      // It should verify inboxCount is up-to-date if key is in target
      final targetArbWithBoth = ArbFile.parse('''
{
  "@@locale": "pt",
  "welcomeMessage": "Bem-vindo de volta, {name}!",
  "inboxCount": "{count, plural, =0{Zero} other{Outro}}"
}
''');

      expect(
        newManager.isUpToDate(
          targetLanguage: 'pt',
          key: 'inboxCount',
          sourceValue: srcInbox,
          targetArb: targetArbWithBoth,
        ),
        isTrue,
      );
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
      expect(res.isValid, isTrue);
      expect(res.error, buildStepId == null ? isNull : anything);
    });

    test('fails when placeholders are missing in target', () {
      final res = IcuValidator.validate(
        key: 'welcomeMessage',
        source: 'Welcome back, {name}!',
        target: 'Bem-vindo de volta!', // Missing {name}
        targetLanguage: 'pt',
      );
      expect(res.isValid, isFalse);
      expect(res.error, contains('Missing placeholder variables: {name}'));
    });

    test('fails when extra placeholders are introduced in target', () {
      final res = IcuValidator.validate(
        key: 'welcomeMessage',
        source: 'Welcome back, {name}!',
        target: 'Bem-vindo de volta, {name} {extra}!', // Added {extra}
        targetLanguage: 'pt',
      );
      expect(res.isValid, isFalse);
      expect(res.error, contains('Unexpected placeholder variables: {extra}'));
    });

    test('fails when variables in complex expressions do not match', () {
      final res = IcuValidator.validate(
        key: 'inboxCount',
        source: '{count, plural, =0{Zero} other{{name}}}',
        target:
            '{name, plural, =0{Zero} other{{count}}}', // name instead of count
        targetLanguage: 'pt',
      );
      expect(res.isValid, isFalse);
      expect(res.error, contains('Variable mismatch at expression 0'));
    });

    test('fails when complex structures do not match', () {
      final res = IcuValidator.validate(
        key: 'inboxCount',
        source: '{count, plural, =0{Zero} other{Other}}',
        target: 'Simple string with {count}', // Literal instead of plural
        targetLanguage: 'pt',
      );
      expect(res.isValid, isFalse);
      expect(res.error, contains('Structural mismatch'));
    });

    test('fails when mandatory other category is missing', () {
      final res = IcuValidator.validate(
        key: 'inboxCount',
        source: '{count, plural, =0{Zero} other{Other}}',
        target: '{count, plural, =0{Zero} =1{Um}}', // Missing 'other'
        targetLanguage: 'pt',
      );
      expect(res.isValid, isFalse);
      expect(res.error, contains('Missing mandatory "other" category'));
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
      expect(invalidPl.isValid, isFalse);
      expect(
        invalidPl.error,
        contains(
          'Missing required CLDR plural categories for language "pl": few, many',
        ),
      );

      final validPl = IcuValidator.validate(
        key: 'inboxCount',
        source: source,
        target: '{count, plural, one{1} few{few} many{many} other{other}}',
        targetLanguage: 'pl',
      );
      expect(validPl.isValid, isTrue);
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
      expect(invalidAr.isValid, isFalse);
      expect(
        invalidAr.error,
        contains(
          'Missing required CLDR plural categories for language "ar": zero, two, few, many',
        ),
      );

      final validAr = IcuValidator.validate(
        key: 'inboxCount',
        source: source,
        target:
            '{count, plural, zero{0} one{1} two{2} few{few} many{many} other{other}}',
        targetLanguage: 'ar',
      );
      expect(validAr.isValid, isTrue);
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
      expect(invalidSl.isValid, isFalse);
      expect(
        invalidSl.error,
        contains(
          'Missing required CLDR plural categories for language "sl": two, few',
        ),
      );

      final validSl = IcuValidator.validate(
        key: 'inboxCount',
        source: source,
        target:
            '{count, plural, one{1} two{2} few{few} other{other}}',
        targetLanguage: 'sl',
      );
      expect(validSl.isValid, isTrue);
    });
  });
}

// Dummy top level variable to bypass linting issues if any
const String? buildStepId = null;
