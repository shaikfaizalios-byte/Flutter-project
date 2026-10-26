import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/study_plan/data/study_profile_repository.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';

import '../../helpers/pump_app.dart';

void main() {
  testAppWidgets('a fresh install starts in onboarding', (tester, db) async {
    await pumpPrepLoopApp(tester, db, studyProfile: const StudyProfile());

    expect(find.text('Welcome to PrepLoop'), findsOneWidget);
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testAppWidgets('completing onboarding saves answers and shows Home', (tester, db) async {
    await pumpPrepLoopApp(tester, db, studyProfile: const StudyProfile());

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Which exam are you preparing for?'), findsOneWidget);
    await tester.tap(find.text('SSC CHSL'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next')); // exam date: skipped
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('How much time can you study each day?'), findsOneWidget);
    await tester.tap(find.text('1 h 30 min'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 5 of 5'), findsOneWidget);
    await tester.tap(find.text('Start studying'));
    await tester.pumpAndSettle();

    expect(find.text('Your study loop'), findsOneWidget);
    expect(find.text('SSC CHSL'), findsOneWidget);
    expect(find.text('0 of 90 min focused today'), findsOneWidget); // the daily goal on Today

    final stored = await seed(tester, () => StudyProfileRepository(db).load());
    expect(stored.examCodes, ['SSC_CHSL']);
    expect(stored.dailyStudyMinutes, 90);
    expect(stored.targetExamDate, isNull);
    expect(stored.onboardingCompleted, isTrue);
  });

  testAppWidgets('Back returns to the previous step', (tester, db) async {
    await pumpPrepLoopApp(tester, db, studyProfile: const StudyProfile());
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to PrepLoop'), findsOneWidget);
  });

  testAppWidgets('Skip setup goes straight to Home and is remembered', (tester, db) async {
    await pumpPrepLoopApp(tester, db, studyProfile: const StudyProfile());

    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(find.text('Your study loop'), findsOneWidget);
    expect(find.text('Choose your exam'), findsOneWidget);
    final stored = await seed(tester, () => StudyProfileRepository(db).load());
    expect(stored.onboardingCompleted, isTrue);
  });

  testAppWidgets('choosing Hindi during onboarding switches the UI immediately', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(tester, db, studyProfile: const StudyProfile());

    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('PrepLoop में आपका स्वागत है'), findsOneWidget);
    expect(find.text('आगे'), findsOneWidget);
  });

  // Criterion 8: onboarding → create concept, end to end (widget-level).
  testAppWidgets('onboarding then creating a concept uses the chosen exam', (tester, db) async {
    await pumpPrepLoopApp(tester, db, studyProfile: const StudyProfile());
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSC CHSL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add concept'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Idioms');
    await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'English');
    await tester.enterText(find.widgetWithText(TextFormField, 'Topic'), 'Vocabulary');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('SSC CHSL · English › Vocabulary'), findsOneWidget);
    final stored = await seed(tester, () => LocalConceptsRepository(db).watch().first);
    expect(stored.single.examCode, 'SSC_CHSL');
  });
}
