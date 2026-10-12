import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';

import '../../helpers/pump_app.dart';

void main() {
  testAppWidgets('prompts to choose an exam when none is selected', (tester, db) async {
    await pumpPrepLoopApp(tester, db);

    expect(find.text('Choose your exam'), findsOneWidget);
    expect(find.text('You have not added any concepts yet.'), findsNothing);
  });

  testAppWidgets('shows selected exams, daily goal and real concept count', (tester, db) async {
    for (final title in ['A', 'B', 'C']) {
      await seed(
        tester,
        () => LocalConceptsRepository(db).create(
          ConceptDraft(
            examCode: 'SSC_CGL',
            title: title,
            subject: 'Maths',
            topic: 'Algebra',
            language: ContentLanguage.english,
          ),
        ),
      );
    }
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CGL'], dailyStudyMinutes: () => 60),
    );

    expect(find.text('SSC CGL'), findsOneWidget);
    expect(find.text('Choose your exam'), findsNothing);
    expect(find.text('Daily study goal: 1 h'), findsOneWidget);
    expect(find.text('You have 3 concepts saved.'), findsOneWidget);
  });

  testAppWidgets('counts down to the exam date', (tester, db) async {
    // testNow is 12 Oct 2026.
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(targetExamDate: () => CalendarDate(2026, 10, 22)),
    );
    await scrollTo(tester, find.text('10 days to go'));

    expect(find.text('10 days to go'), findsOneWidget);
    expect(find.text('Exam date: Oct 22, 2026'), findsOneWidget);
  });

  testAppWidgets('handles exam day and past dates', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(targetExamDate: () => CalendarDate(2026, 10, 12)),
    );
    await scrollTo(tester, find.text('Your exam is today'));
    expect(find.text('Your exam is today'), findsOneWidget);
  });

  testAppWidgets('says when the exam date has passed', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(targetExamDate: () => CalendarDate(2026, 9, 1)),
    );
    final passed = find.text('Your exam date has passed. You can update it in Profile.');
    await scrollTo(tester, passed);
    expect(passed, findsOneWidget);
  });

  testAppWidgets('weak topics stay an honest empty state', (tester, db) async {
    await pumpPrepLoopApp(tester, db);

    expect(find.textContaining('Not enough practice data yet'), findsOneWidget);
  });
}
