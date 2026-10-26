import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/documents/application/documents_providers.dart';
import 'package:preploop/features/documents/domain/imported_document.dart';

import '../../helpers/pump_app.dart';
import 'documents_screen_test.dart'
    show FakeDocumentsRepository, doc, openDocuments, overridesFor, samplePdf;

void main() {
  testAppWidgets('an import shows each step on Home and says when the paper is ready', (
    tester,
    db,
  ) async {
    final repo = FakeDocumentsRepository();
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
      extraOverrides: overridesFor(repo, picked: samplePdf),
    );
    await openDocuments(tester, repo);
    ImportedDocument paper(DocumentStatus status, {int done = 0, String? seg, int found = 0}) =>
        doc(
          id: 'new',
          filename: 'CHSL 2022.pdf',
          exam: 'SSC_CHSL',
          status: status,
          processed: done,
          segmentation: seg,
          questions: found,
          toCheck: found == 0 ? 0 : 9,
        );
    repo.listResponses = [
      [paper(DocumentStatus.queued)],
    ];

    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Leave the papers screen: Home follows the import.
    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Home')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Importing CHSL 2022.pdf: Waiting to be processed'), findsOneWidget);

    repo.listResponses = [
      [paper(DocumentStatus.processing, done: 1)],
    ];
    await tester.pump(documentPollInterval);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Importing CHSL 2022.pdf: Reading page 2 of 4'), findsOneWidget);

    repo.listResponses = [
      [paper(DocumentStatus.completed, done: 4, seg: 'pending')],
    ];
    await tester.pump(documentPollInterval);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Importing CHSL 2022.pdf: Pages read · finding the questions…'),
      findsOneWidget,
    );

    repo.listResponses = [
      [paper(DocumentStatus.completed, done: 4, found: 87)],
    ];
    await tester.pump(documentPollInterval);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('CHSL 2022.pdf is ready: 87 questions found · 9 need a look'), findsOneWidget);
    expect(find.textContaining('Importing'), findsNothing); // no longer in progress

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing); // the paper's review screen
  });
}
