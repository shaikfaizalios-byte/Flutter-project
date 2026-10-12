import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/settings/application/app_preferences.dart';
import 'package:preploop/features/settings/data/preferences_repository.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('defaults when nothing is stored', () async {
    final repo = PreferencesRepository(createTestDatabase());

    expect(await repo.load(), const AppPreferences());
  });

  test('saved preferences round-trip', () async {
    final repo = PreferencesRepository(createTestDatabase());
    const prefs = AppPreferences(language: AppLanguage.hindi, themeMode: ThemeMode.dark);

    await repo.save(prefs);
    await repo.save(prefs); // upsert, not duplicate

    expect(await repo.load(), prefs);
  });

  test('unknown stored values fall back to defaults', () async {
    final db = createTestDatabase();
    await db
        .into(db.appSettings)
        .insert(AppSettingsCompanion.insert(key: 'language', value: 'klingon'));

    expect((await PreferencesRepository(db).load()).language, AppLanguage.system);
  });

  test('controller changes survive a restart (new container, same database)', () async {
    final db = createTestDatabase();

    final first = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    await first.read(appPreferencesProvider.notifier).setLanguage(AppLanguage.hindi);
    await first.read(appPreferencesProvider.notifier).setThemeMode(ThemeMode.dark);
    first.dispose();

    final loaded = await PreferencesRepository(db).load();
    final second = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        initialPreferencesProvider.overrideWithValue(loaded),
      ],
    );
    addTearDown(second.dispose);

    expect(
      second.read(appPreferencesProvider),
      const AppPreferences(language: AppLanguage.hindi, themeMode: ThemeMode.dark),
    );
  });
}
