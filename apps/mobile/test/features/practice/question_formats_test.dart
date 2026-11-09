import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/localization/generated/app_localizations.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';
import 'package:preploop/features/practice/presentation/format_answers.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

SessionItemView item(String format, {Map<String, List<String>>? data, int options = 3}) =>
    SessionItemView(
      position: 1,
      options: [
        for (var i = 1; i <= options; i++)
          QuestionOption(position: i, label: '$i', text: 'Option $i'),
      ],
      verified: true,
      bookmarked: false,
      format: format,
      formatData: data,
    );

Future<List<Map<String, dynamic>>> pump(WidgetTester tester, SessionItemView view) async {
  final sent = <Map<String, dynamic>>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResponseAnswer(
              item: view,
              locked: false,
              onSubmit: (response) async {
                sent.add(response);
                return true;
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sent;
}

void main() {
  test('only three formats need a fuller answer', () {
    expect(item('multiple_correct').takesResponse, isTrue);
    expect(item('match').takesResponse, isTrue);
    expect(item('ordering').takesResponse, isTrue);
    for (final format in ['single_correct', 'assertion_reason', 'statement', 'true_false']) {
      expect(item(format).takesResponse, isFalse);
    }
  });

  test('a session item reads its format, and older data means single correct', () {
    final json = <String, dynamic>{
      'position': 1,
      'options': <dynamic>[],
      'figures': <dynamic>[],
      'verified': true,
      'bookmarked': false,
      'source': <String, dynamic>{},
    };
    expect(SessionItemView.fromJson(json).format, 'single_correct');
    final read = SessionItemView.fromJson({
      ...json,
      'format': 'match',
      'format_data': {
        'left': ['a'],
        'right': ['x', 'y'],
      },
      'response': {
        'pairs': [
          [0, 1],
        ],
      },
    });
    expect(read.formatData!['right'], ['x', 'y']);
    expect(read.answered, isTrue);
  });

  group('the correct answer in words', () {
    AnswerFeedback spec(Map<String, dynamic> value) => AnswerFeedback(correctSpec: value);

    test('multiple correct names the options', () {
      expect(
        correctAnswerText(
          item('multiple_correct'),
          spec({
            'correct_positions': [1, 3],
          }),
        ),
        '1, 3',
      );
    });

    test('numeric shows the value, its tolerance or its range', () {
      final numeric = item('numeric');
      expect(correctAnswerText(numeric, spec({'value': '2.5'})), '2.5');
      expect(correctAnswerText(numeric, spec({'value': '2.5', 'tolerance': '0.01'})), '2.5 ± 0.01');
      expect(correctAnswerText(numeric, spec({'min': '2.4', 'max': '2.6'})), '2.4 – 2.6');
    });

    test('fill in the blank lists what is accepted', () {
      expect(
        correctAnswerText(
          item('fill_blank'),
          spec({
            'accepted': ['a', 'b'],
          }),
        ),
        'a / b',
      );
    });

    test('match pairs the lists, ordering lists the items', () {
      final match = item(
        'match',
        data: {
          'left': ['a', 'b'],
          'right': ['x', 'y'],
        },
      );
      expect(
        correctAnswerText(
          match,
          spec({
            'pairs': [
              [0, 1],
              [1, 0],
            ],
          }),
        ),
        'a → y, b → x',
      );
      final ordering = item(
        'ordering',
        data: {
          'items': ['p', 'q', 'r'],
        },
      );
      expect(
        correctAnswerText(
          ordering,
          spec({
            'order': [2, 0, 1],
          }),
        ),
        'r, p, q',
      );
    });

    test('nothing to say without a spec', () {
      expect(correctAnswerText(item('single_correct'), const AnswerFeedback()), isNull);
    });
  });

  testWidgets('multiple correct sends every ticked option', (tester) async {
    final sent = await pump(tester, item('multiple_correct'));
    final save = find.widgetWithText(FilledButton, 'Save answer');
    expect(tester.widget<FilledButton>(save).onPressed, isNull); // nothing ticked yet
    await tester.tap(find.text('1. Option 1'));
    await tester.tap(find.text('3. Option 3'));
    await tester.pumpAndSettle();
    await tester.tap(save);
    expect(sent.single, {
      'positions': [1, 3],
    });
  });

  testWidgets('match needs every item paired', (tester) async {
    final sent = await pump(
      tester,
      item(
        'match',
        options: 0,
        data: {
          'left': ['a', 'b'],
          'right': ['x', 'y'],
        },
      ),
    );
    final save = find.widgetWithText(FilledButton, 'Save answer');
    Future<void> choose(int row, String text) async {
      await tester.tap(find.byType(DropdownButton<int>).at(row));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).last);
      await tester.pumpAndSettle();
    }

    await choose(0, 'y');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await choose(1, 'x');
    await tester.tap(save);
    expect(sent.single, {
      'pairs': [
        [0, 1],
        [1, 0],
      ],
    });
  });

  testWidgets('items are moved up and down, then sent in that order', (tester) async {
    final sent = await pump(
      tester,
      item(
        'ordering',
        options: 0,
        data: {
          'items': ['p', 'q', 'r'],
        },
      ),
    );
    await tester.tap(find.byTooltip('Move down').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save answer'));
    expect(sent.single, {
      'order': [1, 0, 2],
    });
  });
}
