import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/localization/content_language.dart';
import 'package:preploop/core/localization/generated/app_localizations_en.dart';
import 'package:preploop/features/settings/application/app_preferences.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('a code this app does not know is kept, never turned into English', () {
    final other = ContentLanguage.fromCode('ta');
    expect(other.code, 'ta');
    expect(other.isKnown, isFalse);
    expect(other == ContentLanguage.english, isFalse);
    expect(contentLanguageName(l10n, other), 'ta');
    expect(contentLanguageBadge(other), 'TA');
    expect(ContentLanguage.fromCode('hi'), ContentLanguage.hindi);
  });

  test('choices offer the known languages, plus an unknown current one', () {
    List<String> codes(ContentLanguage? current) => [
      for (final s in contentLanguageSegments(l10n, current: current)) s.value.code,
    ];
    expect(codes(null), ['en', 'hi']);
    expect(codes(ContentLanguage.hindi), ['en', 'hi']);
    expect(codes(const ContentLanguage('ta')), ['en', 'hi', 'ta']);
  });

  test('content and AI languages follow the interface unless chosen', () {
    const hindiUi = Locale('hi');
    const englishUi = Locale('en');
    expect(const AppPreferences().contentLanguageFor(hindiUi), ContentLanguage.hindi);
    expect(const AppPreferences().aiLanguageFor(const Locale('fr')), ContentLanguage.english);
    const prefs = AppPreferences(
      contentLanguage: ContentLanguage.hindi,
      aiLanguage: ContentLanguage.english,
    );
    expect(prefs.contentLanguageFor(englishUi), ContentLanguage.hindi);
    expect(prefs.aiLanguageFor(hindiUi), ContentLanguage.english);
  });
}
