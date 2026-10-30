import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:preploop/app/routes.dart';
import 'package:preploop/features/exams/presentation/exam_switcher.dart';
import 'package:preploop/app/app_shell.dart';
import 'package:preploop/features/dashboard/presentation/home_screen.dart';
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
  switchingExamsGoesHomeTests();

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

void switchingExamsGoesHomeTests() {
  testAppWidgets('switching exams leaves the old exam screens and lands on Home', (
    tester,
    db,
  ) async {
    // Desktop: the switcher sits in the sidebar, beside every screen.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL', 'SSC_CGL']),
    );
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push(AppRoutes.paperSolve('doc1', 'iOS interview.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Solve: iOS interview.pdf'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(AppSidebar), matching: find.byType(ExamSwitcher)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'SSC CGL'));
    await tester.pumpAndSettle();

    expect(find.text('Solve: iOS interview.pdf'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    expect(container.read(activeExamProvider), 'SSC_CGL');
  });
}
