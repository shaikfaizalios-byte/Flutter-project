import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/core/utils/external_links.dart';
import 'package:preploop/features/ai/data/ai_repository.dart';
import 'package:preploop/core/widgets/search_field.dart';

import '../../helpers/pump_app.dart';
import 'concept_flow_test.dart' show openStudy, seedConcept;

final paperQuestions = FakeQuestionsRepository([
  bankQuestion(id: 'q1', stem: 'What does the Swift optional binding do?'),
  bankQuestion(id: 'q2', number: 2, stem: 'Which Swift keyword declares a constant?'),
  bankQuestion(id: 'q3', number: 3, stem: 'What is 20% of 150?'),
  bankQuestion(id: 'q4', number: 4, stem: 'Swift question of another exam', exam: 'SSC_CGL'),
]);

void main() {
  testAppWidgets('the Study search also lists matching questions from the papers', (
    tester,
    db,
  ) async {
    final questions = paperQuestions;
    await pumpPrepLoopApp(
      tester,
      db,
      questions: questions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);

    await tester.enterText(find.byType(AppSearchField), 'swift');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Only the current exam's questions, searched on the server with the typed text.
    expect(questions.queries.last.text, 'swift');
    expect(questions.queries.last.examCode, 'SSC_CHSL');
    expect(find.textContaining('Questions from your SSC CHSL papers'), findsOneWidget);
    expect(find.textContaining('optional binding'), findsOneWidget);
    expect(find.textContaining('declares a constant'), findsOneWidget);
    expect(find.textContaining('another exam'), findsNothing);

    await tester.tap(find.textContaining('See all'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSearchField), findsWidgets);
    expect(questions.queries.last.text, 'swift');
  });

  testAppWidgets('a search with no matching question says so', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);

    await tester.enterText(find.byType(AppSearchField), 'kotlin');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No questions in your imported papers match "kotlin"'),
      findsOneWidget,
    );
  });

  testAppWidgets('a concept page lists questions about that concept', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await seedConcept(tester, db, 'Swift');
    await openStudy(tester);
    await tester.tap(find.text('Swift').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('optional binding'));
    expect(find.textContaining('optional binding'), findsOneWidget);
  });

  testAppWidgets('Google is offered when nothing matches and to learn more about matches', (
    tester,
    db,
  ) async {
    final opened = <Uri>[];
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
      extraOverrides: [
        linkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    await openStudy(tester);

    await tester.enterText(find.byType(AppSearchField), 'kotlin coroutines');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search on Google'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://www.google.com/search?q=kotlin+coroutines');

    await tester.enterText(find.byType(AppSearchField), 'swift');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn more on Google'));
    await tester.pumpAndSettle();
    expect(opened.last.queryParameters['q'], 'swift');

    // A question itself can be looked up too.
    await tester.tap(find.textContaining('optional binding'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Learn more on Google'));
    await tester.pumpAndSettle();
    expect(opened.last.queryParameters['q'], 'What does the Swift optional binding do?');
  });

  testAppWidgets('a link that cannot open says so', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
      extraOverrides: [linkOpenerProvider.overrideWithValue((uri) async => false)],
    );
    await openStudy(tester);
    await tester.enterText(find.byType(AppSearchField), 'kotlin');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search on Google'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the browser."), findsOneWidget);
  });

  test('the Google address collapses whitespace and caps the length', () {
    expect(googleSearchUri('  swift \n  optionals ').queryParameters['q'], 'swift optionals');
    final long = googleSearchUri('a' * 500).queryParameters['q']!;
    expect(long.length, webSearchMaxLength);
    expect(googleSearchUri('C++ & Swift?').host, 'www.google.com');
  });

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(AppSearchField), text);
    await tester.pump(const Duration(milliseconds: 400)); // paper search wait
    await tester.pump(const Duration(seconds: 1)); // AI settle wait
    await tester.pumpAndSettle();
  }

  testAppWidgets('no match: a quick AI answer (after asking once) comes before Google', (
    tester,
    db,
  ) async {
    final ai = FakeAiRepository(enabled: true);
    await pumpPrepLoopApp(
      tester,
      db,
      ai: ai,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);

    // Nothing is sent to the AI until the learner asks once.
    await search(tester, 'kotlin coroutines');
    expect(find.text('AI answer from your material'), findsOneWidget);
    expect(find.textContaining('matching parts of your material are sent'), findsOneWidget);
    expect(ai.calls, isEmpty); // nothing is sent before Ask AI
    await tester.tap(find.text('Ask AI'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Your material first (RAG); it doesn't cover this, so a general answer follows.
    expect(ai.calls, ['search:kotlin coroutines:SSC_CHSL', 'quick:kotlin coroutines:SSC_CHSL']);
    expect(find.textContaining("Your material doesn't cover this"), findsOneWidget);
    expect(find.text('AI-generated · not checked'), findsNothing); // no badge; the note says it
    expect(find.text(ai.quickAnswerText), findsOneWidget);
    expect(find.textContaining('Written by AI (fake-model)'), findsOneWidget);
    // The answer comes first, then Google for deeper reading.
    final answerY = tester.getTopLeft(find.text(ai.quickAnswerText)).dy;
    expect(tester.getTopLeft(find.text('Search on Google')).dy, greaterThan(answerY));

    // From now on it answers by itself (remembered on the device).
    await search(tester, 'kotlin flows');
    expect(ai.calls, contains('quick:kotlin flows:SSC_CHSL'));
    expect(
      await (db.select(
        db.appSettings,
      )..where((s) => s.key.equals('quick_answers_on'))).getSingle().then((r) => r.value),
      'true',
    );

    await tester.ensureVisible(find.text('Stop automatic AI answers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop automatic AI answers'));
    await tester.pumpAndSettle();
    expect(find.text('Ask AI'), findsOneWidget);
  });

  testAppWidgets(
    'quick answers: an unsure AI is flagged, errors can be retried, none with matches',
    (tester, db) async {
      final ai = FakeAiRepository(enabled: true)..confident = false;
      await pumpPrepLoopApp(
        tester,
        db,
        ai: ai,
        questions: paperQuestions,
        studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
      );
      await openStudy(tester);
      await search(tester, 'kotlin');
      await tester.tap(find.text('Ask AI'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      // An unsure AI is not shouted in red while the learner studies: the answer just shows.
      expect(find.text(ai.quickAnswerText), findsOneWidget);
      expect(find.textContaining("isn't sure"), findsNothing);

      ai.failure = const NetworkFailure();
      await search(tester, 'kotlin channels');
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(ai.quickAnswerText), findsOneWidget);

      // Matching paper questions: the answer is asked from the material too.
      await search(tester, 'swift');
      expect(ai.calls, contains('search:swift:SSC_CHSL'));
    },
  );

  testAppWidgets('without AI on the server only Google is offered', (tester, db) async {
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await search(tester, 'kotlin');
    expect(find.text('AI answer from your material'), findsNothing);
    expect(find.text('Search on Google'), findsOneWidget);
  });

  testAppWidgets('an answer from the material shows its sources, and a source opens', (
    tester,
    db,
  ) async {
    final ai = FakeAiRepository(enabled: true)
      ..searchAnswerResult = const SearchAnswer(
        found: true,
        answer: 'Optional binding unwraps a value safely [S1]. It uses if let [S2].',
        simple: 'It opens a box only if something is inside.',
        confident: true,
        model: 'fake-model',
        sources: [
          SearchAnswerSource(
            key: 'S1',
            kind: SearchSourceKind.question,
            label: 'Q.1 · chsl-2024.pdf',
            snippet: '...',
            verified: true,
            cited: true,
            questionId: 'q1',
          ),
          SearchAnswerSource(
            key: 'S2',
            kind: SearchSourceKind.page,
            label: 'swift-notes.pdf, page 7',
            snippet: '...',
            verified: false,
            cited: true,
            documentId: 'doc1',
            pageNumber: 7,
          ),
          SearchAnswerSource(
            key: 'S3',
            kind: SearchSourceKind.page,
            label: 'unused.pdf, page 1',
            snippet: '...',
            verified: false,
            cited: false,
            documentId: 'doc1',
            pageNumber: 1,
          ),
        ],
      );
    await pumpPrepLoopApp(
      tester,
      db,
      ai: ai,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await search(tester, 'swift optional');
    await tester.tap(find.text('Ask AI'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Two parts: what the papers say (cited), and the same in simple words (AI).
    expect(find.text('From your papers'), findsOneWidget);
    expect(find.text('In simple words (AI)'), findsOneWidget);
    expect(find.text('It opens a box only if something is inside.'), findsOneWidget);
    expect(find.textContaining('Written by AI'), findsOneWidget); // the quiet note at the bottom
    expect(find.textContaining('unwraps a value safely [S1]'), findsOneWidget);
    expect(find.text('Q.1 · chsl-2024.pdf'), findsOneWidget);
    expect(find.text('swift-notes.pdf, page 7'), findsOneWidget);
    expect(find.text('Not checked by a reviewer'), findsOneWidget); // the page, not the question
    expect(find.text('unused.pdf, page 1'), findsNothing); // only cited sources are listed
    expect(find.textContaining("doesn't cover this"), findsNothing);
    expect(ai.calls.where((c) => c.startsWith('quick:')), isEmpty); // no general answer needed

    await tester.ensureVisible(find.text('Q.1 · chsl-2024.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Q.1 · chsl-2024.pdf'));
    await tester.pumpAndSettle();
    expect(find.textContaining('optional binding do?'), findsWidgets); // the question opened
  });

  testAppWidgets('no own concept matches, but papers do: the message says where to look', (
    tester,
    db,
  ) async {
    await pumpPrepLoopApp(
      tester,
      db,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await search(tester, 'swift');
    expect(
      find.text(
        'None of your own concepts match "swift". Matches from your papers are shown above.',
      ),
      findsOneWidget,
    );
    await search(tester, 'kotlin'); // nothing anywhere: the plain message
    expect(find.textContaining('Matches from your papers are shown above'), findsNothing);
  });
}
