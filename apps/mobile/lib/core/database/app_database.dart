import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.steps.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The on-device SQLite database.
///
/// Schema changes: bump [schemaVersion], then run
/// `dart run drift_dev make-migrations` and implement the generated step in
/// [migration]. Never edit a released schema in place.
@DriftDatabase(tables: [Concepts, AppSettings, StudyProfiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the app's persistent database. On web this needs `sqlite3.wasm`
  /// and `drift_worker.js` in `web/` (see docs/database.md).
  AppDatabase.open()
    : super(
        driftDatabase(
          name: 'preploop',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      // v2: onboarding / study profile.
      from1To2: (m, schema) async {
        await m.createTable(schema.studyProfiles);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Overridden in `bootstrap()` with the opened database (and in tests with an
/// in-memory one).
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden.'),
);
