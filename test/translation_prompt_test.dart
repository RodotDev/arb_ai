import 'package:arb_ai/arb_ai.dart';
import 'package:arb_ai/src/ai/translation_prompt.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  group('TranslationPrompt.keyContext', () {
    test('returns null when there is nothing to say', () {
      check(TranslationPrompt.keyContext()).isNull();
    });

    test('renders description, location and placeholder details', () {
      final context = TranslationPrompt.keyContext(
        description: 'Due date of a task',
        context: 'tasks: Details sheet',
        placeholders: {
          'date': {
            'type': 'DateTime',
            'format': 'yMMMd',
            'description': 'The due date',
            'example': '2026-01-01',
          },
          'name': {'type': 'String'},
        },
      );

      check(context).equals(
        'Description: Due date of a task. '
        'Location in app: tasks > Details sheet. '
        'Placeholders info: '
        '{date} (type: DateTime, format: yMMMd, desc: The due date, example: 2026-01-01); '
        '{name} (type: String);',
      );
    });

    test('renders a location alone', () {
      check(
        TranslationPrompt.keyContext(context: 'homePage'),
      ).equals('Location in app: homePage.');
    });
  });

  group('TranslationPrompt.instructions', () {
    final config = ArbAiConfig.defaults();

    test('includes the file context when given', () {
      check(
        TranslationPrompt.instructions(
          targetLanguage: 'pt',
          config: config,
          fileContext: 'A recipe sharing app',
        ),
      ).contains('App context for all strings: A recipe sharing app.');
    });

    test('omits the file context line when absent', () {
      check(
        TranslationPrompt.instructions(targetLanguage: 'pt', config: config),
      ).not((it) => it.contains('App context'));
    });
  });
}
