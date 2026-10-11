// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PrepLoop';

  @override
  String get navHome => 'Home';

  @override
  String get navStudy => 'Study';

  @override
  String get navPractice => 'Practice';

  @override
  String get navProgress => 'Progress';

  @override
  String get navProfile => 'Profile';

  @override
  String get homeHeadline => 'Your study loop';

  @override
  String get homeTodayTitle => 'What should I study today?';

  @override
  String get homeTodayEmpty =>
      'No study plan yet. Once you add concepts or import a question paper, your recommended tasks for today will appear here.';

  @override
  String get homeWeakTitle => 'Which topics am I weak in?';

  @override
  String get homeWeakEmpty =>
      'Not enough practice data yet. Weak topics are identified only after you have answered enough questions in a topic.';

  @override
  String get homeUpcomingTitle => 'What is coming up next?';

  @override
  String get homeUpcomingEmpty => 'No revisions or goals are scheduled.';

  @override
  String get studyTitle => 'Study';

  @override
  String get studyEmptyTitle => 'Your study material lives here';

  @override
  String get studyEmptyMessage =>
      'Concepts, flashcards and imported question papers will appear here. This section is available in an upcoming update.';

  @override
  String get practiceTitle => 'Practice';

  @override
  String get practiceEmptyTitle => 'Practice sessions';

  @override
  String get practiceEmptyMessage =>
      'Topic-wise practice and timed mock tests will appear here once questions are available. This section is available in an upcoming update.';

  @override
  String get progressTitle => 'Progress';

  @override
  String get progressEmptyTitle => 'No progress data yet';

  @override
  String get progressEmptyMessage =>
      'Your accuracy and revision history will appear here after you start practising.';

  @override
  String get settingsTitle => 'Profile & settings';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsPreferencesNote =>
      'These preferences are not saved yet and reset when the app restarts.';

  @override
  String get settingsServer => 'Server connection';

  @override
  String get serverChecking => 'Checking…';

  @override
  String serverOnline(String version) {
    return 'Connected · API $version';
  }

  @override
  String get serverOffline => 'Cannot reach the PrepLoop server.';

  @override
  String get serverOfflineHint => 'Features that work offline are not affected.';

  @override
  String get retry => 'Try again';

  @override
  String get settingsAbout => 'About';

  @override
  String aboutBuild(String appName, String flavor) {
    return '$appName · $flavor build';
  }

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get goHome => 'Go to Home';
}
