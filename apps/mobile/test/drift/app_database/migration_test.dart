// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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
}
