import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/localization/content_language.dart';
import 'package:preploop/core/localization/generated/app_localizations.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';

Map<String, dynamic> tally({Object? cutoff, Object? cleared, int? partial}) => {
  'name': 'Maths',
  'correct': 1,
  'wrong': 0,
  'unattempted': 0,
  'score': 4,
  'max_score': 4,
  'accuracy': 1,
  'explanation': 'x',
  'cutoff': ?cutoff,
  'cleared': ?cleared,
  'partial': ?partial,
};

void main() {
  test('a section without a cutoff has none, and older results read as before', () {
    final read = TallyView.fromJson(tally());
    expect(read.cutoff, isNull);
    expect(read.cleared, isNull);
    expect(read.partial, 0);
  });

  test('a cutoff and partly right answers are read', () {
    final read = TallyView.fromJson(tally(cutoff: 3, cleared: true, partial: 2));
    expect((read.cutoff, read.cleared, read.partial), (3.0, true, 2));
  });

  group('translations', () {
    final item = SessionItemView.fromJson({
      'position': 1,
      'options': <dynamic>[],
      'figures': <dynamic>[],
      'verified': true,
      'bookmarked': false,
      'source': <String, dynamic>{},
      'translations': [
        {
          'language': 'hi',
          'stem': 'प्रश्न',
          'options': ['क', 'ख'],
        },
      ],
    });

    test('are found by language', () {
      expect(item.translationIn('hi')?.stem, 'प्रश्न');
      expect(item.translationIn('ta'), isNull);
      expect(item.translationIn(null), isNull);
    });

    test('options keep their position', () {
      final hindi = item.translationIn('hi')!;
      expect(hindi.option(2), 'ख');
      expect(hindi.option(3), isNull);
      expect(hindi.option(0), isNull);
    });
  });

  test('regional languages are named in their own script; others stay as codes', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(contentLanguageName(l10n, const ContentLanguage('ta')), 'தமிழ்');
    expect(contentLanguageName(l10n, const ContentLanguage('xx')), 'xx');
    expect(ContentLanguage.all.length, ContentLanguage.known.length + 10);
  });

  test('the languages offered by default are unchanged', () {
    expect(ContentLanguage.known.map((l) => l.code), ['en', 'hi']);
  });
}
