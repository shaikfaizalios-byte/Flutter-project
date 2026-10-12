import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_log.dart';
import '../data/preferences_repository.dart';

enum AppLanguage {
  system(null),
  english(Locale('en')),
  hindi(Locale('hi'));

  const AppLanguage(this.locale);

  /// `null` means "follow the device language".
  final Locale? locale;
}

@immutable
class AppPreferences {
  const AppPreferences({this.language = AppLanguage.system, this.themeMode = ThemeMode.system});

  final AppLanguage language;
  final ThemeMode themeMode;

  AppPreferences copyWith({AppLanguage? language, ThemeMode? themeMode}) =>
      AppPreferences(language: language ?? this.language, themeMode: themeMode ?? this.themeMode);

  @override
  bool operator ==(Object other) =>
      other is AppPreferences && other.language == language && other.themeMode == themeMode;

  @override
  int get hashCode => Object.hash(language, themeMode);
}

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(appDatabaseProvider)),
);

/// Preferences loaded before the first frame (so the UI never flashes the
/// wrong language or theme). Overridden in `bootstrap()`.
final initialPreferencesProvider = Provider<AppPreferences>((ref) => const AppPreferences());

class AppPreferencesController extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => ref.watch(initialPreferencesProvider);

  Future<void> setLanguage(AppLanguage language) => _update(state.copyWith(language: language));

  Future<void> setThemeMode(ThemeMode mode) => _update(state.copyWith(themeMode: mode));

  Future<void> _update(AppPreferences next) async {
    // Apply immediately; persistence failure must not block the UI change.
    state = next;
    try {
      await ref.read(preferencesRepositoryProvider).save(next);
    } on Object catch (error, stack) {
      logError('Saving preferences failed', error, stack);
    }
  }
}

final appPreferencesProvider = NotifierProvider<AppPreferencesController, AppPreferences>(
  AppPreferencesController.new,
);
