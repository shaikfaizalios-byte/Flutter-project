import 'package:flutter/material.dart';

import 'generated/app_localizations.dart';

/// The language of content (a paper, question, note or AI text), as a code from the server's
/// reference list (`app/domain/languages.py`, global Phase 10). Not the app's interface
/// language. A code this app version doesn't know is kept as it is, never turned into English.
@immutable
class ContentLanguage {
  const ContentLanguage(this.code);

  static const english = ContentLanguage('en');
  static const hindi = ContentLanguage('hi');

  /// The languages this app version offers for new content, in the order shown.
  static const known = [english, hindi];

  final String code;

  static ContentLanguage fromCode(String code) => ContentLanguage(code);

  bool get isKnown => known.contains(this);

  @override
  bool operator ==(Object other) => other is ContentLanguage && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'ContentLanguage($code)';
}

/// The language's name in the interface language ("Hindi" / "हिंदी"); an unknown code is shown
/// as itself.
String contentLanguageName(AppLocalizations l10n, ContentLanguage language) =>
    switch (language.code) {
      'en' => l10n.languageEnglish,
      'hi' => l10n.languageHindi,
      _ => language.code,
    };

/// A short badge for lists ("En", "हि"); an unknown code is shown in capitals.
String contentLanguageBadge(ContentLanguage language) => switch (language.code) {
  'en' => 'En',
  'hi' => 'हि',
  _ => language.code.toUpperCase(),
};

/// The content language that matches the interface [locale] (English when it has none).
ContentLanguage contentLanguageForLocale(Locale locale) => ContentLanguage.known.firstWhere(
  (l) => l.code == locale.languageCode,
  orElse: () => ContentLanguage.english,
);

/// Segments for choosing a content language: every language this app offers, plus [current]
/// when it is one it doesn't know (so editing old content never changes its language).
List<ButtonSegment<ContentLanguage>> contentLanguageSegments(
  AppLocalizations l10n, {
  ContentLanguage? current,
}) => [
  for (final language in [
    ...ContentLanguage.known,
    if (current != null && !current.isKnown) current,
  ])
    ButtonSegment(value: language, label: Text(contentLanguageName(l10n, language))),
];
