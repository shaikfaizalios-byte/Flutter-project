import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/exams/application/active_exam.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart'
    show FakeDocumentsRepository, doc, openDocuments, overridesFor, samplePdf;

/// Exams are switched only from Home.
Future<void> switchExam(WidgetTester tester, String name) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Home')));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Switch exam'));
  await tester.pumpAndSettle();
  expect(find.text('Which exam?'), findsOneWidget);
  await tester.tap(find.widgetWithText(ListTile, name));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('each exam shows only its own papers; uploads go to the current exam', (
    tester,
    db,
  ) async {
    final repo = FakeDocumentsRepository()
      ..listResponses = [
        [
          doc(id: 'cgl', filename: 'CGL 2023.pdf', exam: 'SSC_CGL'),
          doc(id: 'chsl', filename: 'CHSL 2022.pdf', exam: 'SSC_CHSL'),
        ],
      ];
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL', 'SSC_CGL']),
      extraOverrides: overridesFor(repo, picked: samplePdf),
    );
    await openDocuments(tester, repo);

    // The first of the learner's exams is current: only its papers show.
    expect(find.text('CHSL 2022.pdf'), findsOneWidget);
    expect(find.text('CGL 2023.pdf'), findsNothing);

    // No switcher here: exams are switched from Home only.
    expect(find.byTooltip('Switch exam'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await switchExam(tester, 'SSC CGL');
    await openDocuments(tester, repo);
    expect(find.text('CGL 2023.pdf'), findsOneWidget);
    expect(find.text('CHSL 2022.pdf'), findsNothing);

    // A new paper is filed under the current exam.
    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(repo.uploads.single, ('CHSL 2022.pdf', 'SSC_CGL', ContentLanguage.english));

    // The choice is kept on the device.
    final saved = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals(activeExamKey))).getSingle();
    expect(saved.value, 'SSC_CGL');
  });

  testAppWidgets('progress counts the current exam only', (tester, db) async {
    final analytics = FakeAnalyticsRepository();
    await pumpPrepLoopApp(
      tester,
      db,
      analytics: analytics,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL', 'SSC_CGL']),
    );
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Progress')),
    );
    await tester.pumpAndSettle();
    expect(analytics.requestedExams.last, 'SSC_CHSL');

    await switchExam(tester, 'SSC CGL');
    await openTab(tester, 'Progress');
    expect(analytics.requestedExams.last, 'SSC_CGL');
  });
}
