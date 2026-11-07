import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/localization/generated/app_localizations.dart';
import 'package:preploop/features/exams/application/active_exam.dart';
import 'package:preploop/features/library/application/library_providers.dart';
import 'package:preploop/features/library/data/library_repository.dart';
import 'package:preploop/features/library/domain/library_models.dart';
import 'package:preploop/features/library/presentation/library_screen.dart';
import 'package:preploop/features/practice/data/practice_repository.dart';
import 'package:preploop/features/practice/domain/offline_practice.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';
import 'package:preploop/features/question_bank/application/question_bank_providers.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/question_bank/presentation/question_widgets.dart';

import '../../helpers/pump_app.dart';
import '../practice/practice_offline_test.dart' show packQuestion;

const pack = LibraryPack(
  key: 'maths-arithmetic',
  name: 'Arithmetic',
  subject: 'Maths',
  questions: 2,
  seq: 7,
);

Map<String, dynamic> libraryQuestion(String id, {String? stem}) => {
  ...packQuestion(id),
  'stem': ?stem,
  'shared': true,
  'document_filename': null,
  'library_source': 'original_ai_verified',
  'figures': <Object>[],
};

/// Answers each request with the next scripted delta, and records what was asked.
class PackServer implements HttpClientAdapter {
  PackServer(this.replies);

  final List<Map<String, dynamic>> replies;
  final asked = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options.queryParameters);
    final body = options.path.endsWith('/offline-pack')
        ? {
            'questions': [packQuestion('daily')],
            'limit': 500,
            'generated_at': '2026-11-07T09:00:00Z',
          }
        : replies.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeLibrary implements LibraryRepository {
  final queries = <LibraryQuery>[];
  final saved = <String, int>{};

  @override
  Future<LibraryPage> search(LibraryQuery query) async {
    queries.add(query);
    return const LibraryPage(
      total: 1,
      items: [
        LibraryHit(
          questionId: 'q',
          stem: 'What is 2 + 2?',
          format: 'single_correct',
          source: 'original_expert',
          difficulty: 'hard',
          pictured: false,
          year: 2024,
          topic: 'Sums',
          percentRight: 64,
        ),
      ],
    );
  }

  @override
  Future<List<LibraryPack>> packs(String exam) async => const [pack];

  @override
  Future<Map<String, int>> savedPacks(String exam) async => saved;

  @override
  Future<void> savePack(String exam, LibraryPack pack) async => saved[pack.key] = pack.seq;

  @override
  Future<Uint8List?> savedFigure(String figureId) async => null;
}

void main() {
  late AppDatabase db;
  late PackServer server;
  late Dio dio;
  late LibraryRepository repo;

  void serve(List<Map<String, dynamic>> replies) {
    server = PackServer(replies);
    dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'))..httpClientAdapter = server;
    repo = LibraryRepository(dio, db, clock: () => DateTime.utc(2026, 11, 7));
  }

  Future<List<String>> savedIds() async => [
    for (final row in await db.select(db.offlineQuestions).get()) row.id,
  ];

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('a saved chapter asks only for what changed since', () async {
    serve([
      {
        'seq': 5,
        'questions': [libraryQuestion('a'), libraryQuestion('b')],
        'figures': [
          {
            'id': 'f1',
            'question_id': 'b',
            'data': base64Encode([1, 2]),
          },
        ],
        'removed': <String>[],
      },
      {
        'seq': 7,
        'questions': [libraryQuestion('a', stem: 'Reworded?')],
        'figures': <Object>[],
        'removed': ['b'],
      },
    ]);

    await repo.savePack('SSC_CHSL', pack);
    expect(server.asked.last['since'], 0);
    expect(await repo.savedPacks('SSC_CHSL'), {'maths-arithmetic': 5});
    expect(await repo.savedFigure('f1'), [1, 2]);

    await repo.savePack('SSC_CHSL', pack);
    expect(server.asked.last['since'], 5);
    expect(await savedIds(), ['a']);
    expect(await repo.savedFigure('f1'), isNull);
    final row = await db.select(db.offlineQuestions).getSingle();
    expect((jsonDecode(row.data) as Map<String, dynamic>)['stem'], 'Reworded?');
    expect(await repo.savedPacks('SSC_CHSL'), {'maths-arithmetic': 7});
  });

  test('refreshing the daily pack leaves saved chapters alone', () async {
    serve([
      {
        'seq': 5,
        'questions': [libraryQuestion('a')],
        'figures': <Object>[],
        'removed': <String>[],
      },
    ]);
    await repo.savePack('SSC_CHSL', pack);

    await PracticeRepository(dio, db).refreshOfflinePack();

    expect(await savedIds(), unorderedEquals(['a', 'daily']));
  });

  test('a saved question keeps its label offline', () {
    final view = OfflineSession(
      id: 's',
      examCode: 'SSC_CHSL',
      startedAt: DateTime.utc(2026, 11, 7),
      questions: [OfflineQuestion(libraryQuestion('a'))],
    ).toView(DateTime.utc(2026, 11, 7));
    expect(view.items.single.origin, QuestionOrigin.library);
    expect(view.items.single.librarySource, 'original_ai_verified');
  });

  test('a chapter needs fetching only when something changed', () {
    expect(packState(pack, null), PackState.notSaved);
    expect(packState(pack, 6), PackState.outdated);
    expect(packState(pack, 7), PackState.saved);
  });

  test('the library origin is read from the server', () {
    expect(QuestionOrigin.fromCode('library'), QuestionOrigin.library);
    expect(QuestionOrigin.fromCode('source'), QuestionOrigin.source);
  });

  test('percent right is shown only when the server sends it', () {
    expect(AnswerFeedback.fromJson(const {'percent_right': 64}).percentRight, 64);
    expect(AnswerFeedback.fromJson(const {}).percentRight, isNull);
  });

  testWidgets('labels never pass an AI question off as a paper question', (tester) async {
    Future<void> show(Widget chip) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: chip),
      ),
    );
    await show(
      const OriginChip(origin: QuestionOrigin.library, librarySource: 'original_ai_verified'),
    );
    expect(find.text('AI-written, checked by reviewers'), findsOneWidget);
    await show(const OriginChip(origin: QuestionOrigin.source, librarySource: 'official_pyq'));
    expect(find.text('Previous year paper'), findsOneWidget);
    await show(const OriginChip(origin: QuestionOrigin.library));
    expect(find.text('From your PDF'), findsNothing);
  });

  testWidgets('the library shows labelled results and saves a chapter', (tester) async {
    final library = FakeLibrary();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(library),
          activeExamProvider.overrideWithValue('SSC_CHSL'),
          topicsProvider.overrideWith((ref, exam) async => const <TopicRef>[]),
          patternsProvider.overrideWith((ref) async => const <PatternRef>[]),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('What is 2 + 2?', findRichText: true), findsOneWidget);
    expect(find.text('Written for PrepLoop'), findsOneWidget);
    expect(find.text('64% got this right'), findsOneWidget);
    expect(find.text('Sums · 2024 · Hard'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(library.saved, {'maths-arithmetic': 7});
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.text('Difficulty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hard').last);
    await tester.pumpAndSettle();
    expect(library.queries.last.difficulty, 'hard');
  });
}
