import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/question_bank/domain/question.dart';
import 'package:preploop/features/revision/data/revision_repository.dart';
import 'package:preploop/features/revision/domain/revision_card.dart';
import 'package:preploop/features/revision/domain/revision_schedule.dart';

import '../../helpers/pump_app.dart';

void main() {
  late AppDatabase db;
  late RevisionRepository repo;
  late LocalConceptsRepository concepts;
  var now = DateTime(2026, 10, 12, 21, 30); // local evening

  setUp(() {
    db = createTestDatabase();
    now = DateTime(2026, 10, 12, 21, 30);
    repo = RevisionRepository(db, clock: () => now);
    concepts = LocalConceptsRepository(db, clock: () => now);
  });

  Future<Concept> concept(String title) => concepts.create(
    ConceptDraft(
      examCode: 'SSC_CGL',
      title: title,
      notes: 'notes for $title',
      subject: 'Quantitative Aptitude',
      topic: 'Percentage',
      language: ContentLanguage.english,
    ),
  );

  test('a concept card shows the live concept and is due tomorrow (Day 1)', () async {
    final c = await concept('Percent change');
    await repo.addConcept(c.id);
    await repo.addConcept(c.id); // idempotent

    final cards = await repo.watchCards().first;
    expect(cards, hasLength(1));
    expect(cards.single.kind, CardKind.concept);
    expect(cards.single.front, 'Percent change');
    expect(cards.single.back, 'notes for Percent change');
    expect(cards.single.dueOn, CalendarDate(2026, 10, 13));

    await concepts.update(
      c.id,
      const ConceptDraft(
        examCode: 'SSC_CGL',
        title: 'Percentage change',
        notes: 'new',
        subject: 'Quantitative Aptitude',
        topic: 'Percentage',
        language: ContentLanguage.english,
      ),
    );
    expect((await repo.watchCards().first).single.front, 'Percentage change');
  });

  test('archived concepts drop out; deleted concepts remove their card', () async {
    final c = await concept('Ratio');
    await repo.addConcept(c.id);

    await concepts.setArchived(c.id, archived: true);
    expect(await repo.watchCards().first, isEmpty);
    await concepts.setArchived(c.id, archived: false);
    expect(await repo.watchCards().first, hasLength(1));

    await concepts.delete(c.id);
    expect(await db.select(db.revisionCards).get(), isEmpty);
  });

  test('only verified source questions with an answer become cards', () async {
    final result = await repo.addQuestions([
      bankQuestion(id: 'ok', status: VerificationStatus.verified),
      bankQuestion(id: 'unreviewed'),
      bankQuestion(id: 'ai', status: VerificationStatus.verified, origin: QuestionOrigin.ai),
      bankQuestion(id: 'figure', status: VerificationStatus.verified, issues: ['image_dependent']),
      bankQuestion(id: 'no-answer', status: VerificationStatus.verified, answer: null),
    ], reason: CardReason.incorrectAnswer);

    expect((result.added, result.alreadyAdded, result.notEligible), (1, 0, 4));
    final card = (await repo.watchCards().first).single;
    expect(card.kind, CardKind.question);
    expect(card.front, 'What is 20% of 150?\n(1) 20\n(2) 30\n(3) 40\n(4) 50');
    expect(card.back, '(2) 30');
    expect((card.sourceFilename, card.sourcePage), ('chsl-2024.pdf', 1));
    expect(card.reason, CardReason.incorrectAnswer);

    final again = await repo.addQuestions([
      bankQuestion(id: 'ok', status: VerificationStatus.verified),
    ]);
    expect((again.added, again.alreadyAdded), (0, 1));
  });

  test('reviewing reschedules the card and logs the rating', () async {
    final c = await concept('Profit and loss');
    await repo.addConcept(c.id);
    final id = (await repo.watchCards().first).single.id;

    now = DateTime(2026, 10, 13, 8); // Day 1
    final next = await repo.review(id, RecallRating.good);
    expect(next.dueOn, CalendarDate(2026, 10, 16)); // Day 4

    now = DateTime(2026, 10, 16, 8);
    await repo.review(id, RecallRating.again);
    final card = (await repo.watchCards().first).single;
    expect(card.dueOn, CalendarDate(2026, 10, 17));
    expect((card.schedule.reviewCount, card.schedule.lapseCount), (2, 1));

    final log = await repo.reviewsOf(id);
    expect(log.map((r) => r.rating), ['good', 'again']);
    expect(log.map((r) => r.dueAfter), ['2026-10-16', '2026-10-17']);
  });

  test('the ladder is a stored setting used for new cards', () async {
    expect((await repo.loadSettings()).dayOffsets, [1, 4, 7]);
    await repo.saveSettings(const RevisionSettings(dayOffsets: [2, 5, 9]));
    expect((await repo.loadSettings()).dayOffsets, [2, 5, 9]);
    expect(
      () => repo.saveSettings(const RevisionSettings(dayOffsets: [5, 2])),
      throwsArgumentError,
    );

    final c = await concept('Average');
    await repo.addConcept(c.id);
    expect((await repo.watchCards().first).single.dueOn, CalendarDate(2026, 10, 14));
  });

  test('overview counts due, overdue and upcoming cards', () {
    final today = CalendarDate(2026, 10, 12);
    RevisionCard card(String id, CalendarDate due) => RevisionCard(
      id: id,
      kind: CardKind.concept,
      front: id,
      back: '',
      schedule: CardSchedule(step: 0, gapDays: 1, dueOn: due),
      reason: CardReason.added,
      createdAt: DateTime.utc(2026),
    );
    final overview = RevisionOverview.of([
      card('a', today.addDays(-2)),
      card('b', today),
      card('c', today.addDays(1)),
      card('d', today.addDays(1)),
      card('e', today.addDays(7)),
      card('f', today.addDays(30)),
    ], today);

    expect((overview.dueToday, overview.overdue, overview.total), (2, 1, 6));
    expect(overview.upcoming, [2, 0, 0, 0, 0, 0, 1]);
    expect(overview.nextDue, today.addDays(1));
  });

  test('review statistics per topic and local day, within the window', () async {
    final c = await concept('Percent change'); // Quantitative Aptitude › Percentage
    await repo.addConcept(c.id);
    await repo.addQuestions([
      bankQuestion(
        status: VerificationStatus.verified,
        section: 'English Language',
        topic: const TopicRef(id: 't', subject: 'English Language', name: 'Synonyms'),
      ),
    ]);
    final cards = await repo.watchCards().first;
    final conceptCard = cards.firstWhere((x) => x.kind == CardKind.concept).id;
    final questionCard = cards.firstWhere((x) => x.kind == CardKind.question).id;

    now = DateTime(2026, 9, 1, 9); // outside a window starting 13 Sep
    await repo.review(conceptCard, RecallRating.again);
    now = DateTime(2026, 10, 11, 23, 50);
    await repo.review(conceptCard, RecallRating.again);
    now = DateTime(2026, 10, 12, 0, 10);
    await repo.review(conceptCard, RecallRating.good);
    await repo.review(questionCard, RecallRating.hard);

    final stats = await repo.watchStats(since: CalendarDate(2026, 9, 13)).first;
    expect((stats.reviews, stats.forgot), (3, 1));
    expect(stats.daily, {CalendarDate(2026, 10, 11): 1, CalendarDate(2026, 10, 12): 2});
    final byTopic = {for (final r in stats.byTopic) r.topic: r};
    expect((byTopic['Percentage']!.reviews, byTopic['Percentage']!.forgot), (2, 1));
    expect(byTopic['Percentage']!.subject, 'Quantitative Aptitude');
    expect((byTopic['Synonyms']!.reviews, byTopic['Synonyms']!.forgot), (1, 0));
  });
}
