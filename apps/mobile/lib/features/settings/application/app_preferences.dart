import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/content_language.dart';
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
  const AppPreferences({
    this.language = AppLanguage.system,
    this.themeMode = ThemeMode.system,
    this.contentLanguage,
    this.aiLanguage,
  });

  /// The app's interface language.
  final AppLanguage language;
  final ThemeMode themeMode;

  /// The usual language of the learner's papers, syllabus and notes (preselected when adding
  /// them); null = the interface language (global Phase 10).
  final ContentLanguage? contentLanguage;

  /// The language AI lessons and knowledge checks are written in; null = the interface
  /// language. AI explanations follow their question's language.
  final ContentLanguage? aiLanguage;

  AppPreferences copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    ContentLanguage? Function()? contentLanguage,
    ContentLanguage? Function()? aiLanguage,
  }) => AppPreferences(
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
    contentLanguage: contentLanguage == null ? this.contentLanguage : contentLanguage(),
    aiLanguage: aiLanguage == null ? this.aiLanguage : aiLanguage(),
  );

  /// [contentLanguage], else the language of the interface [locale].
  ContentLanguage contentLanguageFor(Locale locale) =>
      contentLanguage ?? contentLanguageForLocale(locale);

  /// [aiLanguage], else the language of the interface [locale].
  ContentLanguage aiLanguageFor(Locale locale) => aiLanguage ?? contentLanguageForLocale(locale);

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.language == language &&
      other.themeMode == themeMode &&
      other.contentLanguage == contentLanguage &&
      other.aiLanguage == aiLanguage;

  @override
  int get hashCode => Object.hash(language, themeMode, contentLanguage, aiLanguage);
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

  /// Null = same as the app's language.
  Future<void> setContentLanguage(ContentLanguage? language) =>
      _update(state.copyWith(contentLanguage: () => language));

  /// Null = same as the app's language.
  Future<void> setAiLanguage(ContentLanguage? language) =>
      _update(state.copyWith(aiLanguage: () => language));

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
