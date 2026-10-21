import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/documents/application/documents_providers.dart';
import 'package:preploop/features/documents/domain/documents_repository.dart';
import 'package:preploop/features/documents/domain/imported_document.dart';

import '../../helpers/pump_app.dart';

ImportedDocument doc({
  String id = 'd1',
  String filename = 'CGL 2023 Tier 1.pdf',
  DocumentStatus status = DocumentStatus.completed,
  int pages = 4,
  int processed = 4,
  int review = 0,
  String? errorCode,
  String exam = 'SSC_CGL',
}) => ImportedDocument(
  id: id,
  filename: filename,
  examCode: exam,
  language: ContentLanguage.english,
  status: status,
  pageCount: pages,
  pagesProcessed: processed,
  needsReviewCount: review,
  errorCode: errorCode,
  createdAt: DateTime.utc(2026, 10, 13),
);

class FakeDocumentsRepository implements DocumentsRepository {
  /// Each call to [list] returns the next entry (the last one repeats).
  List<Object> listResponses = [const <ImportedDocument>[]];
  int listCalls = 0;
  AppFailure? uploadFailure;
  Completer<void>? uploadGate;
  final uploads = <(String name, String exam, ContentLanguage language)>[];
  final deleted = <String>[];

  @override
  Future<List<ImportedDocument>> list() async {
    final response = listResponses[listCalls.clamp(0, listResponses.length - 1)];
    listCalls++;
    if (response is AppFailure) throw response;
    return response as List<ImportedDocument>;
  }

  @override
  Future<ImportedDocument> upload(
    UploadSource source, {
    required String examCode,
    required ContentLanguage language,
    void Function(double progress)? onProgress,
    UploadCancellation? cancellation,
  }) async {
    uploads.add((source.name, examCode, language));
    onProgress?.call(0.5);
    if (uploadGate != null) await uploadGate!.future;
    if (cancellation?.isCancelled ?? false) throw const CancelledFailure();
    if (uploadFailure != null) throw uploadFailure!;
    return doc(id: 'new', filename: source.name, status: DocumentStatus.queued, processed: 0);
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

final samplePdf = UploadSource(
  name: 'CHSL 2022.pdf',
  length: 3,
  open: () => Stream.value([1, 2, 3]),
);

Future<void> openDocuments(
  WidgetTester tester,
  FakeDocumentsRepository repo, {
  UploadSource? picked,
}) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Imported papers'));
  await tester.pumpAndSettle();
}

List<Override> overridesFor(FakeDocumentsRepository repo, {UploadSource? picked}) => [
  documentsRepositoryProvider.overrideWithValue(repo),
  pdfPickerProvider.overrideWithValue(() async => picked),
];

void main() {
  testAppWidgets('empty state explains importing', (tester, db) async {
    final repo = FakeDocumentsRepository();
    await pumpPrepLoopApp(tester, db, extraOverrides: overridesFor(repo));
    await openDocuments(tester, repo);

    expect(find.text('No papers imported yet'), findsOneWidget);
    expect(find.text('Import PDF'), findsOneWidget);
  });

  testAppWidgets('lists documents with status, pages and review warnings', (tester, db) async {
    final repo = FakeDocumentsRepository()
      ..listResponses = [
        [
          doc(id: 'a', filename: 'Done.pdf', review: 2),
          doc(
            id: 'b',
            filename: 'Broken.pdf',
            status: DocumentStatus.failed,
            errorCode: 'processing_timeout',
          ),
        ],
      ];
    await pumpPrepLoopApp(tester, db, extraOverrides: overridesFor(repo));
    await openDocuments(tester, repo);

    expect(find.text('Done.pdf'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('2 pages need review'), findsOneWidget);
    expect(find.text('Processing failed'), findsOneWidget);
    expect(find.text('This document took too long to process.'), findsOneWidget);
    expect(find.text('SSC CGL · English · 4 pages'), findsNWidgets(2));
  });

  testAppWidgets('polls while a document is processing', (tester, db) async {
    final repo = FakeDocumentsRepository()
      ..listResponses = [
        [doc(status: DocumentStatus.processing, processed: 1)],
        [doc(status: DocumentStatus.completed)],
      ];
    await pumpPrepLoopApp(tester, db, extraOverrides: overridesFor(repo));
    await openDocuments(tester, repo);
    expect(find.text('Reading page 2 of 4'), findsOneWidget);

    await tester.pump(documentPollInterval);
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(repo.listCalls, 2);
    // Nothing active any more: no further polling.
    await tester.pump(documentPollInterval * 2);
    expect(repo.listCalls, 2);
  });

  testAppWidgets('offline shows a connectivity message and retries', (tester, db) async {
    final repo = FakeDocumentsRepository()
      ..listResponses = [const NetworkFailure(), <ImportedDocument>[]];
    await pumpPrepLoopApp(tester, db, extraOverrides: overridesFor(repo));
    await openDocuments(tester, repo);

    expect(find.text("Can't reach the PrepLoop server"), findsOneWidget);
    expect(find.textContaining('Your concepts still work offline'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No papers imported yet'), findsOneWidget);
  });

  testAppWidgets('import: pick, choose exam and language, upload', (tester, db) async {
    final repo = FakeDocumentsRepository();
    await pumpPrepLoopApp(
      tester,
      db,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
      extraOverrides: overridesFor(repo, picked: samplePdf),
    );
    await openDocuments(tester, repo);
    repo.listResponses = [
      [
        doc(
          id: 'new',
          filename: 'CHSL 2022.pdf',
          status: DocumentStatus.queued,
          processed: 0,
          exam: 'SSC_CHSL',
        ),
      ],
      [doc(id: 'new', filename: 'CHSL 2022.pdf', exam: 'SSC_CHSL')],
    ];
    repo.listCalls = 0;

    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();
    // No syllabus yet for this exam: the learner is asked first and skips it.
    expect(find.text('Add the SSC CHSL syllabus first?'), findsOneWidget);
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Import "CHSL 2022.pdf"'), findsOneWidget);
    await tester.tap(find.text('हिन्दी'));
    await tester.tap(find.text('Upload'));
    // Pump frames (not pumpAndSettle, which would also run the poll timer).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repo.uploads.single, ('CHSL 2022.pdf', 'SSC_CHSL', ContentLanguage.hindi));
    expect(find.text('Upload complete. Processing has started.'), findsOneWidget);
    expect(find.text('Waiting to be processed'), findsOneWidget);

    await tester.pump(documentPollInterval);
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testAppWidgets('cancelling the picker does nothing', (tester, db) async {
    final repo = FakeDocumentsRepository();
    await pumpPrepLoopApp(tester, db, extraOverrides: overridesFor(repo));
    await openDocuments(tester, repo);

    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(repo.uploads, isEmpty);
  });

  testAppWidgets('shows progress while uploading and can cancel', (tester, db) async {
    final repo = FakeDocumentsRepository()..uploadGate = Completer<void>();
    await pumpPrepLoopApp(tester, db, extraOverrides: overridesFor(repo, picked: samplePdf));
    await openDocuments(tester, repo);
    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Uploading CHSL 2022.pdf…'), findsOneWidget);
    expect(find.text('Import PDF'), findsNothing, reason: 'no second upload while one runs');
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 0.5);

    await tester.tap(find.text('Cancel'));
    repo.uploadGate!.complete();
    await tester.pumpAndSettle();

    expect(find.textContaining('Uploading'), findsNothing);
    expect(find.text('Import PDF'), findsOneWidget);
  });

  for (final (code, message) in [
    ('file_too_large', 'This file is larger than the allowed size.'),
    ('unsupported_file_type', 'Only PDF files can be imported.'),
    ('encrypted_pdf', 'This PDF is password-protected. Remove the password and try again.'),
    ('too_many_pages', 'This PDF has too many pages.'),
    (
      'rate_limited',
      'You have uploaded several files recently. Please wait a while and try again.',
    ),
  ]) {
    testAppWidgets('upload error "$code" is explained', (tester, db) async {
      final repo = FakeDocumentsRepository()
        ..uploadFailure = ServerFailure(statusCode: 422, code: code);
      await pumpPrepLoopApp(tester, db, extraOverrides: overridesFor(repo, picked: samplePdf));
      await openDocuments(tester, repo);
      await tester.tap(find.text('Import PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
    });
  }

  testAppWidgets('delete asks for confirmation', (tester, db) async {
    final repo = FakeDocumentsRepository()
      ..listResponses = [
        [doc()],
        <ImportedDocument>[],
      ];
    await pumpPrepLoopApp(tester, db, extraOverrides: overridesFor(repo));
    await openDocuments(tester, repo);

    await tester.tap(find.byTooltip('Options for CGL 2023 Tier 1.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this paper?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['d1']);
    expect(find.text('Paper deleted'), findsOneWidget);
    expect(find.text('No papers imported yet'), findsOneWidget);
  });

  testAppWidgets('import screen is localised in Hindi', (tester, db) async {
    final repo = FakeDocumentsRepository();
    await pumpPrepLoopApp(
      tester,
      db,
      deviceLocale: const Locale('hi'),
      extraOverrides: overridesFor(repo),
    );
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('अध्ययन')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('आयात किए गए प्रश्न-पत्र'));
    await tester.pumpAndSettle();

    expect(find.text('अभी कोई प्रश्न-पत्र आयात नहीं किया गया'), findsOneWidget);
    expect(find.text('PDF आयात करें'), findsOneWidget);
  });
}
