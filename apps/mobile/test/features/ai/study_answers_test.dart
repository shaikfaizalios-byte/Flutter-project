import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/widgets/search_field.dart';
import 'package:preploop/features/ai/data/ai_repository.dart';
import 'package:preploop/features/ai/presentation/paper_summary_screen.dart';
import 'package:preploop/features/ai/presentation/study_answer_view.dart';

import '../../helpers/pump_app.dart';
import '../concepts/concept_flow_test.dart' show openStudy;
import '../documents/paper_solve_read_test.dart' show openPaper, paperName;

SearchAnswerSource page(String key, int number, {String file = 'swift-notes.pdf'}) =>
    SearchAnswerSource(
      key: key,
      kind: SearchSourceKind.page,
      label: '$file, page $number',
      snippet: '...',
      verified: false,
      cited: true,
      documentId: 'doc1',
      pageNumber: number,
    );

final topics = SearchAnswer(
  kind: SearchAnswerKind.topics,
  found: true,
  confident: true,
  model: 'fake-model',
  requested: 10,
  items: const [
    StudyItem(title: 'Optionals', text: 'A value or nil.', cited: ['S1']),
    StudyItem(title: 'ARC', text: 'Counts references to free memory.', cited: ['S1', 'S2']),
  ],
  sources: [
    page('S1', 7),
    page('S2', 2, file: 'ios-interview.pdf'),
  ],
);

final summary = SearchAnswer(
  kind: SearchAnswerKind.summary,
  found: true,
  confident: false,
  model: 'fake-model',
  documentName: paperName,
  pagesRead: 40,
  pagesTotal: 60,
  items: const [
    StudyItem(title: '', text: 'The paper starts with optionals.', cited: ['S3']),
    StudyItem(title: '', text: 'It ends with memory.', cited: ['S40']),
  ],
  sources: [page('S3', 3), page('S40', 40)],
);

Future<void> askInStudy(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(AppSearchField), text);
  await tester.pump(const Duration(milliseconds: 400)); // paper search wait
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ask AI'));
  await tester.pump(const Duration(seconds: 1)); // AI settle wait
  await tester.pumpAndSettle();
}

void main() {
  test('the server reply is read, and older servers send none of it', () {
    final answer = SearchAnswer.fromJson({
      'kind': 'choose_paper',
      'found': false,
      'answer': null,
      'confident': true,
      'sources': <dynamic>[],
      'model': null,
      'items': <dynamic>[],
      'papers': [
        {'id': 'd1', 'name': 'a.pdf'},
      ],
    });
    expect(answer.kind, SearchAnswerKind.choosePaper);
    expect(answer.papers.single.name, 'a.pdf');

    final older = SearchAnswer.fromJson({
      'found': true,
      'answer': 'x [S1]',
      'confident': true,
      'sources': <dynamic>[],
      'model': 'm',
    });
    expect(older.kind, SearchAnswerKind.answer);
    expect(older.items, isEmpty);
  });

  test('an item lists its own sources, in its order', () {
    expect([for (final s in topics.sourcesOf(topics.items[1])) s.key], ['S1', 'S2']);
    expect([for (final s in topics.sourcesOf(topics.items[0])) s.key], ['S1']);
  });

  testAppWidgets('a topic list from the Study search: each topic, its answer and sources', (
    tester,
    db,
  ) async {
    final ai = FakeAiRepository(enabled: true)..searchAnswerResult = topics;
    await pumpPrepLoopApp(
      tester,
      db,
      ai: ai,
      questions: FakeQuestionsRepository([]),
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await askInStudy(tester, '10 important topics in iOS across pdfs');

    expect(ai.calls, contains('search:10 important topics in iOS across pdfs:SSC_CHSL'));
    expect(find.text('2 topics from your papers'), findsOneWidget);
    expect(find.text('Your papers cover 2 of the 10 topics you asked for.'), findsOneWidget);
    expect(find.text('Optionals'), findsOneWidget);
    expect(find.text('A value or nil.'), findsOneWidget);
    expect(find.text('ios-interview.pdf, page 2'), findsOneWidget);
    expect(find.textContaining('not a prediction of the exam'), findsOneWidget);
    expect(find.textContaining('Written by AI (fake-model)'), findsOneWidget);
    expect(ai.calls.where((c) => c.startsWith('quick:')), isEmpty); // no general answer
  });

  testAppWidgets('several papers: the search asks which one, then opens its summary', (
    tester,
    db,
  ) async {
    final ai = FakeAiRepository(enabled: true)
      ..searchAnswerResult = const SearchAnswer(
        kind: SearchAnswerKind.choosePaper,
        found: false,
        confident: true,
        sources: [],
        papers: [
          PaperChoice(id: 'doc1', name: 'swift-notes.pdf'),
          PaperChoice(id: 'doc2', name: 'ios-interview.pdf'),
        ],
      )
      ..paperSummaryResult = summary;
    await pumpPrepLoopApp(
      tester,
      db,
      ai: ai,
      questions: FakeQuestionsRepository([]),
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await askInStudy(tester, 'summarize this pdf');

    expect(find.text('Which paper should be summarised?'), findsOneWidget);
    await tester.tap(find.text('ios-interview.pdf'));
    await tester.pumpAndSettle();

    expect(find.byType(PaperSummaryScreen), findsOneWidget);
    expect(find.text('Summary: ios-interview.pdf'), findsOneWidget);
    expect(ai.calls, contains('summary:doc2:SSC_CHSL:en'));
  });

  testAppWidgets('no paper yet: the search says to import one', (tester, db) async {
    final ai = FakeAiRepository(enabled: true)
      ..searchAnswerResult = const SearchAnswer(
        kind: SearchAnswerKind.choosePaper,
        found: false,
        confident: true,
        sources: [],
      );
    await pumpPrepLoopApp(
      tester,
      db,
      ai: ai,
      questions: FakeQuestionsRepository([]),
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await askInStudy(tester, 'summarize this pdf');

    expect(find.text('Import a paper first, then ask for its summary.'), findsOneWidget);
  });

  testAppWidgets('a paper offers its summary, which says what it covers', (tester, db) async {
    final (_, ai) = await openPaper(tester, db);
    ai.paperSummaryResult = summary;

    await tester.tap(find.text('Summarize this paper'));
    await tester.pumpAndSettle();

    expect(ai.calls, contains('summary:doc1:SSC_CHSL:en'));
    expect(find.text('Summary of $paperName'), findsOneWidget);
    expect(find.text('The paper starts with optionals.'), findsOneWidget);
    expect(find.text('Page 3'), findsOneWidget); // each point names its page
    expect(find.textContaining('first 40 of 60 pages'), findsOneWidget);
    expect(find.textContaining("wasn't sure"), findsOneWidget);
    expect(find.byType(StudyAnswerView), findsOneWidget);
  });

  testAppWidgets('a paper with no readable text says so', (tester, db) async {
    final (_, ai) = await openPaper(tester, db);
    ai.paperSummaryResult = const SearchAnswer(
      kind: SearchAnswerKind.summary,
      found: false,
      confident: true,
      sources: [],
    );

    await tester.tap(find.text('Summarize this paper'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No readable text'), findsOneWidget);
  });

  testAppWidgets('without AI on the server no summary is offered', (tester, db) async {
    await openPaper(tester, db, ai: false);

    expect(find.text('Read this paper'), findsOneWidget);
    expect(find.text('Summarize this paper'), findsNothing);
  });
}
