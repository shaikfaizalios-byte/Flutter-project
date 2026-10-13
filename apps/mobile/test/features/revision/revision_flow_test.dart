import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:preploop/app/routes.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/practice/application/practice_providers.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/revision/data/revision_repository.dart';

import '../../helpers/pump_app.dart';

/// Saves a concept and (optionally) puts it on the schedule so it is due today.
Future<Concept> seedConcept(
  WidgetTester tester,
  AppDatabase db, {
  String title = 'Percent change',
  String notes = 'new − old ÷ old × 100',
  bool dueToday = false,
}) => seed(tester, () async {
  final concept = await LocalConceptsRepository(db, clock: () => testNow).create(
    ConceptDraft(
      examCode: 'SSC_CGL',
      title: title,
      notes: notes,
      subject: 'Quantitative Aptitude',
      topic: 'Percentage',
      language: ContentLanguage.english,
    ),
  );
  if (dueToday) {
    // Added yesterday → Day 1 is today.
    await RevisionRepository(
      db,
      clock: () => testNow.subtract(const Duration(days: 1)),
    ).addConcept(concept.id);
  }
  return concept;
});

Future<void> openRevision(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Revision'));
  await tester.pumpAndSettle();
}

void push(WidgetTester tester, String location) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location);

void main() {
  testAppWidgets('empty revision explains how to add cards', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openRevision(tester);

    expect(find.text('No flashcards yet'), findsOneWidget);
    expect(find.textContaining('Questions to revisit'), findsOneWidget);
  });

  testAppWidgets('a concept can be added to revision from its details', (tester, db) async {
    final concept = await seedConcept(tester, db);
    await pumpPrepLoopApp(tester, db);
    push(tester, AppRoutes.concept(concept.id));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to revision'));
    await tester.pumpAndSettle();

    expect(find.text('In revision'), findsOneWidget);
    expect(find.text('Next review: Tomorrow'), findsOneWidget);
  });

  testAppWidgets('due cards: dashboard count, recall, reveal, rate, reschedule', (
    tester,
    db,
  ) async {
    await seedConcept(tester, db, dueToday: true);
    await pumpPrepLoopApp(tester, db);

    expect(find.text('Revise 1 flashcard'), findsOneWidget);
    expect(find.textContaining('1 due today'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Start').first);
    await tester.pumpAndSettle();

    expect(find.text('Card 1 of 1'), findsOneWidget);
    expect(find.text('Percent change'), findsOneWidget);
    expect(find.text('Your notes'), findsOneWidget);
    expect(find.text('new − old ÷ old × 100'), findsNothing);

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    expect(find.text('new − old ÷ old × 100'), findsOneWidget);
    // Day 1 → Day 4 on Good; the buttons say when each choice brings the card back.
    expect(find.text('In 3 days'), findsOneWidget);
    expect(find.text('In 5 days'), findsOneWidget);
    expect(find.text('Tomorrow'), findsNWidgets(2)); // Forgot and Hard

    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    expect(find.text('You revised 1 card'), findsOneWidget);
    expect(find.text('Good: 1'), findsOneWidget);

    final card = (await seed(tester, () => db.select(db.revisionCards).get())).single;
    expect(card.dueOn, CalendarDate.fromDateTime(testNow).addDays(3).toIsoString());
    final log = await seed(tester, () => db.select(db.cardReviews).get());
    expect(log.single.rating, 'good');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No revision due today. Next: In 3 days'), findsOneWidget);
  });

  testAppWidgets('the revision ladder can be changed and is validated', (tester, db) async {
    await seedConcept(tester, db, dueToday: true);
    await pumpPrepLoopApp(tester, db);
    await openRevision(tester);
    expect(find.text('Review on day 1 · 4 · 7 after adding a card'), findsOneWidget);

    await tester.tap(find.text('Change schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9, 0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter 1 to 8 different days'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9, 2 5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Review on day 2 · 5 · 9 after adding a card'), findsOneWidget);
    final stored = await seed(tester, () => RevisionRepository(db).loadSettings());
    expect(stored.dayOffsets, [2, 5, 9]);
  });

  testAppWidgets('wrong answers from practice become question cards (verified only)', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(
      tester,
      db,
      extraOverrides: [
        incorrectQuestionsProvider.overrideWith(
          (ref) async => [
            bankQuestion(status: VerificationStatus.verified),
            bankQuestion(id: 'q2', number: 2, stem: 'Not reviewed?'),
          ],
        ),
      ],
    );
    push(tester, AppRoutes.incorrect);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revise these'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 card added to revision.'), findsOneWidget);
    expect(find.textContaining('1 not added'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openRevision(tester);
    await scrollTo(tester, find.text('What is 20% of 150?'));
    expect(find.text('What is 20% of 150?'), findsOneWidget);
    expect(find.textContaining('Answered wrong in practice'), findsOneWidget);
  });

  testAppWidgets('question cards show their source and the answer', (tester, db) async {
    await seed(
      tester,
      () => RevisionRepository(
        db,
        clock: () => testNow.subtract(const Duration(days: 1)),
      ).addQuestions([bankQuestion(status: VerificationStatus.verified)]),
    );
    await pumpPrepLoopApp(tester, db);
    push(tester, AppRoutes.revisionReview);
    await tester.pumpAndSettle();

    expect(find.text('From your PDF · chsl-2024.pdf, p. 1'), findsOneWidget);
    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('(2) 30'), findsOneWidget);
  });

  testAppWidgets('revision is localised in Hindi', (tester, db) async {
    await seedConcept(tester, db, dueToday: true);
    await pumpPrepLoopApp(tester, db, deviceLocale: const Locale('hi'));

    expect(find.text('1 फ्लैशकार्ड दोहराएँ'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'शुरू करें').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('उत्तर दिखाएँ'));
    await tester.pumpAndSettle();
    expect(find.text('भूल गया'), findsOneWidget);
    expect(find.text('3 दिन में'), findsOneWidget);
  });
}
