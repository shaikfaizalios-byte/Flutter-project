import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/documents/application/documents_providers.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/question_bank/presentation/ai_read_card.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart' show FakeDocumentsRepository, doc;

ParseSummary summary({
  int found = 0,
  AiReadStatus status = AiReadStatus.none,
  int done = 0,
  int readByAi = 0,
}) => ParseSummary(
  segmentationStatus: 'completed',
  questionsFound: found,
  verified: 0,
  rejected: 0,
  withOpenIssues: 0,
  missingAnswers: 0,
  imageDependent: 0,
  sections: const [],
  documentIssues: const [],
  pageCount: 5,
  aiReadStatus: status,
  aiReadPagesDone: done,
  readByAi: readByAi,
);

Future<void> openPaper(
  WidgetTester tester,
  AppDatabase db, {
  required FakeQuestionsRepository questions,
  FakeAiRepository? ai,
}) async {
  final docs = FakeDocumentsRepository()
    ..listResponses = [
      [doc(id: 'doc1', filename: 'new-layout.pdf')],
    ];
  await pumpPrepLoopApp(
    tester,
    db,
    questions: questions,
    ai: ai,
    extraOverrides: [documentsRepositoryProvider.overrideWithValue(docs)],
  );
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Imported papers'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('new-layout.pdf'));
  await tester.pumpAndSettle();
  // Tapping a paper offers solve / read / review.
  await tester.tap(find.text('Review and correct questions'));
  await tester.pumpAndSettle();
}

Future<void> pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

void main() {
  testAppWidgets('a paper PrepLoop could not read is read with AI, with progress', (
    tester,
    db,
  ) async {
    final questions = FakeQuestionsRepository()..summary = summary();
    final ai = FakeAiRepository(enabled: true);
    await openPaper(tester, db, questions: questions, ai: ai);

    expect(find.textContaining("PrepLoop couldn't find questions"), findsOneWidget);
    expect(find.textContaining('pages of this paper are sent to the AI service'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Read with AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI will read the 5 pages'), findsOneWidget);
    expect(ai.calls, isEmpty); // nothing is sent before confirming

    // The server queues it; the card follows the reading.
    questions.summary = summary(status: AiReadStatus.queued);
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Read with AI')),
    );
    // While waiting, the progress bar keeps moving, so pump fixed steps (no settling).
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(ai.calls, ['read-paper:doc1']);
    expect(find.text('Waiting to start…'), findsOneWidget);

    questions.summary = summary(status: AiReadStatus.running, done: 3);
    await pumpFor(tester, aiReadPollInterval + const Duration(milliseconds: 500));
    expect(find.text('AI is reading the paper: page 3 of 5'), findsOneWidget);

    questions.summary = summary(found: 2, status: AiReadStatus.completed, done: 5, readByAi: 2);
    questions.questions['ai1'] = bankQuestion(id: 'ai1', documentId: 'doc1', readByAi: true);
    await tester.pump(aiReadPollInterval);
    await tester.pumpAndSettle();
    expect(find.text('2 questions read by AI'), findsOneWidget);
    expect(find.textContaining('compare them with the source page'), findsOneWidget);
    await scrollTo(tester, find.textContaining('Read by AI\n'));
    expect(find.textContaining('Read by AI\n'), findsOneWidget); // the question is labelled
    expect(find.text('Read again with AI'), findsOneWidget);

    await tester.pump(aiReadPollInterval * 2); // polling stopped: no more requests needed
    await tester.pumpAndSettle();
  });

  testAppWidgets('a failed reading says so and can be tried again', (tester, db) async {
    final questions = FakeQuestionsRepository()..summary = summary(status: AiReadStatus.failed);
    await openPaper(tester, db, questions: questions, ai: FakeAiRepository(enabled: true));
    expect(find.textContaining("AI couldn't read this paper"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Read with AI'), findsOneWidget);
  });

  testAppWidgets('without AI on the server the card is not shown', (tester, db) async {
    final questions = FakeQuestionsRepository()..summary = summary();
    await openPaper(tester, db, questions: questions);
    expect(find.text('Read with AI'), findsNothing);
  });
}
