import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/localization/generated/app_localizations.dart';
import 'package:preploop/core/widgets/rich_question_text.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';
import 'package:preploop/features/practice/presentation/session_screen.dart';
import 'package:preploop/features/question_bank/domain/format_spec.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/question_bank/presentation/answer_key_card.dart';

import '../../helpers/fake_questions.dart';

void main() {
  group('chemistry', () {
    test('subscripts follow elements and brackets', () {
      expect(ceToTex('H2O'), r'\mathrm{H_{2}O}');
      expect(ceToTex('Ca(OH)2'), r'\mathrm{Ca(OH)_{2}}');
    });

    test('a leading number stays a coefficient', () {
      expect(ceToTex('2H2O'), r'\mathrm{2H_{2}O}');
    });

    test('charges are raised', () {
      expect(ceToTex('SO4^2-'), r'\mathrm{SO_{4}^{2-}}');
      expect(ceToTex('Na^+'), r'\mathrm{Na^{+}}');
    });

    test('arrows become arrows', () {
      expect(ceToTex('N2 + 3H2 <=> 2NH3'), contains(r'\rightleftharpoons'));
      expect(ceToTex('2H2 + O2 -> 2H2O'), contains(r'\rightarrow'));
    });

    test('text can hold chemistry outside and inside maths', () {
      final parts = splitQuestionText(r'Water is \ce{H2O} here');
      expect(parts.whereType<MathPart>().single.tex, r'\mathrm{H_{2}O}');
      expect(parts.whereType<PlainPart>().length, 2);
      final inside = splitQuestionText(r'$\ce{H2O}$');
      expect(inside.whereType<MathPart>().single.tex, r'\mathrm{H_{2}O}');
    });
  });

  test('parsing the same text twice gives the same parts', () {
    const text = r'Find $x^2$ here';
    expect(identical(splitQuestionText(text), splitQuestionText(text)), isTrue);
  });

  test('plain text and dollar amounts stay as they are', () {
    expect(splitQuestionText(r'It costs $5 and $6').single, isA<PlainPart>());
  });

  group('whole numbers and decimal places', () {
    test('a whole number is saved and read back', () {
      final spec = buildAnswerSpec('integer', const SpecInput(value: ' 7 '));
      expect(spec, {'value': '7'});
      expect(specInputOf('integer', spec).value, '7');
      expect(buildAnswerSpec('integer', const SpecInput()), isNull);
    });

    test('decimal places go with a value or a range, only when given', () {
      expect(buildAnswerSpec('numeric', const SpecInput(value: '2.67', decimals: '2')), {
        'value': '2.67',
        'decimals': 2,
      });
      expect(buildAnswerSpec('numeric', const SpecInput(low: '1', high: '2', decimals: '2')), {
        'min': '1',
        'max': '2',
        'decimals': 2,
      });
      expect(buildAnswerSpec('numeric', const SpecInput(value: '2')), {'value': '2'});
      expect(specInputOf('numeric', {'value': '2', 'decimals': 2}).decimals, '2');
    });
  });

  test('a key edit sends only what it states', () {
    expect(const AnswerKeyEdit(stage: 'final', outcome: 'dropped').toJson(), {
      'stage': 'final',
      'outcome': 'dropped',
    });
    expect(const AnswerKeyEdit(stage: null, outcome: 'one', correctPosition: 2).toJson(), {
      'stage': null,
      'outcome': 'one',
      'correct_option_position': 2,
    });
  });

  group('what the learner is told', () {
    const item = SessionItemView(
      position: 1,
      options: [
        QuestionOption(position: 1, label: 'A', text: 'x'),
        QuestionOption(position: 2, label: 'B', text: 'y'),
      ],
      verified: true,
      bookmarked: false,
    );

    Future<AppLocalizations> l10n(WidgetTester tester) async {
      late AppLocalizations found;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              found = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return found;
    }

    testWidgets('each state has its own note, and a plain key has none', (tester) async {
      final text = await l10n(tester);
      expect(
        keyNoteText(text, item, const AnswerFeedback(keyNote: 'dropped')),
        'Dropped in the official key: everyone gets the marks.',
      );
      expect(
        keyNoteText(
          text,
          item,
          const AnswerFeedback(keyNote: 'several', acceptedPositions: [1, 2]),
        ),
        'The official key accepts more than one answer: A, B.',
      );
      expect(
        keyNoteText(text, item, const AnswerFeedback(keyNote: 'changed')),
        'This answer changed in the final key.',
      );
      expect(keyNoteText(text, item, const AnswerFeedback()), isNull);
    });
  });

  test('feedback and results read the new fields, and older ones still read', () {
    final feedback = AnswerFeedback.fromJson({
      'correct_position': 1,
      'is_correct': true,
      'explanation': null,
      'explanation_origin': null,
      'accepted_positions': [1, 3],
      'key_note': 'several',
    });
    expect(feedback.acceptedPositions, [1, 3]);
    final older = AnswerFeedback.fromJson({
      'correct_position': 1,
      'is_correct': true,
      'explanation': null,
      'explanation_origin': null,
    });
    expect(older.acceptedPositions, isEmpty);
    expect(older.keyNote, isNull);
  });

  group('the key card', () {
    Future<List<AnswerKeyEdit>> pumpCard(WidgetTester tester) async {
      final saved = <AnswerKeyEdit>[];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnswerKeyCard(
                  question: bankQuestion(),
                  onSave: (edit) async => saved.add(edit),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return saved;
    }

    Future<void> choose(WidgetTester tester, String from, String to) async {
      await tester.tap(find.text(from).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(to).last);
      await tester.pumpAndSettle();
    }

    testWidgets('a final key warns that attempts are marked again', (tester) async {
      final saved = await pumpCard(tester);
      expect(find.textContaining('marks every attempt'), findsNothing);
      await choose(tester, 'No official key', 'Final key');
      expect(find.textContaining('marks every attempt'), findsOneWidget);
      await tester.tap(find.text('Save the key'));
      await tester.pumpAndSettle();
      expect(saved.single.stage, 'final');
      expect(saved.single.outcome, 'one');
    });

    testWidgets('a dropped question sends no answer', (tester) async {
      final saved = await pumpCard(tester);
      await choose(tester, 'One answer', 'Dropped: marks to everyone');
      await tester.tap(find.text('Save the key'));
      await tester.pumpAndSettle();
      expect(saved.single.outcome, 'dropped');
      expect(saved.single.correctPosition, isNull);
    });

    testWidgets('several answers need at least two', (tester) async {
      final saved = await pumpCard(tester);
      await choose(tester, 'One answer', 'Several answers accepted');
      await tester.tap(find.text('Save the key'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(find.textContaining('at least two'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.text('Save the key'));
      await tester.pumpAndSettle();
      expect(saved.single.acceptedPositions, hasLength(2));
    });
  });
}
