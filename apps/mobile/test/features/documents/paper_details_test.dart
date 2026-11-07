import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/localization/generated/app_localizations.dart';
import 'package:preploop/features/documents/application/documents_providers.dart';
import 'package:preploop/features/documents/domain/paper_details.dart';
import 'package:preploop/features/documents/presentation/paper_details_screen.dart';

import 'documents_screen_test.dart' show FakeDocumentsRepository;

const keyResult = AnswerKeyResult(
  applied: 3,
  agreed: 1,
  conflicts: 2,
  unmatched: [90, 91],
  ambiguous: false,
  withoutAnswer: 4,
  problems: [],
);

Future<void> pump(WidgetTester tester, FakeDocumentsRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [documentsRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PaperDetailsScreen(documentId: 'd1', filename: 'paper.pdf'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('blank details are cleared', () {
    const details = PaperDetails(stage: ' Tier-I ', sessionLabel: '', setCode: ' ');
    expect(details.toJson(), {'stage': 'Tier-I', 'session_label': null, 'set_code': null});
  });

  test('a key result is read from the server', () {
    final read = AnswerKeyResult.fromJson({
      'applied': 1,
      'agreed': 0,
      'conflicts': 0,
      'unmatched': [9],
      'ambiguous': false,
      'without_answer': 2,
      'problems': ['x'],
    });
    expect(read.applied, 1);
    expect(read.unmatched, [9]);
    expect(read.problems, ['x']);
  });

  testWidgets('details are saved', (tester) async {
    final repository = FakeDocumentsRepository();
    await pump(tester, repository);
    await tester.enterText(find.widgetWithText(TextField, 'Stage'), 'Prelims');
    await tester.enterText(find.widgetWithText(TextField, 'Set'), 'B');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.details.single.toJson()['stage'], 'Prelims');
    expect(repository.details.single.toJson()['set_code'], 'B');
  });

  testWidgets('no other sets, no card', (tester) async {
    await pump(tester, FakeDocumentsRepository());
    expect(find.text('Could be the same paper'), findsNothing);
  });

  testWidgets('another set is only marked when the reviewer says so', (tester) async {
    final repository = FakeDocumentsRepository()
      ..others = const [OtherSet(documentId: 'd2', filename: 'set-b.pdf', sharedShare: 0.96)];
    await pump(tester, repository);
    expect(find.text('set-b.pdf'), findsOneWidget);
    expect(find.text('96% of the questions match'), findsOneWidget);
    expect(repository.markedAsSetOf, isNull);
    await tester.tap(find.text('Same paper'));
    await tester.pumpAndSettle();
    expect(repository.markedAsSetOf, 'd2');
  });

  testWidgets('a pasted key reports what it did', (tester) async {
    final repository = FakeDocumentsRepository()..keyResult = keyResult;
    await pump(tester, repository);
    await tester.enterText(find.widgetWithText(TextField, 'Paste the key'), '1-(2)');
    await tester.ensureVisible(find.text('Apply key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply key'));
    await tester.pumpAndSettle();
    expect(repository.keyTexts, ['1-(2)']);
    expect(find.text('3 answers filled in'), findsOneWidget);
    expect(find.text('2 differ from the answer already set: flagged, not changed'), findsOneWidget);
    expect(find.text('No such question: 90, 91'), findsOneWidget);
    expect(find.text('4 questions still have no answer'), findsOneWidget);
  });

  testWidgets('an empty key sends nothing', (tester) async {
    final repository = FakeDocumentsRepository()..keyResult = keyResult;
    await pump(tester, repository);
    await tester.ensureVisible(find.text('Apply key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply key'));
    await tester.pumpAndSettle();
    expect(repository.keyTexts, isEmpty);
  });
}
