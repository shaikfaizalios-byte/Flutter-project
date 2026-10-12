import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../application/app_preferences.dart';

/// Persists [AppPreferences] in the local `app_settings` table.
class PreferencesRepository {
  const PreferencesRepository(this._db);

  final AppDatabase _db;

  static const _languageKey = 'language';
  static const _themeModeKey = 'theme_mode';

  Future<AppPreferences> load() async {
    final rows = await _db.select(_db.appSettings).get();
    final values = {for (final row in rows) row.key: row.value};
    return AppPreferences(
      language: AppLanguage.values.asNameMap()[values[_languageKey]] ?? AppLanguage.system,
      themeMode: ThemeMode.values.asNameMap()[values[_themeModeKey]] ?? ThemeMode.system,
    );
  }

  Future<void> save(AppPreferences prefs) => _db.batch((batch) {
    batch.insertAllOnConflictUpdate(_db.appSettings, [
      AppSettingsCompanion.insert(key: _languageKey, value: prefs.language.name),
      AppSettingsCompanion.insert(key: _themeModeKey, value: prefs.themeMode.name),
    ]);
  });
}
