import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/sync_outbox.dart';
import '../../../core/utils/calendar_date.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../question_bank/domain/question.dart';
import '../domain/revision_card.dart';
import '../domain/revision_schedule.dart';

/// Flashcards and their schedule, stored on the device (offline-first; sync is Phase 10).
class RevisionRepository {
  RevisionRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  static const settingsKey = 'revision_day_offsets';

  CalendarDate get _today => CalendarDate.fromDateTime(_clock());

  // --- settings ---------------------------------------------------------------------

  Stream<RevisionSettings> watchSettings() =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(settingsKey)))
          .watchSingleOrNull()
          .map((row) => RevisionSettings.parse(row?.value));

  Future<RevisionSettings> loadSettings() async => RevisionSettings.parse(
    (await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(settingsKey))).getSingleOrNull())?.value,
  );

  /// Applies to future reviews; cards keep their current due dates.
  Future<void> saveSettings(RevisionSettings settings) async {
    if (!RevisionSettings.isValid(settings.dayOffsets)) {
      throw ArgumentError.value(settings.dayOffsets, 'dayOffsets', 'Not a valid ladder');
    }
    await _db.transaction(() async {
      await _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: settingsKey, value: settings.serialize()),
          );
      await _db.markDirty(SyncEntity.setting, SyncEntity.revisionOffsetsId);
    });
  }

  // --- reading ----------------------------------------------------------------------

  /// All cards, soonest due first. Cards of archived concepts are left out until the
  /// concept is restored.
  Stream<List<RevisionCard>> watchCards() {
    final query = _cardsQuery()
      ..orderBy([
        OrderingTerm.asc(_db.revisionCards.dueOn),
        OrderingTerm.asc(_db.revisionCards.id),
      ]);
    return query.watch().map((rows) => rows.map(_fromJoined).whereType<RevisionCard>().toList());
  }

  Stream<RevisionCard?> watchConceptCard(String conceptId) {
    final query = _cardsQuery()..where(_db.revisionCards.conceptId.equals(conceptId));
    return query.watchSingleOrNull().map((row) => row == null ? null : _fromJoined(row));
  }

  Future<RevisionCard?> getCard(String id) async {
    final row = await (_cardsQuery()..where(_db.revisionCards.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromJoined(row);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _cardsQuery() => _db.select(_db.revisionCards).join([
    leftOuterJoin(_db.concepts, _db.concepts.id.equalsExp(_db.revisionCards.conceptId)),
  ])..where(_db.concepts.archivedAt.isNull());

  RevisionCard? _fromJoined(TypedResult row) {
    final card = row.readTable(_db.revisionCards);
    final concept = row.readTableOrNull(_db.concepts);
    final isConcept = card.kind == CardKind.concept.name;
    if (isConcept && concept == null) return null;
    return RevisionCard(
      id: card.id,
      kind: isConcept ? CardKind.concept : CardKind.question,
      front: isConcept ? concept!.title : card.front ?? '',
      back: isConcept ? concept!.notes : card.back ?? '',
      schedule: CardSchedule(
        step: card.step,
        gapDays: card.gapDays,
        dueOn: CalendarDate.tryParse(card.dueOn) ?? _today,
        reviewCount: card.reviewCount,
        lapseCount: card.lapseCount,
      ),
      reason: CardReason.fromCode(card.reason),
      createdAt: card.createdAt,
      conceptId: card.conceptId,
      questionId: card.questionId,
      examCode: isConcept ? concept!.examCode : card.examCode,
      subject: isConcept ? concept!.subject : card.subject,
      topic: isConcept ? concept!.topic : card.topic,
      sourceFilename: card.sourceFilename,
      sourcePage: card.sourcePage,
      lastReviewedAt: card.lastReviewedAt,
    );
  }

  // --- adding and removing ------------------------------------------------------------

  /// Puts a concept on the schedule (Day 1 = tomorrow). Idempotent.
  Future<void> addConcept(String conceptId) async {
    final settings = await loadSettings();
    final schedule = RevisionScheduler.initial(_today, settings);
    final now = _clock().toUtc();
    final id = _uuid.v4();
    await _db.transaction(() async {
      final inserted = await _db
          .into(_db.revisionCards)
          .insert(
            RevisionCardsCompanion.insert(
              id: id,
              kind: CardKind.concept.name,
              conceptId: Value(conceptId),
              step: schedule.step,
              gapDays: schedule.gapDays,
              dueOn: schedule.dueOn.toIsoString(),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      // insertOrIgnore returns 0 when the concept already had a card.
      if (inserted > 0) await _db.markDirty(SyncEntity.revisionCard, id);
    });
  }

  /// Turns questions into cards. Only verified questions from imported papers that
  /// have an answer and need no figure are eligible; the rest are counted, not added.
  Future<AddQuestionsResult> addQuestions(
    List<BankQuestion> questions, {
    CardReason reason = CardReason.added,
  }) async {
    final eligible = questions.where(isEligibleQuestion).toList();
    final existing =
        await (_db.selectOnly(_db.revisionCards)
              ..addColumns([_db.revisionCards.questionId])
              ..where(_db.revisionCards.questionId.isIn(eligible.map((q) => q.id))))
            .map((r) => r.read(_db.revisionCards.questionId))
            .get();
    final fresh = {
      for (final q in eligible)
        if (!existing.contains(q.id)) q.id: q,
    }.values.toList();

    final settings = await loadSettings();
    final schedule = RevisionScheduler.initial(_today, settings);
    final now = _clock().toUtc();
    final ids = {for (final q in fresh) q.id: _uuid.v4()};
    await _db.transaction(() async {
      await _db.batch((batch) {
        for (final q in fresh) {
          batch.insert(
            _db.revisionCards,
            RevisionCardsCompanion.insert(
              id: ids[q.id]!,
              kind: CardKind.question.name,
              questionId: Value(q.id),
              front: Value(questionFront(q)),
              back: Value(questionBack(q)),
              sourceFilename: Value(q.documentFilename),
              sourcePage: Value(q.sourcePages.firstOrNull),
              examCode: Value(q.examCode),
              subject: Value(q.subject ?? q.section),
              topic: Value(q.topic?.name),
              reason: Value(reason.code),
              step: schedule.step,
              gapDays: schedule.gapDays,
              dueOn: schedule.dueOn.toIsoString(),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
      for (final id in ids.values) {
        await _db.markDirty(SyncEntity.revisionCard, id);
      }
    });
    return AddQuestionsResult(
      added: fresh.length,
      alreadyAdded: eligible.length - fresh.length,
      notEligible: questions.length - eligible.length,
    );
  }

  static bool isEligibleQuestion(BankQuestion q) =>
      q.origin == QuestionOrigin.source &&
      q.status == VerificationStatus.verified &&
      !q.imageDependent &&
      (q.isWritten
          ? (q.modelAnswer?.trim().isNotEmpty ?? false)
          : q.correctPosition != null && q.options.any((o) => o.position == q.correctPosition));

  /// The back of a question card: the written answer, or the right option (and explanation).
  static String questionBack(BankQuestion q) {
    final explanation = q.explanation?.trim() ?? '';
    final answer = q.isWritten
        ? q.modelAnswer!.trim()
        : () {
            final option = q.options.firstWhere((o) => o.position == q.correctPosition);
            return '(${option.label}) ${option.text}';
          }();
    return explanation.isEmpty ? answer : '$answer\n\n$explanation';
  }

  static String questionFront(BankQuestion q) {
    final buffer = StringBuffer();
    final passage = q.passage?.text.trim();
    if (passage != null && passage.isNotEmpty) buffer.write('$passage\n\n');
    buffer.write(q.stem.trim());
    for (final option in q.options) {
      buffer.write('\n(${option.label}) ${option.text}');
    }
    return buffer.toString();
  }

  Future<void> removeCard(String id) => _db.transaction(() async {
    final deleted = await (_db.delete(_db.revisionCards)..where((c) => c.id.equals(id))).go();
    if (deleted > 0) await _db.markDirty(SyncEntity.revisionCard, id);
  });

  // --- reviewing --------------------------------------------------------------------

  /// Records a recall rating and reschedules the card. Returns the new schedule.
  Future<CardSchedule> review(String cardId, RecallRating rating) async {
    final settings = await loadSettings();
    final today = _today;
    final reviewId = _uuid.v4();
    final now = _clock().toUtc();
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.revisionCards,
      )..where((c) => c.id.equals(cardId))).getSingle();
      final current = CardSchedule(
        step: row.step,
        gapDays: row.gapDays,
        dueOn: CalendarDate.tryParse(row.dueOn) ?? today,
        reviewCount: row.reviewCount,
        lapseCount: row.lapseCount,
      );
      final next = RevisionScheduler.review(current, rating, today, settings);
      await (_db.update(_db.revisionCards)..where((c) => c.id.equals(cardId))).write(
        RevisionCardsCompanion(
          step: Value(next.step),
          gapDays: Value(next.gapDays),
          dueOn: Value(next.dueOn.toIsoString()),
          reviewCount: Value(next.reviewCount),
          lapseCount: Value(next.lapseCount),
          lastReviewedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db
          .into(_db.cardReviews)
          .insert(
            CardReviewsCompanion.insert(
              cardId: cardId,
              syncId: Value(reviewId),
              reviewedAt: now,
              rating: rating.name,
              dueBefore: current.dueOn.toIsoString(),
              dueAfter: next.dueOn.toIsoString(),
              gapDays: next.gapDays,
            ),
          );
      await _db.markDirty(SyncEntity.revisionCard, cardId);
      await _db.markDirty(SyncEntity.cardReview, reviewId);
      return next;
    });
  }

  /// Flashcard review activity since local midnight of [since], per topic and per local
  /// day (for progress analytics). Re-emits when reviews are added.
  Stream<RevisionStats> watchStats({required CalendarDate since}) {
    final reviews = _db.cardReviews;
    final cards = _db.revisionCards;
    final concepts = _db.concepts;
    final query = _db.select(reviews).join([
      innerJoin(cards, cards.id.equalsExp(reviews.cardId)),
      leftOuterJoin(concepts, concepts.id.equalsExp(cards.conceptId)),
    ])..where(reviews.reviewedAt.isBiggerOrEqualValue(since.toLocalDateTime().toUtc()));
    return query.watch().map((rows) {
      var total = 0;
      var forgot = 0;
      final daily = <CalendarDate, int>{};
      final byTopic = <String, ({String subject, String topic, int reviews, int forgot})>{};
      for (final row in rows) {
        final review = row.readTable(reviews);
        final card = row.readTable(cards);
        final concept = row.readTableOrNull(concepts);
        final lapse = review.rating == RecallRating.again.name;
        total++;
        if (lapse) forgot++;
        daily.update(CalendarDate.fromDateTime(review.reviewedAt), (n) => n + 1, ifAbsent: () => 1);
        final subject = concept?.subject ?? card.subject;
        final topic = concept?.topic ?? card.topic;
        if (subject == null || topic == null) continue;
        final key = '${subject.toLowerCase()}${topic.toLowerCase()}';
        final current = byTopic[key];
        byTopic[key] = (
          subject: current?.subject ?? subject,
          topic: current?.topic ?? topic,
          reviews: (current?.reviews ?? 0) + 1,
          forgot: (current?.forgot ?? 0) + (lapse ? 1 : 0),
        );
      }
      return RevisionStats(
        reviews: total,
        forgot: forgot,
        daily: daily,
        byTopic: [
          for (final t in byTopic.values)
            TopicRecall(subject: t.subject, topic: t.topic, reviews: t.reviews, forgot: t.forgot),
        ],
      );
    });
  }

  /// Review log rows for a card, oldest first (for tests and Phase 8 analytics).
  Future<List<CardReviewRow>> reviewsOf(String cardId) =>
      (_db.select(_db.cardReviews)
            ..where((r) => r.cardId.equals(cardId))
            ..orderBy([(r) => OrderingTerm.asc(r.id)]))
          .get();
}
