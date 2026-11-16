import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/current_affairs/data/current_affairs_repository.dart';
import 'package:preploop/features/current_affairs/domain/current_affairs.dart';

import '../../helpers/pump_app.dart';

const games = CurrentAffairsCard(
  front: 'Where were the National Games 2026 held?',
  back: 'Dehradun',
  sourceLabel: 'Pasted text',
  quote: 'The National Games 2026 were held in Dehradun',
);

class FakeCurrentAffairsRepository implements CurrentAffairsRepository {
  final calls = <String>[];

  @override
  Future<CurrentAffairsDraft> fromText({
    required String examCode,
    required String text,
    required ContentLanguage language,
  }) async {
    calls.add('text:$examCode');
    return const CurrentAffairsDraft(
      cards: [
        games,
        CurrentAffairsCard(
          front: 'Who topped the medal table?',
          back: 'Services',
          sourceLabel: 'Pasted text',
          quote: 'topped the medal table with 68 gold medals',
        ),
      ],
      dropped: 1,
    );
  }

  @override
  Future<CurrentAffairsDraft> fromPdf({
    required String examCode,
    required String name,
    required List<int> bytes,
    required ContentLanguage language,
  }) async {
    calls.add('pdf:$examCode:$name');
    return const CurrentAffairsDraft(cards: [], noText: true);
  }
}

Future<FakeCurrentAffairsRepository> open(WidgetTester tester, AppDatabase db) async {
  final repo = FakeCurrentAffairsRepository();
  await pumpPrepLoopApp(
    tester,
    db,
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    extraOverrides: [
      currentAffairsRepositoryProvider.overrideWithValue(repo),
      currentAffairsPdfPickerProvider.overrideWithValue(
        () async => (name: 'news.pdf', bytes: [1, 2, 3]),
      ),
    ],
  );
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/study/current-affairs'),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  test('an approved card becomes an AI-labelled concept tagged with its month', () {
    final draft = currentAffairsConcept(
      games,
      examCode: 'SSC_CHSL',
      language: ContentLanguage.english,
      today: CalendarDate(2026, 11, 16),
      sourceLine: 'From Pasted text: "..."',
    );
    expect(draft.tags, ['current-affairs', 'current-affairs-2026-11', aiGeneratedTag]);
    expect((draft.subject, draft.topic), ('Current affairs', '2026-11'));
    expect(draft.sourceReference, 'Pasted text: "The National Games 2026 were held in Dehradun"');
    expect(draft.notes, startsWith('Dehradun'));
  });

  testAppWidgets('drafts are approved one by one and only approved ones are saved', (
    tester,
    db,
  ) async {
    final repo = await open(tester, db);
    expect(find.textContaining("doesn't fetch web pages"), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'The National Games 2026 were held in Dehradun.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft cards'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(repo.calls, ['text:SSC_CHSL']);
    expect(find.textContaining('AI-generated from your material'), findsOneWidget);
    expect(find.textContaining('1 draft was left out'), findsOneWidget);
    await scrollTo(tester, find.text('Approve').first);
    await tester.tap(find.text('Approve').first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Saved to your concepts'), findsOneWidget);
    final concepts = await tester.runAsync(() => db.select(db.concepts).get());
    expect(concepts!.map((c) => c.title), ['Where were the National Games 2026 held?']);
    final cards = await tester.runAsync(() => db.select(db.revisionCards).get());
    expect(cards!.single.conceptId, concepts.single.id);
  });

  testAppWidgets('a PDF that gives no text says so', (tester, db) async {
    final repo = await open(tester, db);
    await tester.tap(find.text('A PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a PDF'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(repo.calls, ['pdf:SSC_CHSL:news.pdf']);
    expect(find.textContaining('No text could be read'), findsOneWidget);
  });
}
