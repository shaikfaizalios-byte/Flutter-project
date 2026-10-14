import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/database/sync_outbox.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/revision/data/revision_repository.dart';
import 'package:preploop/features/revision/domain/revision_schedule.dart';
import 'package:preploop/features/study_plan/data/study_profile_repository.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';
import 'package:preploop/features/sync/data/sync_engine.dart';

import '../../helpers/pump_app.dart';

/// One simulated device: its own database, repositories and sync engine.
class Device {
  Device(this.server) : db = createTestDatabase() {
    concepts = LocalConceptsRepository(db, clock: () => now);
    revision = RevisionRepository(db, clock: () => now);
    profile = StudyProfileRepository(db, clock: () => now);
    engine = SyncEngine(db, server);
  }

  final FakeSyncServer server;
  final AppDatabase db;
  DateTime now = DateTime(2026, 10, 14, 9);
  late final LocalConceptsRepository concepts;
  late final RevisionRepository revision;
  late final StudyProfileRepository profile;
  late final SyncEngine engine;

  Future<int> pending() async => (await db.select(db.syncOutbox).get()).length;

  Future<List<String>> titles() async =>
      [for (final c in await db.select(db.concepts).get()) c.title]..sort();
}

ConceptDraft draft(String title) => ConceptDraft(
  examCode: 'SSC_CGL',
  title: title,
  notes: 'notes',
  subject: 'Quantitative Aptitude',
  topic: 'Percentage',
  language: ContentLanguage.english,
);

void main() {
  late FakeSyncServer server;
  late Device phone;
  late Device tablet;

  setUp(() {
    server = FakeSyncServer();
    phone = Device(server);
    tablet = Device(server);
  });

  test('local changes are uploaded and the outbox is cleared', () async {
    final concept = await phone.concepts.create(draft('Percent change'));
    await phone.profile.save(
      StudyProfile(
        examCodes: const ['SSC_CGL'],
        targetExamDate: CalendarDate(2027, 6, 1),
        dailyStudyMinutes: 60,
      ),
    );
    await phone.revision.addConcept(concept.id);
    await phone.revision.saveSettings(const RevisionSettings(dayOffsets: [2, 5]));
    final card = (await phone.db.select(phone.db.revisionCards).getSingle()).id;
    await phone.revision.review(card, RecallRating.good);
    expect(await phone.pending(), 5); // concept, profile, card (coalesced), review, setting

    final report = await phone.engine.run();

    expect(report.pushed, 5);
    expect(await phone.pending(), 0);
    expect(server.data('concept', concept.id)!['title'], 'Percent change');
    expect(server.data('study_profile', 'profile')!['target_exam_date'], '2027-06-01');
    expect(server.data('setting', 'revision_day_offsets'), {'value': '2,5'});
    expect(server.data('revision_card', card)!['review_count'], 1);
    final reviewId = (await phone.db.select(phone.db.cardReviews).getSingle()).syncId!;
    expect(server.data('card_review', reviewId)!['rating'], 'good');
  });

  test('another device receives everything, children after parents across pages', () async {
    server.pageSize = 2;
    final concept = await phone.concepts.create(draft('Ratio'));
    await phone.revision.addConcept(concept.id);
    final card = (await phone.db.select(phone.db.revisionCards).getSingle()).id;
    await phone.revision.review(card, RecallRating.good);
    await phone.engine.run();
    // Editing the concept later gives it a newer server number than its card.
    await phone.concepts.update(concept.id, draft('Ratio and proportion'));
    await phone.engine.run();

    final report = await tablet.engine.run();

    expect(report.pulled, 3);
    expect(await tablet.titles(), ['Ratio and proportion']);
    final tabletCard = await tablet.db.select(tablet.db.revisionCards).getSingle();
    expect((tabletCard.id, tabletCard.conceptId, tabletCard.reviewCount), (card, concept.id, 1));
    expect(await tablet.db.select(tablet.db.cardReviews).get(), hasLength(1));
    expect(await tablet.pending(), 0); // applying pulled data never marks it dirty
  });

  test('last writer wins and both devices converge', () async {
    final concept = await phone.concepts.create(draft('Original'));
    await phone.engine.run();
    await tablet.engine.run();

    await phone.concepts.update(concept.id, draft('Phone edit'));
    await tablet.concepts.update(concept.id, draft('Tablet edit'));
    await phone.engine.run();
    await tablet.engine.run(); // pushes after the phone → wins
    await phone.engine.run();

    expect(await phone.titles(), ['Tablet edit']);
    expect(await tablet.titles(), ['Tablet edit']);
  });

  test('a pending local change is not overwritten by pulled data', () async {
    final concept = await phone.concepts.create(draft('Original'));
    await phone.engine.run();
    await tablet.engine.run();
    await tablet.concepts.update(concept.id, draft('Tablet edit'));
    await tablet.engine.run();

    server.offline = true;
    await phone.concepts.update(concept.id, draft('Phone edit (offline)'));
    await expectLater(phone.engine.run(), throwsA(isA<NetworkFailure>()));
    expect(await phone.pending(), 1); // kept for later
    server.offline = false;
    await phone.engine.run();

    expect(await phone.titles(), ['Phone edit (offline)']);
    expect(server.data('concept', concept.id)!['title'], 'Phone edit (offline)');
  });

  test('deletes win over edits made elsewhere, including cascaded cards', () async {
    final concept = await phone.concepts.create(draft('To delete'));
    await phone.revision.addConcept(concept.id);
    await phone.engine.run();
    await tablet.engine.run();

    await phone.concepts.delete(concept.id); // also deletes (and syncs) its card
    await phone.engine.run();
    await tablet.concepts.update(concept.id, draft('Edited offline'));
    await tablet.engine.run();

    expect(server.isDeleted('concept', concept.id), isTrue);
    expect(server.keys.where((k) => k.startsWith('revision_card')).length, 1);
    expect(await tablet.titles(), isEmpty);
    expect(await tablet.db.select(tablet.db.revisionCards).get(), isEmpty);
    expect(await tablet.pending(), 0);
  });

  test('an edit made during an upload is kept for the next sync', () async {
    final concept = await phone.concepts.create(draft('First'));
    server.duringPush = () async {
      server.duringPush = null;
      await phone.concepts.update(concept.id, draft('Changed while uploading'));
    };

    await phone.engine.run();

    expect(await phone.pending(), 1);
    await phone.engine.run();
    expect(server.data('concept', concept.id)!['title'], 'Changed while uploading');
  });

  test('changes the server rejects are dropped, not retried forever', () async {
    final concept = await phone.concepts.create(draft('Rejected'));
    server.reject.add('concept:${concept.id}');

    final report = await phone.engine.run();

    expect((report.pushed, report.dropped), (0, 1));
    expect(await phone.pending(), 0);
  });

  test('first sync of existing local data uploads all of it', () async {
    // Data created before sync existed has no outbox entries.
    await phone.concepts.create(draft('Old note'));
    await phone.db.delete(phone.db.syncOutbox).go();

    await phone.engine.markAllDirty();
    await phone.engine.run();
    await tablet.engine.run();

    expect(await tablet.titles(), ['Old note']);
  });

  test('erasing local user data keeps device preferences', () async {
    await phone.concepts.create(draft('Mine'));
    await phone.db
        .into(phone.db.appSettings)
        .insert(AppSettingsCompanion.insert(key: 'language', value: 'hindi'));
    await phone.engine.run();

    await phone.engine.eraseLocalUserData();

    expect(await phone.titles(), isEmpty);
    expect(await phone.pending(), 0);
    final settings = await phone.db.select(phone.db.appSettings).get();
    expect(settings.map((s) => s.key), ['language']);
  });

  test('marking a record twice coalesces into one outbox entry', () async {
    await phone.db.markDirty(SyncEntity.concept, 'c1');
    await phone.db.markDirty(SyncEntity.concept, 'c1');
    final rows = await phone.db.select(phone.db.syncOutbox).get();
    expect(rows.single.version, 2);
  });
}
