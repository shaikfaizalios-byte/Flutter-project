import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('hi')];

  /// Product name shown in the app bar and task switcher.
  ///
  /// In en, this message translates to:
  /// **'PrepLoop'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get navStudy;

  /// No description provided for @navPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get navPractice;

  /// No description provided for @navProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get navProgress;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your study loop'**
  String get homeHeadline;

  /// No description provided for @homeTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'What should I study today?'**
  String get homeTodayTitle;

  /// No description provided for @homeTodayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No study plan yet. Once you add concepts or import a question paper, your recommended tasks for today will appear here.'**
  String get homeTodayEmpty;

  /// No description provided for @homeWeakTitle.
  ///
  /// In en, this message translates to:
  /// **'Which topics am I weak in?'**
  String get homeWeakTitle;

  /// No description provided for @homeWeakEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough practice data yet. Weak topics are identified only after you have answered enough questions in a topic.'**
  String get homeWeakEmpty;

  /// No description provided for @homeUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'What is coming up next?'**
  String get homeUpcomingTitle;

  /// No description provided for @homeUpcomingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No revisions or goals are scheduled.'**
  String get homeUpcomingEmpty;

  /// No description provided for @studyTitle.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get studyTitle;

  /// No description provided for @studyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your study material lives here'**
  String get studyEmptyTitle;

  /// No description provided for @studyEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Concepts, flashcards and imported question papers will appear here. This section is available in an upcoming update.'**
  String get studyEmptyMessage;

  /// No description provided for @practiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practiceTitle;

  /// No description provided for @practiceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice sessions'**
  String get practiceEmptyTitle;

  /// No description provided for @practiceEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Topic-wise practice and timed mock tests will appear here once questions are available. This section is available in an upcoming update.'**
  String get practiceEmptyMessage;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressTitle;

  /// No description provided for @progressEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No progress data yet'**
  String get progressEmptyTitle;

  /// No description provided for @progressEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your accuracy and revision history will appear here after you start practising.'**
  String get progressEmptyMessage;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile & settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHindi;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsPreferencesNote.
  ///
  /// In en, this message translates to:
  /// **'These preferences are not saved yet and reset when the app restarts.'**
  String get settingsPreferencesNote;

  /// No description provided for @settingsServer.
  ///
  /// In en, this message translates to:
  /// **'Server connection'**
  String get settingsServer;

  /// No description provided for @serverChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get serverChecking;

  /// No description provided for @serverOnline.
  ///
  /// In en, this message translates to:
  /// **'Connected · API {version}'**
  String serverOnline(String version);

  /// No description provided for @serverOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the PrepLoop server.'**
  String get serverOffline;

  /// No description provided for @serverOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Features that work offline are not affected.'**
  String get serverOfflineHint;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @aboutBuild.
  ///
  /// In en, this message translates to:
  /// **'{appName} · {flavor} build'**
  String aboutBuild(String appName, String flavor);

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get goHome;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
