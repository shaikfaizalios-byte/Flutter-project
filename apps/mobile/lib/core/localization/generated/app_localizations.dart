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

  /// No description provided for @conceptsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search concepts'**
  String get conceptsSearchHint;

  /// No description provided for @conceptsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No concepts yet'**
  String get conceptsEmptyTitle;

  /// No description provided for @conceptsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add the topics and notes you are studying. They are saved on this device and work offline.'**
  String get conceptsEmptyMessage;

  /// No description provided for @conceptsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No concepts match \"{query}\".'**
  String conceptsNoResults(String query);

  /// No description provided for @conceptsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Your concepts could not be loaded.'**
  String get conceptsLoadError;

  /// No description provided for @conceptsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add concept'**
  String get conceptsAdd;

  /// No description provided for @conceptArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get conceptArchive;

  /// No description provided for @conceptArchived.
  ///
  /// In en, this message translates to:
  /// **'Concept archived'**
  String get conceptArchived;

  /// No description provided for @conceptSaved.
  ///
  /// In en, this message translates to:
  /// **'Concept saved'**
  String get conceptSaved;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @conceptOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for {title}'**
  String conceptOptions(String title);

  /// No description provided for @conceptFormTitle.
  ///
  /// In en, this message translates to:
  /// **'New concept'**
  String get conceptFormTitle;

  /// No description provided for @fieldExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get fieldExam;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get fieldSubject;

  /// No description provided for @fieldSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Quantitative Aptitude'**
  String get fieldSubjectHint;

  /// No description provided for @fieldTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get fieldTopic;

  /// No description provided for @fieldTopicHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Percentage'**
  String get fieldTopicHint;

  /// No description provided for @fieldSubtopic.
  ///
  /// In en, this message translates to:
  /// **'Subtopic (optional)'**
  String get fieldSubtopic;

  /// No description provided for @fieldContentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Content language'**
  String get fieldContentLanguage;

  /// No description provided for @fieldTags.
  ///
  /// In en, this message translates to:
  /// **'Tags (optional)'**
  String get fieldTags;

  /// No description provided for @fieldTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate tags with commas'**
  String get fieldTagsHint;

  /// No description provided for @fieldSourceReference.
  ///
  /// In en, this message translates to:
  /// **'Source (optional)'**
  String get fieldSourceReference;

  /// No description provided for @fieldSourceReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. book, page, or paper'**
  String get fieldSourceReferenceHint;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get fieldNotes;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'The concept could not be saved. Please try again.'**
  String get saveFailed;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get validationRequired;

  /// No description provided for @validationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Please shorten this to {max} characters or fewer.'**
  String validationTooLong(int max);

  /// No description provided for @validationTooManyTags.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} tags.'**
  String validationTooManyTags(int max);

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
