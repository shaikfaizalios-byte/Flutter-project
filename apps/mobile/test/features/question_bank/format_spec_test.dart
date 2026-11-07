import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/localization/generated/app_localizations.dart';
import 'package:preploop/features/question_bank/domain/format_spec.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/question_bank/presentation/format_editor_card.dart';

import '../../helpers/fake_questions.dart' show bankQuestion;

void main() {
  test('multiple correct needs a choice, and sorts it', () {
    expect(buildAnswerSpec('multiple_correct', const SpecInput()), isNull);
    expect(buildAnswerSpec('multiple_correct', const SpecInput(positions: {3, 1})), {
      'correct_positions': [1, 3],
    });
  });

  test('numeric is a value with an optional tolerance, or a range', () {
    expect(buildAnswerSpec('numeric', const SpecInput(value: ' 2.5 ')), {'value': '2.5'});
    expect(buildAnswerSpec('numeric', const SpecInput(value: '2.5', tolerance: '0.01')), {
      'value': '2.5',
      'tolerance': '0.01',
    });
    expect(buildAnswerSpec('numeric', const SpecInput(low: '1', high: '2')), {
      'min': '1',
      'max': '2',
    });
    expect(buildAnswerSpec('numeric', const SpecInput(low: '1')), isNull);
  });

  test('fill in the blank takes one answer per line', () {
    expect(buildAnswerSpec('fill_blank', const SpecInput(lines: 'cell\n\n cells ')), {
      'accepted': ['cell', 'cells'],
    });
    expect(buildAnswerSpec('fill_blank', const SpecInput(lines: '  ')), isNull);
  });

  test('match reads pairs, and sorts the right list so it gives nothing away', () {
    expect(buildAnswerSpec('match', const SpecInput(lines: 'Iron = Fe\nGold = Au')), {
      'left': ['Iron', 'Gold'],
      'right': ['Au', 'Fe'],
      'pairs': [
        [0, 1],
        [1, 0],
      ],
    });
  });

  test('a line without both sides is incomplete', () {
    expect(buildAnswerSpec('match', const SpecInput(lines: 'Iron')), isNull);
    expect(buildAnswerSpec('match', const SpecInput(lines: '= Fe')), isNull);
    expect(buildAnswerSpec('match', const SpecInput(lines: 'Iron =')), isNull);
  });

  test('ordering keeps the order but lists the items sorted', () {
    expect(buildAnswerSpec('ordering', const SpecInput(lines: 'c\na\nb')), {
      'items': ['a', 'b', 'c'],
      'order': [2, 0, 1],
    });
    expect(buildAnswerSpec('ordering', const SpecInput(lines: 'one')), isNull);
    expect(buildAnswerSpec('ordering', const SpecInput(lines: 'a\na')), isNull);
  });

  test('a saved answer comes back as it was typed', () {
    for (final (format, input) in const [
      ('multiple_correct', SpecInput(positions: {1, 3})),
      ('numeric', SpecInput(value: '2.5', tolerance: '0.01')),
      ('numeric', SpecInput(low: '1', high: '2')),
      ('fill_blank', SpecInput(lines: 'a\nb')),
      ('match', SpecInput(lines: 'Iron = Fe\nGold = Au')),
      ('ordering', SpecInput(lines: 'c\na\nb')),
    ]) {
      final back = specInputOf(format, buildAnswerSpec(format, input));
      expect(back.positions, input.positions, reason: format);
      expect(back.value, input.value, reason: format);
      expect(back.tolerance, input.tolerance, reason: format);
      expect(back.low, input.low, reason: format);
      expect(back.high, input.high, reason: format);
      expect(back.lines, input.lines, reason: format);
    }
  });

  test('no answer yet gives empty fields', () {
    expect(specInputOf('match', null).lines, '');
  });

  test('an edit sends only what it states', () {
    const edit = QuestionEdit(format: 'numeric', answerSpec: {'value': '2'}, marks: 4);
    expect(edit.toJson(), {
      'format': 'numeric',
      'answer_spec': {'value': '2'},
      'marks': 4.0,
    });
    expect(const QuestionEdit().toJson().containsKey('format'), isFalse);
  });

  testWidgets('a format that needs an answer says so instead of saving', (tester) async {
    final saved = <QuestionEdit>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormatEditorCard(question: bankQuestion(), onSave: (e) async => saved.add(e)),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Numerical answer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save format'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.text('Fill in the answer first.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Value'), '2.5');
    await tester.tap(find.text('Save format'));
    await tester.pumpAndSettle();
    expect(saved.single.format, 'numeric');
    expect(saved.single.answerSpec, {'value': '2.5'});
  });
}
