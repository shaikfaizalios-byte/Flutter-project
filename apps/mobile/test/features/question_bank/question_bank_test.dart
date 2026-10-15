import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/widgets/search_field.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/documents/application/documents_providers.dart';
import 'package:preploop/features/documents/domain/imported_document.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart' show FakeDocumentsRepository, doc;

/// Opens the question bank (Practice tab, then Question bank).
Future<void> openPractice(
  WidgetTester tester, {
  String tab = 'Practice',
  String bank = 'Question bank',
}) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
  await tester.pumpAndSettle();
  await scrollTo(tester, find.text(bank));
  await tester.tap(find.text(bank));
  await tester.pumpAndSettle();
}

Future<void> openQuestion(WidgetTester tester, String stemStart) async {
  await tester.tap(find.textContaining(stemStart).first);
  await tester.pumpAndSettle();
}

FakeQuestionsRepository sampleBank() => FakeQuestionsRepository([
  bankQuestion(),
  bankQuestion(
    id: 'q2',
    number: 2,
    stem: 'Select the figure that completes the pattern.',
    section: 'General Intelligence',
    options: const ['A', 'B', 'C'],
    answer: null,
    issues: const ['missing_answer', 'incomplete_options', 'image_dependent'],
  ),
  bankQuestion(
    id: 'q3',
    number: 3,
    stem: 'Choose the synonym of RAPID.',
    section: 'English Language',
    exam: 'SSC_CGL',
    status: VerificationStatus.verified,
  ),
]);

void main() {
  testAppWidgets('practice tab shows the empty bank', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openPractice(tester);

    expect(find.text('Question bank'), findsOneWidget);
    expect(find.text('No questions yet'), findsOneWidget);
  });

  testAppWidgets('lists questions with numbers, sections and issue labels', (tester, db) async {
    await pumpPrepLoopApp(tester, db, questions: sampleBank());
    await openPractice(tester);

    expect(find.textContaining('Q.1  What is 20% of 150?'), findsOneWidget);
    expect(
      find.textContaining('Answer not found · Options incomplete · Needs the original figure'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Verified'), findsOneWidget);
  });

  testAppWidgets('filters and search are passed to the server query', (tester, db) async {
    final repo = sampleBank();
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);

    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.hasIssues, isTrue);
    expect(repo.queries.last.status, VerificationStatus.unverified);
    expect(find.textContaining('Select the figure'), findsOneWidget);
    expect(find.textContaining('20% of 150'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.tap(find.widgetWithText(FilterChip, 'SSC CGL'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.examCode, 'SSC_CGL');
    expect(find.textContaining('synonym of RAPID'), findsOneWidget);

    await tester.enterText(find.byType(AppSearchField), 'zzz');
    await tester.pumpAndSettle();
    expect(repo.queries.last.text, 'zzz');
    expect(find.text('No questions in this view.'), findsOneWidget);
  });

  testAppWidgets('server unreachable shows an offline state', (tester, db) async {
    final repo = sampleBank()..listFailure = const NetworkFailure();
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);

    expect(find.text("Can't reach the PrepLoop server"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testAppWidgets('review screen shows provenance, label and open problems', (tester, db) async {
    await pumpPrepLoopApp(tester, db, questions: sampleBank());
    await openPractice(tester);
    await openQuestion(tester, 'Q.2');

    expect(find.text('Q.2'), findsOneWidget);
    expect(find.text('From your PDF'), findsOneWidget);
    expect(find.text('From chsl-2024.pdf, page 1'), findsOneWidget);
    expect(find.text('Problems to check'), findsOneWidget);
    expect(find.text('• Answer not found'), findsOneWidget);
  });

  testAppWidgets('AI-generated questions are labelled as such', (tester, db) async {
    final repo = FakeQuestionsRepository([
      bankQuestion(id: 'ai1', stem: 'Practice: what is 10% of 90?', origin: QuestionOrigin.ai),
    ]);
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);
    await openQuestion(tester, 'Practice: what is');

    expect(find.text('AI-generated'), findsOneWidget);
    expect(find.text('From your PDF'), findsNothing);
  });

  testAppWidgets('approving without an answer is refused with an explanation', (tester, db) async {
    final repo = sampleBank();
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);
    await openQuestion(tester, 'Q.2');

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Fix the listed problems before approving.'), findsOneWidget);
    expect(repo.questions['q2']!.status, VerificationStatus.unverified);
  });

  testAppWidgets('fixing options and answer, then approving', (tester, db) async {
    final repo = sampleBank();
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);
    await openQuestion(tester, 'Q.2');

    await scrollTo(tester, find.text('Add option'));
    await tester.tap(find.text('Add option'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Option 4'), 'D');
    await scrollTo(tester, find.text('(2)'));
    await tester.tap(find.text('(2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    final (_, json) = repo.edits.last;
    expect(json['verification_status'], 'verified');
    expect(json['correct_option_position'], 2);
    expect((json['options']! as List<Object?>).length, 4);
    expect(find.text('Question approved'), findsOneWidget);
    expect(repo.questions['q2']!.status, VerificationStatus.verified);
  });

  testAppWidgets('rejecting a question', (tester, db) async {
    final repo = sampleBank();
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);
    await openQuestion(tester, 'Q.1');

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    expect(repo.edits.last.$2['verification_status'], 'rejected');
    expect(find.text('Question rejected'), findsOneWidget);
  });

  testAppWidgets('source page text can be opened for comparison', (tester, db) async {
    await pumpPrepLoopApp(tester, db, questions: sampleBank());
    await openPractice(tester);
    await openQuestion(tester, 'Q.1');

    await tester.tap(find.text('Source page text'));
    await tester.pumpAndSettle();

    expect(find.textContaining('(1) 20 (2) 30'), findsOneWidget);
  });

  testAppWidgets('document review: summary, document issues, questions, re-parse', (
    tester,
    db,
  ) async {
    final docs = FakeDocumentsRepository()
      ..listResponses = [
        [doc(id: 'doc1', filename: 'chsl-2024.pdf')],
      ];
    final repo = sampleBank();
    await pumpPrepLoopApp(
      tester,
      db,
      questions: repo,
      extraOverrides: [documentsRepositoryProvider.overrideWithValue(docs)],
    );
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Imported papers'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('chsl-2024.pdf'));
    await tester.pumpAndSettle();

    expect(find.text('Review questions'), findsOneWidget);
    expect(find.text('2 questions found'), findsOneWidget);
    expect(find.text('1 need attention'), findsOneWidget);
    expect(find.text('Some question numbers are missing: Missing: 3'), findsOneWidget);
    expect(
      find.text('No verified format linked, so question-count checks are skipped.'),
      findsOneWidget,
    );
    expect(repo.queries.last.documentId, 'doc1');
    await scrollTo(tester, find.textContaining('Q.1  What is 20% of 150?'));
    expect(find.textContaining('Q.1  What is 20% of 150?'), findsOneWidget);

    await tester.tap(find.text('Parse again'));
    await tester.pumpAndSettle();
    expect(repo.resegmentCalls, 1);
    expect(find.text('Questions parsed again. Your reviewed questions were kept.'), findsOneWidget);
  });

  testAppWidgets('only extracted documents open the review screen', (tester, db) async {
    final docs = FakeDocumentsRepository()
      ..listResponses = [
        [
          doc(
            id: 'p',
            filename: 'still-processing.pdf',
            status: DocumentStatus.processing,
            processed: 1,
          ),
        ],
      ];
    await pumpPrepLoopApp(
      tester,
      db,
      extraOverrides: [documentsRepositoryProvider.overrideWithValue(docs)],
    );
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Imported papers'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.text('still-processing.pdf'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Review questions'), findsNothing);
    // Let the poll timer fire so no timers are pending.
    await tester.pump(documentPollInterval);
  });

  testAppWidgets('question bank is localised in Hindi', (tester, db) async {
    await pumpPrepLoopApp(tester, db, deviceLocale: const Locale('hi'), questions: sampleBank());
    await openPractice(tester, tab: 'अभ्यास', bank: 'प्रश्न बैंक');

    expect(find.text('प्रश्न बैंक'), findsOneWidget);
    expect(find.text('ध्यान ज़रूरी'), findsOneWidget);
    expect(find.textContaining('उत्तर नहीं मिला'), findsOneWidget);
  });
}
