// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // v1 -> v2 only adds a table; existing concepts and settings must be untouched.
  test('migration from v1 to v2 keeps concepts and settings', () async {
    const concept = v1.ConceptsData(
      id: '0b6c1d3e-5f1a-4c7e-9a43-2a1f0e9d7b11',
      examCode: 'SSC_CGL',
      title: 'प्रतिशत',
      notes: 'x% of y = y% of x',
      subject: 'Quantitative Aptitude',
      topic: 'Percentage',
      language: 'hi',
      tags: '["formula"]',
      createdAt: '2026-10-01T09:00:00.000Z',
      updatedAt: '2026-10-02T09:00:00.000Z',
    );
    const setting = v1.AppSettingsData(key: 'language', value: 'hindi');

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.concepts, concept);
        batch.insert(oldDb.appSettings, setting);
      },
      validateItems: (newDb) async {
        final concepts = await newDb.select(newDb.concepts).get();
        expect(concepts.single.toJson(), concept.toJson());
        final settings = await newDb.select(newDb.appSettings).get();
        expect(settings.single.toJson(), setting.toJson());
        expect(await newDb.select(newDb.studyProfiles).get(), isEmpty);
      },
    );
  });

  // v3 -> v4 only adds the flashcard tables; queued answers and concepts must survive.
  test('migration from v3 to v4 keeps concepts and queued answers', () async {
    const concept = v3.ConceptsData(
      id: '0b6c1d3e-5f1a-4c7e-9a43-2a1f0e9d7b11',
      examCode: 'SSC_CHSL',
      title: 'Synonyms',
      notes: 'abundant = plentiful',
      subject: 'English Language',
      topic: 'Vocabulary',
      language: 'en',
      tags: '[]',
      createdAt: '2026-10-01T09:00:00.000Z',
      updatedAt: '2026-10-02T09:00:00.000Z',
    );
    const pending = v3.PendingAnswersData(
      sessionId: 's1',
      position: 3,
      selectedPosition: 2,
      clientSeq: 1760000000000000,
      createdAt: '2026-10-02T09:00:00.000Z',
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.concepts, concept);
        batch.insert(oldDb.pendingAnswers, pending);
      },
      validateItems: (newDb) async {
        expect(
          (await newDb.select(newDb.concepts).get()).single.toJson(),
          concept.toJson(),
        );
        expect(
          (await newDb.select(newDb.pendingAnswers).get()).single.toJson(),
          pending.toJson(),
        );
        expect(await newDb.select(newDb.revisionCards).get(), isEmpty);
        expect(await newDb.select(newDb.cardReviews).get(), isEmpty);
      },
    );
  });

  // v4 -> v5 adds the sync outbox and gives existing card reviews a stable sync id.
  test(
    'migration from v4 to v5 keeps cards and reviews and assigns sync ids',
    () async {
      const card = v4.RevisionCardsData(
        id: 'card-1',
        kind: 'question',
        questionId: 'q1',
        front: 'What is 20% of 150?',
        back: '(2) 30',
        reason: 'added',
        step: 1,
        gapDays: 3,
        dueOn: '2026-10-17',
        reviewCount: 1,
        lapseCount: 0,
        createdAt: '2026-10-13T09:00:00.000Z',
        updatedAt: '2026-10-14T09:00:00.000Z',
      );
      const review = v4.CardReviewsData(
        id: 1,
        cardId: 'card-1',
        reviewedAt: '2026-10-14T09:00:00.000Z',
        rating: 'good',
        dueBefore: '2026-10-14',
        dueAfter: '2026-10-17',
        gapDays: 3,
      );

      await verifier.testWithDataIntegrity(
        oldVersion: 4,
        newVersion: 5,
        createOld: v4.DatabaseAtV4.new,
        createNew: v5.DatabaseAtV5.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(oldDb.revisionCards, card);
          batch.insert(oldDb.cardReviews, review);
        },
        validateItems: (newDb) async {
          expect(
            (await newDb.select(newDb.revisionCards).get()).single.id,
            'card-1',
          );
          final migrated = (await newDb.select(newDb.cardReviews).get()).single;
          expect(migrated.cardId, 'card-1');
          expect(migrated.syncId, hasLength(32));
          expect(await newDb.select(newDb.syncOutbox).get(), isEmpty);
        },
      );
    },
  );
}
