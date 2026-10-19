import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/documents/application/documents_providers.dart';
import 'package:preploop/features/insights/domain/repeats.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import '../helpers/pump_app.dart';
import 'documents/documents_screen_test.dart' show FakeDocumentsRepository, doc;
import 'insights/repeats_test.dart' show openRepeats;
import 'practice/practice_flow_test.dart' show pumpPractice, startPractice;
import 'question_bank/figures_topics_test.dart' show openPaperReview, paperSummary;
import 'question_bank/question_bank_test.dart' show openPractice, openQuestion;

const source = 'SSC CHSL 2024 Tier-I, 2 July 2024, shift 1';

void main() {
  testAppWidgets('shared bank questions are labelled in practice and cannot be bookmarked', (
    tester,
    db,
  ) async {
    await pumpPractice(
      tester,
      db,
      pool: [bankQuestion(status: VerificationStatus.verified, sharedSource: source)],
    );
    await startPractice(tester);

    expect(find.text('Shared bank · $source'), findsOneWidget);
    expect(find.byTooltip('Bookmark'), findsNothing);
    expect(find.byTooltip('Report a problem'), findsNothing);
  });

  testAppWidgets('a shared question opens read-only, with its source', (tester, db) async {
    final repo = FakeQuestionsRepository([
      bankQuestion(status: VerificationStatus.verified, sharedSource: source),
    ]);
    await pumpPrepLoopApp(tester, db, questions: repo);
    await openPractice(tester);
    await openQuestion(tester, 'What is 20%');

    expect(find.textContaining('From the shared bank (read-only)'), findsOneWidget);
    expect(find.text(source), findsOneWidget);
    expect(find.text('Correct answer: (2)'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Approve'), findsNothing);
  });

  testAppWidgets('repeats: the shared bank is a separate view; small samples are flagged', (
    tester,
    db,
  ) async {
    final insights = FakeInsightsRepository(
      report: const RepeatsReport(papers: PapersBasis(total: 2, dated: 0, undated: 2)),
    );
    await pumpPrepLoopApp(tester, db, insights: insights);
    await openRepeats(tester);

    expect(find.text('Based on 2 of your papers'), findsOneWidget);
    expect(find.textContaining('Small sample: 2 papers. Below 5 papers'), findsOneWidget);

    await tester.tap(find.text('Shared bank'));
    await tester.pumpAndSettle();
    expect(insights.scopes.last, 'shared');
    expect(find.text('No shared papers yet'), findsOneWidget);

    insights.sharedReport = const RepeatsReport(
      papers: PapersBasis(total: 6, dated: 6, undated: 0, years: [2022, 2024]),
    );
    await tester.tap(find.text('Your papers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shared bank'));
    await tester.pumpAndSettle();
    expect(find.text('Based on 6 shared papers (2022–2024)'), findsOneWidget);
    expect(find.textContaining('Small sample'), findsNothing);
  });

  testAppWidgets('paper review: verify every clean question after confirming', (tester, db) async {
    final repo = FakeQuestionsRepository([
      bankQuestion(),
      bankQuestion(id: 'q2', number: 2, stem: 'No answer yet', answer: null),
    ])..summary = paperSummary();
    await pumpPrepLoopApp(
      tester,
      db,
      questions: repo,
      extraOverrides: [
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository()
            ..listResponses = [
              [doc(id: 'doc1', filename: 'chsl-2024.pdf')],
            ],
        ),
      ],
    );
    await openPaperReview(tester);

    await tester.tap(find.text('Verify all clean questions'));
    await tester.pumpAndSettle();
    expect(find.text('Verify clean questions?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(repo.verifyCleanCalls, ['doc1']);
    expect(find.text('1 verified · 1 still need review'), findsOneWidget);
    expect(repo.questions['q1']!.status, VerificationStatus.verified);
    expect(repo.questions['q2']!.status, VerificationStatus.unverified);
  });
}
