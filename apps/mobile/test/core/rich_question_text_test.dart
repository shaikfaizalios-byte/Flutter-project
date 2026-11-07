import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/app_features.dart';
import 'package:preploop/core/widgets/rich_question_text.dart';

String describe(TextPart part) => switch (part) {
  PlainPart(:final text) => 'text:$text',
  MathPart(:final tex, :final display) => '${display ? 'display' : 'inline'}:$tex',
  TablePart(:final rows) => 'table:${rows.length}',
};

List<String> split(String text) => splitQuestionText(text).map(describe).toList();

Future<void> pump(WidgetTester tester, String text, {required bool on, ThemeData? theme}) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [appFeaturesProvider.overrideWithValue(AppFeatures(examProfiles: on))],
        child: MaterialApp(
          theme: theme,
          home: Scaffold(body: RichQuestionText(text)),
        ),
      ),
    );

void main() {
  test('plain text stays one piece', () {
    expect(split('What is 20 percent of 150?'), ['text:What is 20 percent of 150?']);
  });

  test('inline maths in both notations', () {
    expect(split(r'If $x^2 = 4$ then'), ['text:If ', 'inline:x^2 = 4', 'text: then']);
    expect(split(r'If \(x^2\) then'), ['text:If ', 'inline:x^2', 'text: then']);
  });

  test('display maths in both notations', () {
    expect(split(r'$$\frac{a}{b}$$'), [r'display:\frac{a}{b}']);
    expect(split(r'Find \[ E = mc^2 \] now'), ['text:Find ', 'display:E = mc^2', 'text: now']);
  });

  test('money stays text', () {
    expect(split(r'He paid $5 and then $6.'), [r'text:He paid $5 and then $6.']);
    expect(split(r'A pen costs $ 5 and a book $ 6'), [r'text:A pen costs $ 5 and a book $ 6']);
    expect(split(r'Costs US$5 or US$6'), [r'text:Costs US$5 or US$6']);
  });

  test('an escaped dollar is not maths, and a lone dollar is left alone', () {
    expect(split(r'Price \$5 and \$6'), [r'text:Price \$5 and \$6']);
    expect(split(r'Only $5 here'), [r'text:Only $5 here']);
  });

  test('a pipe table needs its rule line', () {
    final table = splitQuestionText(
      'Sales\n| Year | Units |\n|---|---|\n| 2020 | 5 |\n| 2021 | 7 |',
    );
    expect(table.map(describe), ['text:Sales', 'table:3']);
    expect((table[1] as TablePart).rows[1], ['2020', '5']);
    expect(split('a | b is not a table'), ['text:a | b is not a table']);
  });

  test('text after a table carries on', () {
    expect(split('| A |\n|---|\n| 1 |\nWhich is right?'), ['table:2', 'text:Which is right?']);
  });

  testWidgets('with the flag off, text is exactly what it always was', (tester) async {
    await pump(tester, r'If $x^2 = 4$ then', on: false);
    expect(find.byType(Math), findsNothing);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('plain text stays selectable with the flag on', (tester) async {
    await pump(tester, 'Plain question', on: true);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('inside something tappable, plain text takes no taps', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: RichQuestionText('Option', selectable: false))),
      ),
    );
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Option'), findsOneWidget);
  });

  testWidgets('maths renders', (tester) async {
    await pump(tester, r'If $\frac{a}{b}$ then $$x^2$$', on: true);
    expect(find.byType(Math), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TeX that cannot be read is shown as written', (tester) async {
    await pump(tester, r'If $\notacommand{a}$ then', on: true);
    expect(tester.takeException(), isNull);
    expect(find.text(r'\notacommand{a}'), findsOneWidget);
  });

  testWidgets('maths follows the theme in dark mode', (tester) async {
    await pump(tester, r'$x$', on: true, theme: ThemeData.dark());
    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('tables render', (tester) async {
    await pump(tester, '| A | B |\n|---|---|\n| 1 |', on: true);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
