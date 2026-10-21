import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/exams/application/active_exam.dart';

import '../../helpers/pump_app.dart';
import '../documents/documents_screen_test.dart'
    show FakeDocumentsRepository, doc, openDocuments, overridesFor, samplePdf;

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

    await tester.tap(find.byTooltip('Switch exam'));
    await tester.pumpAndSettle();
    expect(find.text('Which exam?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'SSC CGL'));
    await tester.pumpAndSettle();
    expect(find.text('CGL 2023.pdf'), findsOneWidget);
    expect(find.text('CHSL 2022.pdf'), findsNothing);

    // A new paper is filed under the current exam.
    await tester.tap(find.text('Import PDF'));
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
}
