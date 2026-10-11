import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

/// In-memory for Phase 1. Persistence is added with local storage in Phase 2.
class AppPreferencesController extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => const AppPreferences();

  void setLanguage(AppLanguage language) => state = state.copyWith(language: language);

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);
}

final appPreferencesProvider = NotifierProvider<AppPreferencesController, AppPreferences>(
  AppPreferencesController.new,
);
