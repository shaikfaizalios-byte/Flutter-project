import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/content_language.dart';
import '../application/app_preferences.dart';

import 'package:drift/drift.dart' show InsertMode;

/// Persists [AppPreferences] in the local `app_settings` table.
class PreferencesRepository {
  const PreferencesRepository(this._db);

  final AppDatabase _db;

  static const _languageKey = 'language';
  static const _themeModeKey = 'theme_mode';
  static const _contentLanguageKey = 'content_language';
  static const _aiLanguageKey = 'ai_language';

  Future<AppPreferences> load() async {
    final rows = await _db.select(_db.appSettings).get();
    final values = {for (final row in rows) row.key: row.value};
    return AppPreferences(
      language: AppLanguage.values.asNameMap()[values[_languageKey]] ?? AppLanguage.system,
      themeMode: ThemeMode.values.asNameMap()[values[_themeModeKey]] ?? ThemeMode.system,
      contentLanguage: _language(values[_contentLanguageKey]),
      aiLanguage: _language(values[_aiLanguageKey]),
    );
  }

  /// A stored code this app version offers; anything else = "same as the app".
  static ContentLanguage? _language(String? code) =>
      ContentLanguage.known.where((l) => l.code == code).firstOrNull;

  Future<void> save(AppPreferences prefs) => _db.batch((batch) {
    batch.insertAllOnConflictUpdate(_db.appSettings, [
      AppSettingsCompanion.insert(key: _languageKey, value: prefs.language.name),
      AppSettingsCompanion.insert(key: _themeModeKey, value: prefs.themeMode.name),
    ]);
    for (final (key, language) in [
      (_contentLanguageKey, prefs.contentLanguage),
      (_aiLanguageKey, prefs.aiLanguage),
    ]) {
      if (language == null) {
        batch.deleteWhere(_db.appSettings, (t) => t.key.equals(key));
      } else {
        batch.insert(
          _db.appSettings,
          AppSettingsCompanion.insert(key: key, value: language.code),
          mode: InsertMode.insertOrReplace,
        );
      }
    }
  });
}
