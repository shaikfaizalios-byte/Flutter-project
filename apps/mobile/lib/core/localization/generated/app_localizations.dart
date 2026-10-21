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

  /// No description provided for @navFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get navFeaturesTitle;

  /// No description provided for @homeShortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Go straight to'**
  String get homeShortcutsTitle;

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

  /// No description provided for @onboardingStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onboardingStep(int step, int total);

  /// No description provided for @onboardingSkipSetup.
  ///
  /// In en, this message translates to:
  /// **'Skip setup'**
  String get onboardingSkipSetup;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @onboardingFinish.
  ///
  /// In en, this message translates to:
  /// **'Start studying'**
  String get onboardingFinish;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to PrepLoop'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Let\'s set up your preparation. Every step is optional, and you can change your answers later in Profile. Your answers are stored on this device.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingExamTitle.
  ///
  /// In en, this message translates to:
  /// **'Which exam are you preparing for?'**
  String get onboardingExamTitle;

  /// No description provided for @onboardingExamHint.
  ///
  /// In en, this message translates to:
  /// **'Select one or both.'**
  String get onboardingExamHint;

  /// No description provided for @onboardingDateTitle.
  ///
  /// In en, this message translates to:
  /// **'When is your exam?'**
  String get onboardingDateTitle;

  /// No description provided for @onboardingDateHint.
  ///
  /// In en, this message translates to:
  /// **'If you know the date, PrepLoop shows a countdown. You can skip this.'**
  String get onboardingDateHint;

  /// No description provided for @onboardingDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'How much time can you study each day?'**
  String get onboardingDailyTitle;

  /// No description provided for @onboardingDailyHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a realistic amount. Studying a little every day works better than occasional long sessions.'**
  String get onboardingDailyHint;

  /// No description provided for @onboardingReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'When should PrepLoop remind you to study?'**
  String get onboardingReminderTitle;

  /// No description provided for @onboardingReminderHint.
  ///
  /// In en, this message translates to:
  /// **'Switch on the daily reminder in Profile. PrepLoop asks for notification permission only then.'**
  String get onboardingReminderHint;

  /// No description provided for @chooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get chooseDate;

  /// No description provided for @chooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose time'**
  String get chooseTime;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String durationHours(int hours);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @settingsStudyPlan.
  ///
  /// In en, this message translates to:
  /// **'Study plan'**
  String get settingsStudyPlan;

  /// No description provided for @fieldExams.
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get fieldExams;

  /// No description provided for @examsNotChosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen'**
  String get examsNotChosen;

  /// No description provided for @fieldExamDate.
  ///
  /// In en, this message translates to:
  /// **'Exam date'**
  String get fieldExamDate;

  /// No description provided for @fieldDailyStudy.
  ///
  /// In en, this message translates to:
  /// **'Daily study time'**
  String get fieldDailyStudy;

  /// No description provided for @fieldReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get fieldReminder;

  /// No description provided for @settingsLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get settingsLicences;

  /// No description provided for @homeChooseExamTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your exam'**
  String get homeChooseExamTitle;

  /// No description provided for @homeChooseExamMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose the exams you\'re preparing for to personalise PrepLoop.'**
  String get homeChooseExamMessage;

  /// No description provided for @homeChooseExamAction.
  ///
  /// In en, this message translates to:
  /// **'Choose exam'**
  String get homeChooseExamAction;

  /// No description provided for @homeExamCountdown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Your exam is today} =1{1 day to go} other{{count} days to go}}'**
  String homeExamCountdown(int count);

  /// No description provided for @homeExamPassed.
  ///
  /// In en, this message translates to:
  /// **'Your exam date has passed. You can update it in Profile.'**
  String get homeExamPassed;

  /// No description provided for @homeExamOn.
  ///
  /// In en, this message translates to:
  /// **'Exam date: {date}'**
  String homeExamOn(String date);

  /// No description provided for @homeConceptCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{You have not added any concepts yet.} =1{You have 1 concept saved.} other{You have {count} concepts saved.}}'**
  String homeConceptCount(int count);

  /// No description provided for @homeDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily study goal: {duration}'**
  String homeDailyGoal(String duration);

  /// No description provided for @homeOpenConcepts.
  ///
  /// In en, this message translates to:
  /// **'Open concepts'**
  String get homeOpenConcepts;

  /// No description provided for @homeSetExamDate.
  ///
  /// In en, this message translates to:
  /// **'Set your exam date in Profile to see a countdown.'**
  String get homeSetExamDate;

  /// No description provided for @conceptDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Concept'**
  String get conceptDetailsTitle;

  /// No description provided for @conceptEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get conceptEdit;

  /// No description provided for @conceptEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit concept'**
  String get conceptEditTitle;

  /// No description provided for @conceptUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get conceptUnarchive;

  /// No description provided for @conceptRestored.
  ///
  /// In en, this message translates to:
  /// **'Concept restored'**
  String get conceptRestored;

  /// No description provided for @conceptDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get conceptDelete;

  /// No description provided for @conceptDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this concept?'**
  String get conceptDeleteTitle;

  /// No description provided for @conceptDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be permanently deleted from this device. This cannot be undone.'**
  String conceptDeleteMessage(String title);

  /// No description provided for @conceptDeleted.
  ///
  /// In en, this message translates to:
  /// **'Concept deleted'**
  String get conceptDeleted;

  /// No description provided for @conceptNotFound.
  ///
  /// In en, this message translates to:
  /// **'This concept no longer exists.'**
  String get conceptNotFound;

  /// No description provided for @conceptLoadError.
  ///
  /// In en, this message translates to:
  /// **'This concept could not be loaded.'**
  String get conceptLoadError;

  /// No description provided for @conceptArchivedBanner.
  ///
  /// In en, this message translates to:
  /// **'This concept is archived and hidden from your main list.'**
  String get conceptArchivedBanner;

  /// No description provided for @conceptCreatedOn.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String conceptCreatedOn(String date);

  /// No description provided for @conceptUpdatedOn.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String conceptUpdatedOn(String date);

  /// No description provided for @conceptMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get conceptMoreActions;

  /// No description provided for @filterExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get filterExam;

  /// No description provided for @filterSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get filterSubject;

  /// No description provided for @filterTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get filterTopic;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get filterArchived;

  /// No description provided for @filterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get filterClear;

  /// No description provided for @filterBy.
  ///
  /// In en, this message translates to:
  /// **'Filter by {label}'**
  String filterBy(String label);

  /// No description provided for @conceptsNoFilterResults.
  ///
  /// In en, this message translates to:
  /// **'No concepts match these filters.'**
  String get conceptsNoFilterResults;

  /// No description provided for @conceptsArchivedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No archived concepts.'**
  String get conceptsArchivedEmpty;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Imported papers'**
  String get documentsTitle;

  /// No description provided for @documentsImport.
  ///
  /// In en, this message translates to:
  /// **'Import PDF'**
  String get documentsImport;

  /// No description provided for @documentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No papers imported yet'**
  String get documentsEmptyTitle;

  /// No description provided for @documentsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Import previous-year papers or study PDFs. PrepLoop reads the text page by page and flags pages it cannot read reliably for review.'**
  String get documentsEmptyMessage;

  /// No description provided for @documentsOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the PrepLoop server'**
  String get documentsOfflineTitle;

  /// No description provided for @documentsOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Importing papers needs an internet connection. Your concepts still work offline.'**
  String get documentsOfflineMessage;

  /// No description provided for @documentsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Your imported papers could not be loaded.'**
  String get documentsLoadError;

  /// No description provided for @documentStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be processed'**
  String get documentStatusQueued;

  /// No description provided for @documentStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Reading page {done} of {total}'**
  String documentStatusProcessing(int done, int total);

  /// No description provided for @documentStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get documentStatusCompleted;

  /// No description provided for @documentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed'**
  String get documentStatusFailed;

  /// No description provided for @documentPages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String documentPages(int count);

  /// No description provided for @documentNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page needs review} other{{count} pages need review}}'**
  String documentNeedsReview(int count);

  /// No description provided for @documentErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'This document took too long to process.'**
  String get documentErrorTimeout;

  /// No description provided for @documentErrorSourceMissing.
  ///
  /// In en, this message translates to:
  /// **'The original file is no longer available.'**
  String get documentErrorSourceMissing;

  /// No description provided for @documentErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while reading this document.'**
  String get documentErrorGeneric;

  /// No description provided for @documentOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for {filename}'**
  String documentOptions(String filename);

  /// No description provided for @documentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this paper?'**
  String get documentDeleteTitle;

  /// No description provided for @documentDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{filename}\" and the text extracted from it will be permanently deleted from the server.'**
  String documentDeleteMessage(String filename);

  /// No description provided for @documentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Paper deleted'**
  String get documentDeleted;

  /// No description provided for @importSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Import \"{filename}\"'**
  String importSheetTitle(String filename);

  /// No description provided for @importUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get importUpload;

  /// No description provided for @importUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {filename}…'**
  String importUploading(String filename);

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Upload complete. Processing has started.'**
  String get importDone;

  /// No description provided for @uploadErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than the allowed size.'**
  String get uploadErrorTooLarge;

  /// No description provided for @uploadErrorNotPdf.
  ///
  /// In en, this message translates to:
  /// **'Only PDF files can be imported.'**
  String get uploadErrorNotPdf;

  /// No description provided for @uploadErrorEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This PDF is password-protected. Remove the password and try again.'**
  String get uploadErrorEncrypted;

  /// No description provided for @uploadErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is damaged or is not a valid PDF.'**
  String get uploadErrorInvalid;

  /// No description provided for @uploadErrorTooManyPages.
  ///
  /// In en, this message translates to:
  /// **'This PDF has too many pages.'**
  String get uploadErrorTooManyPages;

  /// No description provided for @uploadErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'This file is empty.'**
  String get uploadErrorEmpty;

  /// No description provided for @uploadErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You have uploaded several files recently. Please wait a while and try again.'**
  String get uploadErrorRateLimited;

  /// No description provided for @uploadErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not upload: there is no connection to the server.'**
  String get uploadErrorOffline;

  /// No description provided for @uploadErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'The upload failed. Please try again.'**
  String get uploadErrorGeneric;

  /// No description provided for @issueMissingAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer not found'**
  String get issueMissingAnswer;

  /// No description provided for @issueIncompleteOptions.
  ///
  /// In en, this message translates to:
  /// **'Options incomplete'**
  String get issueIncompleteOptions;

  /// No description provided for @issueEmptyOption.
  ///
  /// In en, this message translates to:
  /// **'An option is empty'**
  String get issueEmptyOption;

  /// No description provided for @issueDuplicateNumber.
  ///
  /// In en, this message translates to:
  /// **'Question number repeated'**
  String get issueDuplicateNumber;

  /// No description provided for @issueAmbiguousBoundary.
  ///
  /// In en, this message translates to:
  /// **'Question boundary unclear'**
  String get issueAmbiguousBoundary;

  /// No description provided for @issueImageDependent.
  ///
  /// In en, this message translates to:
  /// **'Needs the original figure'**
  String get issueImageDependent;

  /// No description provided for @issueRepeatedOptionLabels.
  ///
  /// In en, this message translates to:
  /// **'Extra options found (possibly a second language)'**
  String get issueRepeatedOptionLabels;

  /// No description provided for @issueAnswerNotInOptions.
  ///
  /// In en, this message translates to:
  /// **'Answer does not match the options'**
  String get issueAnswerNotInOptions;

  /// No description provided for @issueConflictingAnswers.
  ///
  /// In en, this message translates to:
  /// **'Different answers found'**
  String get issueConflictingAnswers;

  /// No description provided for @issueSourcePageNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Source page was hard to read'**
  String get issueSourcePageNeedsReview;

  /// No description provided for @issueNoQuestionsFound.
  ///
  /// In en, this message translates to:
  /// **'No questions were found'**
  String get issueNoQuestionsFound;

  /// No description provided for @issueNumberingGaps.
  ///
  /// In en, this message translates to:
  /// **'Some question numbers are missing'**
  String get issueNumberingGaps;

  /// No description provided for @issueAnswerKeyUnmatched.
  ///
  /// In en, this message translates to:
  /// **'Answer key has numbers that are not in the paper'**
  String get issueAnswerKeyUnmatched;

  /// No description provided for @issueAnswerKeyAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'Numbering restarts in each section, so answers must be set during review'**
  String get issueAnswerKeyAmbiguous;

  /// No description provided for @issueCountMismatch.
  ///
  /// In en, this message translates to:
  /// **'Question count differs from the official format'**
  String get issueCountMismatch;

  /// No description provided for @issueSectionCountMismatch.
  ///
  /// In en, this message translates to:
  /// **'A section\'s count differs from the official format'**
  String get issueSectionCountMismatch;

  /// No description provided for @issueOther.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get issueOther;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review questions'**
  String get reviewTitle;

  /// No description provided for @reviewQuestions.
  ///
  /// In en, this message translates to:
  /// **'Review questions'**
  String get reviewQuestions;

  /// No description provided for @reviewSummaryVerified.
  ///
  /// In en, this message translates to:
  /// **'{count} verified'**
  String reviewSummaryVerified(int count);

  /// No description provided for @reviewSummaryAttention.
  ///
  /// In en, this message translates to:
  /// **'{count} need attention'**
  String reviewSummaryAttention(int count);

  /// No description provided for @reviewSummaryMissingAnswers.
  ///
  /// In en, this message translates to:
  /// **'{count} without an answer'**
  String reviewSummaryMissingAnswers(int count);

  /// No description provided for @reviewFormat.
  ///
  /// In en, this message translates to:
  /// **'Format: {name}'**
  String reviewFormat(String name);

  /// No description provided for @reviewFormatUnknown.
  ///
  /// In en, this message translates to:
  /// **'No verified format linked, so question-count checks are skipped.'**
  String get reviewFormatUnknown;

  /// No description provided for @reviewReparse.
  ///
  /// In en, this message translates to:
  /// **'Parse again'**
  String get reviewReparse;

  /// No description provided for @reviewReparsed.
  ///
  /// In en, this message translates to:
  /// **'Questions parsed again. Your reviewed questions were kept.'**
  String get reviewReparsed;

  /// No description provided for @reviewSegmentationPending.
  ///
  /// In en, this message translates to:
  /// **'Questions will appear after the text has been extracted.'**
  String get reviewSegmentationPending;

  /// No description provided for @reviewSegmentationFailed.
  ///
  /// In en, this message translates to:
  /// **'Questions could not be parsed from this paper.'**
  String get reviewSegmentationFailed;

  /// No description provided for @reviewNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'No questions in this view.'**
  String get reviewNoQuestions;

  /// No description provided for @filterAllQuestions.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAllQuestions;

  /// No description provided for @filterNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get filterNeedsAttention;

  /// No description provided for @filterVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get filterVerified;

  /// No description provided for @filterRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get filterRejected;

  /// No description provided for @documentQuestionsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No questions found} =1{1 question found} other{{count} questions found}}'**
  String documentQuestionsFound(int count);

  /// No description provided for @questionNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Q.{number}'**
  String questionNumberLabel(int number);

  /// No description provided for @questionSource.
  ///
  /// In en, this message translates to:
  /// **'From {filename}, page {page}'**
  String questionSource(String filename, int page);

  /// No description provided for @questionLabelSource.
  ///
  /// In en, this message translates to:
  /// **'From your PDF'**
  String get questionLabelSource;

  /// No description provided for @questionLabelAi.
  ///
  /// In en, this message translates to:
  /// **'AI-generated'**
  String get questionLabelAi;

  /// No description provided for @questionStatusVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get questionStatusVerified;

  /// No description provided for @questionStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get questionStatusRejected;

  /// No description provided for @questionStatusUnverified.
  ///
  /// In en, this message translates to:
  /// **'Not reviewed'**
  String get questionStatusUnverified;

  /// No description provided for @questionTitle.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get questionTitle;

  /// No description provided for @fieldStem.
  ///
  /// In en, this message translates to:
  /// **'Question text'**
  String get fieldStem;

  /// No description provided for @fieldOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get fieldOptions;

  /// No description provided for @fieldOption.
  ///
  /// In en, this message translates to:
  /// **'Option {label}'**
  String fieldOption(String label);

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOption;

  /// No description provided for @fieldCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get fieldCorrectAnswer;

  /// No description provided for @answerNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get answerNotSet;

  /// No description provided for @fieldExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation (optional)'**
  String get fieldExplanation;

  /// No description provided for @topicSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested topic. Approving the question confirms it.'**
  String get topicSuggested;

  /// No description provided for @topicNone.
  ///
  /// In en, this message translates to:
  /// **'No topic'**
  String get topicNone;

  /// No description provided for @fieldImageDependent.
  ///
  /// In en, this message translates to:
  /// **'Needs the original figure or image'**
  String get fieldImageDependent;

  /// No description provided for @sharedPassage.
  ///
  /// In en, this message translates to:
  /// **'Shared passage (Q.{first} to Q.{last})'**
  String sharedPassage(int first, int last);

  /// No description provided for @sourcePageText.
  ///
  /// In en, this message translates to:
  /// **'Source page text'**
  String get sourcePageText;

  /// No description provided for @sourcePageLoadError.
  ///
  /// In en, this message translates to:
  /// **'The page text could not be loaded.'**
  String get sourcePageLoadError;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @questionApproved.
  ///
  /// In en, this message translates to:
  /// **'Question approved'**
  String get questionApproved;

  /// No description provided for @questionRejected.
  ///
  /// In en, this message translates to:
  /// **'Question rejected'**
  String get questionRejected;

  /// No description provided for @cannotVerify.
  ///
  /// In en, this message translates to:
  /// **'Fix the listed problems before approving.'**
  String get cannotVerify;

  /// No description provided for @openIssues.
  ///
  /// In en, this message translates to:
  /// **'Problems to check'**
  String get openIssues;

  /// No description provided for @bankTitle.
  ///
  /// In en, this message translates to:
  /// **'Question bank'**
  String get bankTitle;

  /// No description provided for @bankSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search questions'**
  String get bankSearchHint;

  /// No description provided for @bankEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No questions yet'**
  String get bankEmptyTitle;

  /// No description provided for @bankEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Import a previous-year paper in Study, then Imported papers. Its questions appear here for review, and reviewed questions can be practised.'**
  String get bankEmptyMessage;

  /// No description provided for @bankLoadError.
  ///
  /// In en, this message translates to:
  /// **'Questions could not be loaded.'**
  String get bankLoadError;

  /// No description provided for @practiceHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practiceHubTitle;

  /// No description provided for @practiceStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice questions'**
  String get practiceStartTitle;

  /// No description provided for @practiceStartMessage.
  ///
  /// In en, this message translates to:
  /// **'Untimed. You see whether you are right after each answer.'**
  String get practiceStartMessage;

  /// No description provided for @practiceStart.
  ///
  /// In en, this message translates to:
  /// **'Start practice'**
  String get practiceStart;

  /// No description provided for @practiceSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up practice'**
  String get practiceSetupTitle;

  /// No description provided for @practiceMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed (all subjects)'**
  String get practiceMixed;

  /// No description provided for @practiceSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get practiceSubject;

  /// No description provided for @practiceTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic (optional)'**
  String get practiceTopic;

  /// No description provided for @practiceTopicAny.
  ///
  /// In en, this message translates to:
  /// **'Any topic'**
  String get practiceTopicAny;

  /// No description provided for @practiceCount.
  ///
  /// In en, this message translates to:
  /// **'Number of questions'**
  String get practiceCount;

  /// No description provided for @practiceIncludeUnverified.
  ///
  /// In en, this message translates to:
  /// **'Include questions not yet reviewed'**
  String get practiceIncludeUnverified;

  /// No description provided for @practiceIncludeUnverifiedHint.
  ///
  /// In en, this message translates to:
  /// **'They are labelled, and their answers may contain extraction mistakes.'**
  String get practiceIncludeUnverifiedHint;

  /// No description provided for @practiceNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'No reviewed questions match. Approve questions in the question bank, or include ones not yet reviewed.'**
  String get practiceNoQuestions;

  /// No description provided for @mockTestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Mock tests'**
  String get mockTestsTitle;

  /// No description provided for @mockTestsMessage.
  ///
  /// In en, this message translates to:
  /// **'Timed tests built only from verified official exam formats.'**
  String get mockTestsMessage;

  /// No description provided for @mockTestsNone.
  ///
  /// In en, this message translates to:
  /// **'No verified exam formats are available yet.'**
  String get mockTestsNone;

  /// No description provided for @mockTestDetails.
  ///
  /// In en, this message translates to:
  /// **'{questions} questions · {minutes} min'**
  String mockTestDetails(int questions, int minutes);

  /// No description provided for @mockNegative.
  ///
  /// In en, this message translates to:
  /// **'−{marks} per wrong answer'**
  String mockNegative(String marks);

  /// No description provided for @mockStart.
  ///
  /// In en, this message translates to:
  /// **'Start mock test'**
  String get mockStart;

  /// No description provided for @mockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not enough reviewed questions yet:'**
  String get mockUnavailable;

  /// No description provided for @mockSectionShort.
  ///
  /// In en, this message translates to:
  /// **'{subject}: {available} of {needed}'**
  String mockSectionShort(String subject, int available, int needed);

  /// No description provided for @mockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start the mock test?'**
  String get mockConfirmTitle;

  /// No description provided for @mockConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'The timer starts now and keeps running even if you close the app. The test is submitted automatically when time is up.'**
  String get mockConfirmMessage;

  /// No description provided for @reviewToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewToolsTitle;

  /// No description provided for @bookmarksTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarksTitle;

  /// No description provided for @bookmarksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bookmarked questions.'**
  String get bookmarksEmpty;

  /// No description provided for @incorrectTitle.
  ///
  /// In en, this message translates to:
  /// **'Questions to revisit'**
  String get incorrectTitle;

  /// No description provided for @incorrectEmpty.
  ///
  /// In en, this message translates to:
  /// **'No incorrect answers to review.'**
  String get incorrectEmpty;

  /// No description provided for @questionBankOpen.
  ///
  /// In en, this message translates to:
  /// **'Question bank'**
  String get questionBankOpen;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your practice sessions will appear here.'**
  String get historyEmpty;

  /// No description provided for @historyPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get historyPractice;

  /// No description provided for @historyMock.
  ///
  /// In en, this message translates to:
  /// **'Mock: {name}'**
  String historyMock(String name);

  /// No description provided for @historyInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get historyInProgress;

  /// No description provided for @historyScore.
  ///
  /// In en, this message translates to:
  /// **'{score} / {max}'**
  String historyScore(String score, String max);

  /// No description provided for @sessionQuestionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String sessionQuestionOf(int current, int total);

  /// No description provided for @sessionNotReviewed.
  ///
  /// In en, this message translates to:
  /// **'Not yet reviewed'**
  String get sessionNotReviewed;

  /// No description provided for @sessionPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get sessionPrevious;

  /// No description provided for @sessionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get sessionNext;

  /// No description provided for @sessionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get sessionSubmit;

  /// No description provided for @sessionFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get sessionFinish;

  /// No description provided for @sessionCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get sessionCorrect;

  /// No description provided for @sessionIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get sessionIncorrect;

  /// No description provided for @sessionCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: ({label})'**
  String sessionCorrectAnswer(String label);

  /// No description provided for @sessionSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It will be sent when you are back online.'**
  String get sessionSavedOffline;

  /// No description provided for @sessionFeedbackOffline.
  ///
  /// In en, this message translates to:
  /// **'Feedback will appear when you are back online.'**
  String get sessionFeedbackOffline;

  /// No description provided for @sessionSubmitTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit now?'**
  String get sessionSubmitTitle;

  /// No description provided for @sessionUnanswered.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{All questions are answered.} =1{1 question is unanswered.} other{{count} questions are unanswered.}}'**
  String sessionUnanswered(int count);

  /// No description provided for @sessionTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Time is up. Your saved answers were submitted.'**
  String get sessionTimeUp;

  /// No description provided for @sessionTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'Time left {time}'**
  String sessionTimeLeft(String time);

  /// No description provided for @sessionQuestionRemoved.
  ///
  /// In en, this message translates to:
  /// **'This question was removed from the question bank.'**
  String get sessionQuestionRemoved;

  /// No description provided for @sessionLoadError.
  ///
  /// In en, this message translates to:
  /// **'This session could not be loaded.'**
  String get sessionLoadError;

  /// No description provided for @sessionOfflineOpen.
  ///
  /// In en, this message translates to:
  /// **'Opening a session needs a connection. Answers you give during a session are saved on this device if the connection drops.'**
  String get sessionOfflineOpen;

  /// No description provided for @sessionPalette.
  ///
  /// In en, this message translates to:
  /// **'All questions'**
  String get sessionPalette;

  /// No description provided for @sessionBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get sessionBookmark;

  /// No description provided for @sessionRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get sessionRemoveBookmark;

  /// No description provided for @sessionSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit. Your answers are saved; try again when you are online.'**
  String get sessionSubmitFailed;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get resultTitle;

  /// No description provided for @resultScore.
  ///
  /// In en, this message translates to:
  /// **'{score} of {max}'**
  String resultScore(String score, String max);

  /// No description provided for @resultAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy {percent}%'**
  String resultAccuracy(int percent);

  /// No description provided for @resultAccuracyNone.
  ///
  /// In en, this message translates to:
  /// **'No questions attempted'**
  String get resultAccuracyNone;

  /// No description provided for @resultTime.
  ///
  /// In en, this message translates to:
  /// **'Time taken {time}'**
  String resultTime(String time);

  /// No description provided for @resultCounts.
  ///
  /// In en, this message translates to:
  /// **'{correct} correct · {wrong} wrong · {unattempted} unattempted'**
  String resultCounts(int correct, int wrong, int unattempted);

  /// No description provided for @resultHowScored.
  ///
  /// In en, this message translates to:
  /// **'How this score was calculated'**
  String get resultHowScored;

  /// No description provided for @resultSections.
  ///
  /// In en, this message translates to:
  /// **'By section'**
  String get resultSections;

  /// No description provided for @resultTopics.
  ///
  /// In en, this message translates to:
  /// **'By topic'**
  String get resultTopics;

  /// No description provided for @resultReviewAnswers.
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get resultReviewAnswers;

  /// No description provided for @resultYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer: ({label})'**
  String resultYourAnswer(String label);

  /// No description provided for @resultNotAnswered.
  ///
  /// In en, this message translates to:
  /// **'Not answered'**
  String get resultNotAnswered;

  /// No description provided for @resultSubmittedTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Submitted automatically when time was up.'**
  String get resultSubmittedTimeUp;

  /// No description provided for @revisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get revisionTitle;

  /// No description provided for @revisionDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get revisionDueTitle;

  /// No description provided for @revisionDueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card to revise} other{{count} cards to revise}}'**
  String revisionDueCount(int count);

  /// No description provided for @revisionOverdueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 of them is overdue} other{{count} of them are overdue}}'**
  String revisionOverdueCount(int count);

  /// No description provided for @revisionStart.
  ///
  /// In en, this message translates to:
  /// **'Start revision'**
  String get revisionStart;

  /// No description provided for @revisionNothingDue.
  ///
  /// In en, this message translates to:
  /// **'Nothing to revise today.'**
  String get revisionNothingDue;

  /// No description provided for @revisionNextReview.
  ///
  /// In en, this message translates to:
  /// **'Next review: {when}'**
  String revisionNextReview(String when);

  /// No description provided for @revisionUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get revisionUpcomingTitle;

  /// No description provided for @revisionScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Revision schedule'**
  String get revisionScheduleTitle;

  /// No description provided for @revisionLadder.
  ///
  /// In en, this message translates to:
  /// **'Review on day {days} after adding a card'**
  String revisionLadder(String days);

  /// No description provided for @revisionLadderExplanation.
  ///
  /// In en, this message translates to:
  /// **'Remembering moves a card to the next review day; after the last one the gap keeps doubling. Hard repeats with a shorter gap. Forgetting starts the card again from the first day.'**
  String get revisionLadderExplanation;

  /// No description provided for @revisionEditSchedule.
  ///
  /// In en, this message translates to:
  /// **'Change schedule'**
  String get revisionEditSchedule;

  /// No description provided for @revisionScheduleHelp.
  ///
  /// In en, this message translates to:
  /// **'Days after you add a card when it comes back for review. Changes apply to future reviews; cards keep their current due dates.'**
  String get revisionScheduleHelp;

  /// No description provided for @revisionScheduleField.
  ///
  /// In en, this message translates to:
  /// **'Review days'**
  String get revisionScheduleField;

  /// No description provided for @revisionScheduleFieldHint.
  ///
  /// In en, this message translates to:
  /// **'For example: 1, 4, 7'**
  String get revisionScheduleFieldHint;

  /// No description provided for @revisionScheduleInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 1 to {maxSteps} different days between 1 and {maxDay}.'**
  String revisionScheduleInvalid(int maxSteps, int maxDay);

  /// No description provided for @revisionScheduleReset.
  ///
  /// In en, this message translates to:
  /// **'Use 1, 4, 7'**
  String get revisionScheduleReset;

  /// No description provided for @revisionScheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Revision schedule saved.'**
  String get revisionScheduleSaved;

  /// No description provided for @revisionAllCards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card} other{All cards ({count})}}'**
  String revisionAllCards(int count);

  /// No description provided for @revisionEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No flashcards yet'**
  String get revisionEmptyTitle;

  /// No description provided for @revisionEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a concept to revision from its details page, or add questions from Practice → Bookmarks or Questions to revisit.'**
  String get revisionEmptyMessage;

  /// No description provided for @revisionLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your flashcards.'**
  String get revisionLoadError;

  /// No description provided for @revisionSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get revisionSaveError;

  /// No description provided for @revisionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get revisionRemove;

  /// No description provided for @revisionRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from revision.'**
  String get revisionRemoved;

  /// No description provided for @revisionDueToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get revisionDueToday;

  /// No description provided for @revisionDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get revisionDueTomorrow;

  /// No description provided for @revisionDueInDays.
  ///
  /// In en, this message translates to:
  /// **'In {days} days'**
  String revisionDueInDays(int days);

  /// No description provided for @revisionOverdueBy.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day overdue} other{{days} days overdue}}'**
  String revisionOverdueBy(int days);

  /// No description provided for @revisionReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Revise'**
  String get revisionReviewTitle;

  /// No description provided for @revisionCardPosition.
  ///
  /// In en, this message translates to:
  /// **'Card {position} of {total}'**
  String revisionCardPosition(int position, int total);

  /// No description provided for @revisionShowAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show answer'**
  String get revisionShowAnswer;

  /// No description provided for @revisionAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get revisionAnswer;

  /// No description provided for @revisionNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes for this concept. Try to recall what you know about it.'**
  String get revisionNoNotes;

  /// No description provided for @revisionHowWell.
  ///
  /// In en, this message translates to:
  /// **'How well did you remember it?'**
  String get revisionHowWell;

  /// No description provided for @revisionDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You revised 1 card} other{You revised {count} cards}}'**
  String revisionDone(int count);

  /// No description provided for @ratingAgain.
  ///
  /// In en, this message translates to:
  /// **'Forgot'**
  String get ratingAgain;

  /// No description provided for @ratingHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get ratingHard;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// No description provided for @ratingEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get ratingEasy;

  /// No description provided for @cardOriginNotes.
  ///
  /// In en, this message translates to:
  /// **'Your notes'**
  String get cardOriginNotes;

  /// No description provided for @cardOriginPaper.
  ///
  /// In en, this message translates to:
  /// **'From your PDF'**
  String get cardOriginPaper;

  /// No description provided for @cardOriginPaperPage.
  ///
  /// In en, this message translates to:
  /// **'From your PDF · {file}, p. {page}'**
  String cardOriginPaperPage(String file, int page);

  /// No description provided for @cardReasonIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Answered wrong in practice'**
  String get cardReasonIncorrect;

  /// No description provided for @conceptAddToRevision.
  ///
  /// In en, this message translates to:
  /// **'Add to revision'**
  String get conceptAddToRevision;

  /// No description provided for @conceptInRevision.
  ///
  /// In en, this message translates to:
  /// **'In revision'**
  String get conceptInRevision;

  /// No description provided for @revisionAddAll.
  ///
  /// In en, this message translates to:
  /// **'Revise these'**
  String get revisionAddAll;

  /// No description provided for @revisionQuestionsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No new cards added.} =1{1 card added to revision.} other{{count} cards added to revision.}}'**
  String revisionQuestionsAdded(int count);

  /// No description provided for @revisionQuestionsAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} already in revision.'**
  String revisionQuestionsAlreadyAdded(int count);

  /// No description provided for @revisionQuestionsNotEligible.
  ///
  /// In en, this message translates to:
  /// **'{count} not added: only reviewed questions with an answer and no figure can be revised.'**
  String revisionQuestionsNotEligible(int count);

  /// No description provided for @homeRevisionNoneToday.
  ///
  /// In en, this message translates to:
  /// **'No revision due today. Next: {when}.'**
  String homeRevisionNoneToday(String when);

  /// No description provided for @homeRevisionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No flashcards yet. Add concepts or questions to revision.'**
  String get homeRevisionEmpty;

  /// No description provided for @reminderSwitch.
  ///
  /// In en, this message translates to:
  /// **'Daily study reminder'**
  String get reminderSwitch;

  /// No description provided for @reminderOn.
  ///
  /// In en, this message translates to:
  /// **'Every day at {time}'**
  String reminderOn(String time);

  /// No description provided for @reminderOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reminderOff;

  /// No description provided for @reminderNeedsTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a reminder time to switch it on.'**
  String get reminderNeedsTime;

  /// No description provided for @reminderBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for PrepLoop. Allow them in system settings to get reminders.'**
  String get reminderBlocked;

  /// No description provided for @reminderFailed.
  ///
  /// In en, this message translates to:
  /// **'The reminder could not be set.'**
  String get reminderFailed;

  /// No description provided for @reminderUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Reminders work in the Android and iOS apps.'**
  String get reminderUnsupported;

  /// No description provided for @reminderOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open notification settings'**
  String get reminderOpenSettings;

  /// No description provided for @reminderNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to study'**
  String get reminderNotificationTitle;

  /// No description provided for @reminderNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Open PrepLoop to see what to revise today.'**
  String get reminderNotificationBody;

  /// No description provided for @reminderChannelName.
  ///
  /// In en, this message translates to:
  /// **'Study reminders'**
  String get reminderChannelName;

  /// No description provided for @topicAccuracy.
  ///
  /// In en, this message translates to:
  /// **'{percent} correct over {answered} answers'**
  String topicAccuracy(String percent, int answered);

  /// No description provided for @topicForgotten.
  ///
  /// In en, this message translates to:
  /// **'forgotten in {forgot} of {reviews} flashcard reviews'**
  String topicForgotten(int forgot, int reviews);

  /// No description provided for @planRevisionTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Revise 1 flashcard} other{Revise {count} flashcards}}'**
  String planRevisionTitle(int count);

  /// No description provided for @planWeakTopicTitle.
  ///
  /// In en, this message translates to:
  /// **'Practise {topic}'**
  String planWeakTopicTitle(String topic);

  /// No description provided for @planMixedTitle.
  ///
  /// In en, this message translates to:
  /// **'Practise mixed questions'**
  String get planMixedTitle;

  /// No description provided for @planMockTitle.
  ///
  /// In en, this message translates to:
  /// **'Take a mock test: {name}'**
  String planMockTitle(String name);

  /// No description provided for @planMinutes.
  ///
  /// In en, this message translates to:
  /// **'about {minutes} min'**
  String planMinutes(int minutes);

  /// No description provided for @planStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get planStart;

  /// No description provided for @reasonCardsDue.
  ///
  /// In en, this message translates to:
  /// **'{due} due today'**
  String reasonCardsDue(int due);

  /// No description provided for @reasonCardsDueOverdue.
  ///
  /// In en, this message translates to:
  /// **'{due} due today, {overdue} overdue'**
  String reasonCardsDueOverdue(int due, int overdue);

  /// No description provided for @reasonBelowThreshold.
  ///
  /// In en, this message translates to:
  /// **'below {threshold}'**
  String reasonBelowThreshold(String threshold);

  /// No description provided for @reasonNoPracticeData.
  ///
  /// In en, this message translates to:
  /// **'No practice answers yet; practising shows which topics need work'**
  String get reasonNoPracticeData;

  /// No description provided for @reasonNoWeakTopic.
  ///
  /// In en, this message translates to:
  /// **'No weak topic found yet (a topic is judged after {min} answers)'**
  String reasonNoWeakTopic(int min);

  /// No description provided for @reasonMockNever.
  ///
  /// In en, this message translates to:
  /// **'You have not taken a mock test yet.'**
  String get reasonMockNever;

  /// No description provided for @reasonMockSince.
  ///
  /// In en, this message translates to:
  /// **'Last mock test {days} days ago.'**
  String reasonMockSince(int days);

  /// No description provided for @reasonExamIn.
  ///
  /// In en, this message translates to:
  /// **'Exam in {days} days.'**
  String reasonExamIn(int days);

  /// No description provided for @planGoal.
  ///
  /// In en, this message translates to:
  /// **'About {planned} min planned for your {goal}-minute daily goal.'**
  String planGoal(int planned, int goal);

  /// No description provided for @planNoGoal.
  ///
  /// In en, this message translates to:
  /// **'Set a daily study goal in Profile to fit the plan to your time.'**
  String get planNoGoal;

  /// No description provided for @planOffline.
  ///
  /// In en, this message translates to:
  /// **'Practice suggestions need a connection, so only revision is planned.'**
  String get planOffline;

  /// No description provided for @planEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned for today: no flashcards are due.'**
  String get planEmpty;

  /// No description provided for @homeWeakOffline.
  ///
  /// In en, this message translates to:
  /// **'Practice statistics need a connection.'**
  String get homeWeakOffline;

  /// No description provided for @homeWeakNone.
  ///
  /// In en, this message translates to:
  /// **'No weak topics: every topic with enough data is at {threshold} correct or better.'**
  String homeWeakNone(String threshold);

  /// No description provided for @homeWeakNeedMore.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet. A topic is judged after {answers} practice answers or {reviews} flashcard reviews.'**
  String homeWeakNeedMore(int answers, int reviews);

  /// No description provided for @homeSeeProgress.
  ///
  /// In en, this message translates to:
  /// **'See progress'**
  String get homeSeeProgress;

  /// No description provided for @progressSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice overview'**
  String get progressSummaryTitle;

  /// No description provided for @progressAnswered.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 practice answer} other{{count} practice answers}}'**
  String progressAnswered(int count);

  /// No description provided for @progressAccuracy.
  ///
  /// In en, this message translates to:
  /// **'{percent} correct'**
  String progressAccuracy(String percent);

  /// No description provided for @progressSessions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String progressSessions(int count);

  /// No description provided for @progressDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Questions answered, last {days} days'**
  String progressDailyTitle(int days);

  /// No description provided for @progressChartSummary.
  ///
  /// In en, this message translates to:
  /// **'{total} in the last {days} days'**
  String progressChartSummary(int total, int days);

  /// No description provided for @progressSubjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'By subject'**
  String get progressSubjectsTitle;

  /// No description provided for @progressNoAnswers.
  ///
  /// In en, this message translates to:
  /// **'No practice answers yet.'**
  String get progressNoAnswers;

  /// No description provided for @progressSubjectRow.
  ///
  /// In en, this message translates to:
  /// **'{percent} correct over {answered} answers'**
  String progressSubjectRow(String percent, int answered);

  /// No description provided for @progressNotEnough.
  ///
  /// In en, this message translates to:
  /// **'Not enough answers yet ({answered} of {min})'**
  String progressNotEnough(int answered, int min);

  /// No description provided for @progressMocksTitle.
  ///
  /// In en, this message translates to:
  /// **'Mock tests'**
  String get progressMocksTitle;

  /// No description provided for @progressMocksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No mock tests taken yet.'**
  String get progressMocksEmpty;

  /// No description provided for @progressMockScore.
  ///
  /// In en, this message translates to:
  /// **'{score} / {max}'**
  String progressMockScore(String score, String max);

  /// No description provided for @progressMockTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Submitted when time ran out'**
  String get progressMockTimeUp;

  /// No description provided for @progressTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get progressTopicsTitle;

  /// No description provided for @progressTopicsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Topic results appear once practised questions or flashcards have a topic.'**
  String get progressTopicsEmpty;

  /// No description provided for @progressWeakBadge.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get progressWeakBadge;

  /// No description provided for @progressTrendImproving.
  ///
  /// In en, this message translates to:
  /// **'Improving'**
  String get progressTrendImproving;

  /// No description provided for @progressTrendSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get progressTrendSteady;

  /// No description provided for @progressTrendDeclining.
  ///
  /// In en, this message translates to:
  /// **'Declining'**
  String get progressTrendDeclining;

  /// No description provided for @progressNeedsData.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more topic needs more data before it is judged.} other{{count} more topics need more data before they are judged.}}'**
  String progressNeedsData(int count);

  /// No description provided for @progressRevisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Flashcard recall'**
  String get progressRevisionTitle;

  /// No description provided for @progressRevisionSummary.
  ///
  /// In en, this message translates to:
  /// **'{reviews} reviews, forgotten {forgot} times in the last {days} days'**
  String progressRevisionSummary(int reviews, int forgot, int days);

  /// No description provided for @progressRevisionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No flashcard reviews in the last {days} days.'**
  String progressRevisionEmpty(int days);

  /// No description provided for @progressOffline.
  ///
  /// In en, this message translates to:
  /// **'Practice statistics could not be loaded. Check your connection.'**
  String get progressOffline;

  /// No description provided for @progressRules.
  ///
  /// In en, this message translates to:
  /// **'A topic is weak when it is below {accuracy} correct after at least {answers} answers, or forgotten in {forget} or more of at least {reviews} flashcard reviews. Trends compare the last {recentDays} days with earlier answers.'**
  String progressRules(String accuracy, int answers, String forget, int reviews, int recentDays);

  /// No description provided for @aiAssistTitle.
  ///
  /// In en, this message translates to:
  /// **'AI assistance'**
  String get aiAssistTitle;

  /// No description provided for @aiReviewNote.
  ///
  /// In en, this message translates to:
  /// **'AI output is a draft. It is labelled \"AI-generated\" and must be reviewed before learners see it.'**
  String get aiReviewNote;

  /// No description provided for @aiProvenance.
  ///
  /// In en, this message translates to:
  /// **'AI-generated by {model} (prompt {version})'**
  String aiProvenance(String model, String version);

  /// No description provided for @aiBasedOnQuestion.
  ///
  /// In en, this message translates to:
  /// **'based on a reviewed question'**
  String get aiBasedOnQuestion;

  /// No description provided for @aiDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'AI-generated draft, not reviewed'**
  String get aiDraftLabel;

  /// No description provided for @aiExplanationApproved.
  ///
  /// In en, this message translates to:
  /// **'AI-generated explanation (approved)'**
  String get aiExplanationApproved;

  /// No description provided for @aiExplanationLabel.
  ///
  /// In en, this message translates to:
  /// **'AI-generated explanation'**
  String get aiExplanationLabel;

  /// No description provided for @aiUnsure.
  ///
  /// In en, this message translates to:
  /// **'The AI was not sure the given answer is right. Check the answer before approving.'**
  String get aiUnsure;

  /// No description provided for @aiApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get aiApprove;

  /// No description provided for @aiEditApprove.
  ///
  /// In en, this message translates to:
  /// **'Edit and approve'**
  String get aiEditApprove;

  /// No description provided for @aiDraftExplanation.
  ///
  /// In en, this message translates to:
  /// **'Draft an explanation with AI'**
  String get aiDraftExplanation;

  /// No description provided for @aiSuggestTopic.
  ///
  /// In en, this message translates to:
  /// **'Suggest a topic with AI'**
  String get aiSuggestTopic;

  /// No description provided for @aiNoTopic.
  ///
  /// In en, this message translates to:
  /// **'The AI found no matching topic. Choose one yourself.'**
  String get aiNoTopic;

  /// No description provided for @aiGenerateSimilar.
  ///
  /// In en, this message translates to:
  /// **'Generate similar practice questions'**
  String get aiGenerateSimilar;

  /// No description provided for @aiApproveFirst.
  ///
  /// In en, this message translates to:
  /// **'Approve this question first; AI only works from reviewed questions with an answer.'**
  String get aiApproveFirst;

  /// No description provided for @aiGenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate practice questions'**
  String get aiGenerateTitle;

  /// No description provided for @aiGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get aiGenerate;

  /// No description provided for @aiGenerateFromQuestionNotice.
  ///
  /// In en, this message translates to:
  /// **'New questions are written by AI on the same topic. They are saved as AI-generated and unreviewed, and never count as previous-year questions.'**
  String get aiGenerateFromQuestionNotice;

  /// No description provided for @aiGenerateFromConcept.
  ///
  /// In en, this message translates to:
  /// **'Practice questions from my notes (AI)'**
  String get aiGenerateFromConcept;

  /// No description provided for @aiConceptNotice.
  ///
  /// In en, this message translates to:
  /// **'The concept title and your notes are sent to the AI service to write questions. The questions are saved as AI-generated and need review in the question bank before practice.'**
  String get aiConceptNotice;

  /// No description provided for @aiGenerated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No usable questions were generated.} =1{1 AI question added to the question bank for review.} other{{count} AI questions added to the question bank for review.}}'**
  String aiGenerated(int count);

  /// No description provided for @aiGeneratedRejected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 was rejected by the checks.} other{{count} were rejected by the checks.}}'**
  String aiGeneratedRejected(int count);

  /// No description provided for @aiErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline. AI assistance needs a connection.'**
  String get aiErrorOffline;

  /// No description provided for @aiErrorDisabled.
  ///
  /// In en, this message translates to:
  /// **'AI assistance is not set up on the server.'**
  String get aiErrorDisabled;

  /// No description provided for @aiErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The AI service is not available right now. Please try again in a moment.'**
  String get aiErrorUnavailable;

  /// No description provided for @aiErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many AI requests. Please try again later.'**
  String get aiErrorRateLimited;

  /// No description provided for @aiErrorNotEligible.
  ///
  /// In en, this message translates to:
  /// **'AI can only work from reviewed questions with an answer and no figure.'**
  String get aiErrorNotEligible;

  /// No description provided for @aiErrorExplanationExists.
  ///
  /// In en, this message translates to:
  /// **'This question already has an explanation.'**
  String get aiErrorExplanationExists;

  /// No description provided for @aiErrorTopicSet.
  ///
  /// In en, this message translates to:
  /// **'This question already has a topic.'**
  String get aiErrorTopicSet;

  /// No description provided for @aiErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get aiErrorGeneric;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportTitle;

  /// No description provided for @reportNote.
  ///
  /// In en, this message translates to:
  /// **'What is wrong? (optional)'**
  String get reportNote;

  /// No description provided for @reportSend.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSend;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks. The question goes back for review.'**
  String get reportSent;

  /// No description provided for @reportWrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'The answer is wrong'**
  String get reportWrongAnswer;

  /// No description provided for @reportUnclear.
  ///
  /// In en, this message translates to:
  /// **'The question is unclear'**
  String get reportUnclear;

  /// No description provided for @reportIncorrectContent.
  ///
  /// In en, this message translates to:
  /// **'The content is incorrect'**
  String get reportIncorrectContent;

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportOther;

  /// No description provided for @practiceIncludeAi.
  ///
  /// In en, this message translates to:
  /// **'Include AI-generated questions'**
  String get practiceIncludeAi;

  /// No description provided for @practiceIncludeAiHint.
  ///
  /// In en, this message translates to:
  /// **'They are labelled \"AI-generated\" and are not previous-year questions. Mock tests never use them.'**
  String get practiceIncludeAiHint;

  /// No description provided for @topicSuggestedByAi.
  ///
  /// In en, this message translates to:
  /// **'Suggested by AI. Confirm or change it.'**
  String get topicSuggestedByAi;

  /// No description provided for @issueLearnerReport.
  ///
  /// In en, this message translates to:
  /// **'Reported by a learner'**
  String get issueLearnerReport;

  /// No description provided for @issueAiLanguageReview.
  ///
  /// In en, this message translates to:
  /// **'AI-written Hindi: check the language'**
  String get issueAiLanguageReview;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your study account.'**
  String get authSignInTitle;

  /// No description provided for @authCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your study account.'**
  String get authCreateTitle;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'You were signed out. Please sign in again.'**
  String get authSessionExpired;

  /// No description provided for @authName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get authName;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEmailInvalid;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters'**
  String authPasswordHint(int min);

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get authPasswordRequired;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreate;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get authNoAccount;

  /// No description provided for @authAgeConfirm.
  ///
  /// In en, this message translates to:
  /// **'I am {age} or older'**
  String authAgeConfirm(int age);

  /// No description provided for @authAgeRequired.
  ///
  /// In en, this message translates to:
  /// **'You must be {age} or older to create an account.'**
  String authAgeRequired(int age);

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authHaveAccount;

  /// No description provided for @authSyncNote.
  ///
  /// In en, this message translates to:
  /// **'Your concepts, flashcards and study plan are saved to your account, so you can continue on another device. Imported papers and practice results are kept on the server for your account only.'**
  String get authSyncNote;

  /// No description provided for @authErrorCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is not correct.'**
  String get authErrorCredentials;

  /// No description provided for @authErrorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in instead.'**
  String get authErrorEmailTaken;

  /// No description provided for @authErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get authErrorRateLimited;

  /// No description provided for @authErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the email and password and try again.'**
  String get authErrorInvalid;

  /// No description provided for @authErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Connect to the internet to continue.'**
  String get authErrorOffline;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncInProgress;

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get syncNever;

  /// No description provided for @syncDone.
  ///
  /// In en, this message translates to:
  /// **'Synced {when}'**
  String syncDone(String when);

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync} other{{count} changes waiting to sync}}'**
  String syncPending(int count);

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Offline. Changes will sync when you are back online.} other{Offline. {count} changes will sync when you are back online.}}'**
  String syncOffline(int count);

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sync. It will be retried.'**
  String get syncFailed;

  /// No description provided for @accountExport.
  ///
  /// In en, this message translates to:
  /// **'Copy my data'**
  String get accountExport;

  /// No description provided for @accountExported.
  ///
  /// In en, this message translates to:
  /// **'Your data was copied as JSON. Paste it into a file to keep it.'**
  String get accountExported;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get accountSignOutTitle;

  /// No description provided for @accountSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Your study data will be removed from this device. It stays in your account.'**
  String get accountSignOutMessage;

  /// No description provided for @accountSignOutUnsynced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change has not synced yet and will be lost if you sign out now.} other{{count} changes have not synced yet and will be lost if you sign out now.}}'**
  String accountSignOutUnsynced(int count);

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and everything in it: concepts, flashcards, imported papers, questions and practice history. It cannot be undone. Enter your password to confirm.'**
  String get accountDeleteMessage;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get accountDeleteConfirm;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authErrorCode.
  ///
  /// In en, this message translates to:
  /// **'That code is not valid or has expired. Request a new one.'**
  String get authErrorCode;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetTitle;

  /// No description provided for @resetIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email. We will send you a 6-digit code.'**
  String get resetIntro;

  /// No description provided for @resetCodeSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, we sent a 6-digit code. It expires in 15 minutes.'**
  String get resetCodeSent;

  /// No description provided for @resetCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get resetCode;

  /// No description provided for @resetCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from the email.'**
  String get resetCodeInvalid;

  /// No description provided for @resetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetNewPassword;

  /// No description provided for @resetSend.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get resetSend;

  /// No description provided for @resetSave.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get resetSave;

  /// No description provided for @resetResend.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get resetResend;

  /// No description provided for @resetDone.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Sign in with your new password.'**
  String get resetDone;

  /// No description provided for @legalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legalPrivacy;

  /// No description provided for @legalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get legalTerms;

  /// No description provided for @legalLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the document.'**
  String get legalLoadError;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get verifyTitle;

  /// No description provided for @verifyMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirming your email lets you reset your password if you forget it.'**
  String get verifyMessage;

  /// No description provided for @verifyAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get verifyAction;

  /// No description provided for @verifyCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to your email.'**
  String get verifyCodeSent;

  /// No description provided for @verifyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get verifyConfirm;

  /// No description provided for @verifyDone.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed.'**
  String get verifyDone;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @figureLabel.
  ///
  /// In en, this message translates to:
  /// **'Figure from the paper (page {page})'**
  String figureLabel(int page);

  /// No description provided for @figureOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Option figure from the paper (page {page})'**
  String figureOptionLabel(int page);

  /// No description provided for @figureOriginalLabel.
  ///
  /// In en, this message translates to:
  /// **'Question as printed in the paper (page {page})'**
  String figureOriginalLabel(int page);

  /// No description provided for @figureLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the figure.'**
  String get figureLoadError;

  /// No description provided for @figuresFromPaper.
  ///
  /// In en, this message translates to:
  /// **'Figures from the paper (shown as printed)'**
  String get figuresFromPaper;

  /// No description provided for @issueUnreadableText.
  ///
  /// In en, this message translates to:
  /// **'Some characters couldn\'t be read'**
  String get issueUnreadableText;

  /// No description provided for @issueFiguresNotExtracted.
  ///
  /// In en, this message translates to:
  /// **'Some figures couldn\'t be extracted'**
  String get issueFiguresNotExtracted;

  /// No description provided for @reviewSummaryFigures.
  ///
  /// In en, this message translates to:
  /// **'{count} with figures'**
  String reviewSummaryFigures(int count);

  /// No description provided for @reviewSummaryUnreadable.
  ///
  /// In en, this message translates to:
  /// **'{count} with unreadable text'**
  String reviewSummaryUnreadable(int count);

  /// No description provided for @topicsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Subjects and topics'**
  String get topicsCardTitle;

  /// No description provided for @topicsSummary.
  ///
  /// In en, this message translates to:
  /// **'{suggested} suggested · {unassigned} without a topic'**
  String topicsSummary(int suggested, int unassigned);

  /// No description provided for @topicsAcceptAll.
  ///
  /// In en, this message translates to:
  /// **'Accept all suggestions ({count})'**
  String topicsAcceptAll(int count);

  /// No description provided for @topicsAcceptConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept all suggestions?'**
  String get topicsAcceptConfirmTitle;

  /// No description provided for @topicsAcceptConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Every suggested topic and question type of this paper becomes confirmed. Rejected questions are skipped, and you can still change any of them afterwards.'**
  String get topicsAcceptConfirmBody;

  /// No description provided for @topicsAcceptAction.
  ///
  /// In en, this message translates to:
  /// **'Accept all'**
  String get topicsAcceptAction;

  /// No description provided for @topicsAccepted.
  ///
  /// In en, this message translates to:
  /// **'{count} topics accepted.'**
  String topicsAccepted(int count);

  /// No description provided for @topicsAiSuggest.
  ///
  /// In en, this message translates to:
  /// **'Suggest topics with AI ({count} questions)'**
  String topicsAiSuggest(int count);

  /// No description provided for @topicsAiNotice.
  ///
  /// In en, this message translates to:
  /// **'The text of these questions is sent to the AI service. Its suggestions are labelled AI and need your confirmation.'**
  String get topicsAiNotice;

  /// No description provided for @topicsAiConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send to AI'**
  String get topicsAiConfirm;

  /// No description provided for @topicsAiRunning.
  ///
  /// In en, this message translates to:
  /// **'Asking the AI… {remaining} left'**
  String topicsAiRunning(int remaining);

  /// No description provided for @topicsAiDone.
  ///
  /// In en, this message translates to:
  /// **'AI suggested {suggested} topics. {noMatch} questions had no match.'**
  String topicsAiDone(int suggested, int noMatch);

  /// No description provided for @topicsRulesNote.
  ///
  /// In en, this message translates to:
  /// **'Suggestions come from keyword rules (and the AI if you ask). Each one shows why it was made.'**
  String get topicsRulesNote;

  /// No description provided for @topicSuggestionReason.
  ///
  /// In en, this message translates to:
  /// **'Why: {reason}'**
  String topicSuggestionReason(String reason);

  /// No description provided for @repeatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Repeated models'**
  String get repeatsTitle;

  /// No description provided for @repeatsHubMessage.
  ///
  /// In en, this message translates to:
  /// **'See which topics and question types came up most often in the papers you imported, so you don\'t miss them.'**
  String get repeatsHubMessage;

  /// No description provided for @repeatsOpen.
  ///
  /// In en, this message translates to:
  /// **'See repeated models'**
  String get repeatsOpen;

  /// No description provided for @repeatsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No papers yet'**
  String get repeatsEmptyTitle;

  /// No description provided for @repeatsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Import previous papers. PrepLoop counts how often each topic and question type appears in them.'**
  String get repeatsEmptyMessage;

  /// No description provided for @repeatsImportPapers.
  ///
  /// In en, this message translates to:
  /// **'Import papers'**
  String get repeatsImportPapers;

  /// No description provided for @repeatsNeedsReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review topics to count them'**
  String get repeatsNeedsReviewTitle;

  /// No description provided for @repeatsNeedsReviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Topics are only suggestions so far. Open a paper and accept its suggestions (or approve questions) to count them here.'**
  String get repeatsNeedsReviewMessage;

  /// No description provided for @repeatsSimilarTitle.
  ///
  /// In en, this message translates to:
  /// **'Worded alike in different papers'**
  String get repeatsSimilarTitle;

  /// No description provided for @repeatsSimilarNote.
  ///
  /// In en, this message translates to:
  /// **'Found by comparing wording, with numbers ignored. A hint, not a reviewed classification: check before relying on it.'**
  String get repeatsSimilarNote;

  /// No description provided for @repeatsBasis.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} of your papers'**
  String repeatsBasis(int count);

  /// No description provided for @repeatsBasisYears.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} of your papers ({first}–{last})'**
  String repeatsBasisYears(int count, int first, int last);

  /// No description provided for @repeatsUndated.
  ///
  /// In en, this message translates to:
  /// **'{count} papers have no confirmed date, so they aren\'t in the year counts. Confirm dates on each paper\'s review screen.'**
  String repeatsUndated(int count);

  /// No description provided for @repeatsReviewedNote.
  ///
  /// In en, this message translates to:
  /// **'Counts use questions whose topic or type you have confirmed. Unconfirmed suggestions are shown separately.'**
  String get repeatsReviewedNote;

  /// No description provided for @repeatsMostPapersRule.
  ///
  /// In en, this message translates to:
  /// **'“Seen in most papers” means in at least {percent}% of your papers, once you have {min} or more.'**
  String repeatsMostPapersRule(int percent, int min);

  /// No description provided for @repeatsInPapers.
  ///
  /// In en, this message translates to:
  /// **'In {papers} of {total} papers · {questions} questions'**
  String repeatsInPapers(int papers, int total, int questions);

  /// No description provided for @repeatsUnreviewed.
  ///
  /// In en, this message translates to:
  /// **'+{count} not yet reviewed'**
  String repeatsUnreviewed(int count);

  /// No description provided for @repeatsSeenInMost.
  ///
  /// In en, this message translates to:
  /// **'Seen in most papers'**
  String get repeatsSeenInMost;

  /// No description provided for @repeatsByYear.
  ///
  /// In en, this message translates to:
  /// **'By year: {years}'**
  String repeatsByYear(String years);

  /// No description provided for @repeatsPractise.
  ///
  /// In en, this message translates to:
  /// **'Practise'**
  String get repeatsPractise;

  /// No description provided for @repeatsPractiseTopic.
  ///
  /// In en, this message translates to:
  /// **'Practise this topic'**
  String get repeatsPractiseTopic;

  /// No description provided for @repeatsWithoutPattern.
  ///
  /// In en, this message translates to:
  /// **'{count} other questions in this topic (no named type)'**
  String repeatsWithoutPattern(int count);

  /// No description provided for @repeatsSimilarUnclassified.
  ///
  /// In en, this message translates to:
  /// **'No topic yet'**
  String get repeatsSimilarUnclassified;

  /// No description provided for @repeatsSimilarPapers.
  ///
  /// In en, this message translates to:
  /// **'In {papers} of {total} papers'**
  String repeatsSimilarPapers(int papers, int total);

  /// No description provided for @fieldPattern.
  ///
  /// In en, this message translates to:
  /// **'Question type'**
  String get fieldPattern;

  /// No description provided for @patternNone.
  ///
  /// In en, this message translates to:
  /// **'No type'**
  String get patternNone;

  /// No description provided for @patternSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested type. Approving the question confirms it.'**
  String get patternSuggested;

  /// No description provided for @patternsSuggestedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} question types suggested'**
  String patternsSuggestedCount(int count);

  /// No description provided for @topicsAcceptedWithPatterns.
  ///
  /// In en, this message translates to:
  /// **'{topics} topics and {patterns} question types accepted.'**
  String topicsAcceptedWithPatterns(int topics, int patterns);

  /// No description provided for @paperDateTitle.
  ///
  /// In en, this message translates to:
  /// **'When was this paper held?'**
  String get paperDateTitle;

  /// No description provided for @paperDateMissing.
  ///
  /// In en, this message translates to:
  /// **'Not known yet'**
  String get paperDateMissing;

  /// No description provided for @paperDateUnknownConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Date not known'**
  String get paperDateUnknownConfirmed;

  /// No description provided for @paperDateConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed. Used in year counts.'**
  String get paperDateConfirmed;

  /// No description provided for @paperDateSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested: confirm it to use it in year counts'**
  String get paperDateSuggested;

  /// No description provided for @paperDateWhy.
  ///
  /// In en, this message translates to:
  /// **'Set the date to see which years a topic appeared in.'**
  String get paperDateWhy;

  /// No description provided for @paperDateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get paperDateConfirm;

  /// No description provided for @paperDateEdit.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get paperDateEdit;

  /// No description provided for @paperDateSet.
  ///
  /// In en, this message translates to:
  /// **'Set date'**
  String get paperDateSet;

  /// No description provided for @paperDateSaved.
  ///
  /// In en, this message translates to:
  /// **'Paper date saved.'**
  String get paperDateSaved;

  /// No description provided for @paperShift.
  ///
  /// In en, this message translates to:
  /// **'Shift {shift}'**
  String paperShift(int shift);

  /// No description provided for @paperYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get paperYear;

  /// No description provided for @paperShiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get paperShiftLabel;

  /// No description provided for @paperDateNotKnown.
  ///
  /// In en, this message translates to:
  /// **'Not known'**
  String get paperDateNotKnown;

  /// No description provided for @paperDatePickDay.
  ///
  /// In en, this message translates to:
  /// **'Pick the day (optional)'**
  String get paperDatePickDay;

  /// No description provided for @repeatsYourPapers.
  ///
  /// In en, this message translates to:
  /// **'Your papers'**
  String get repeatsYourPapers;

  /// No description provided for @repeatsAllLearners.
  ///
  /// In en, this message translates to:
  /// **'All learners'**
  String get repeatsAllLearners;

  /// No description provided for @radarShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Repeat Radar'**
  String get radarShareTitle;

  /// No description provided for @radarShareSwitch.
  ///
  /// In en, this message translates to:
  /// **'Share my counts with the Repeat Radar'**
  String get radarShareSwitch;

  /// No description provided for @radarShareWhat.
  ///
  /// In en, this message translates to:
  /// **'Only how many questions of each topic and question type your reviewed papers had, with the paper\'s exam date and shift. Never question text, your papers or your account details. Turning this off removes your counts at once.'**
  String get radarShareWhat;

  /// No description provided for @radarShareEligible.
  ///
  /// In en, this message translates to:
  /// **'{count} of your papers can join (they need a confirmed date and shift).'**
  String radarShareEligible(int count);

  /// No description provided for @radarEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Not enough shared data yet'**
  String get radarEmptyTitle;

  /// No description provided for @radarEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'A paper shift appears here once at least {min} learners have reviewed it and their counts agree. Turn on sharing below and confirm your papers\' date and shift to help.'**
  String radarEmptyMessage(int min);

  /// No description provided for @radarBasis.
  ///
  /// In en, this message translates to:
  /// **'Based on {shifts} exam shifts reviewed by learners'**
  String radarBasis(int shifts);

  /// No description provided for @radarBasisYears.
  ///
  /// In en, this message translates to:
  /// **'Based on {shifts} exam shifts reviewed by learners ({first}–{last})'**
  String radarBasisYears(int shifts, int first, int last);

  /// No description provided for @radarHowCounted.
  ///
  /// In en, this message translates to:
  /// **'Each shift counts only when at least {min} learners reviewed it, and a number is shown only when their counts agree. One person can\'t change these numbers.'**
  String radarHowCounted(int min);

  /// No description provided for @radarWithheld.
  ///
  /// In en, this message translates to:
  /// **'{count} counts are hidden because learners\' numbers didn\'t agree.'**
  String radarWithheld(int count);

  /// No description provided for @radarMostRule.
  ///
  /// In en, this message translates to:
  /// **'“In most shifts” means in at least {percent}% of the shifts, once there are {min} or more.'**
  String radarMostRule(int percent, int min);

  /// No description provided for @radarInShifts.
  ///
  /// In en, this message translates to:
  /// **'In {shifts} of {total} shifts · {questions} questions'**
  String radarInShifts(int shifts, int total, int questions);

  /// No description provided for @radarSeenInMost.
  ///
  /// In en, this message translates to:
  /// **'In most shifts'**
  String get radarSeenInMost;

  /// No description provided for @radarShiftsByYear.
  ///
  /// In en, this message translates to:
  /// **'Shifts by year: {years}'**
  String radarShiftsByYear(String years);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @examsMore.
  ///
  /// In en, this message translates to:
  /// **'More exams'**
  String get examsMore;

  /// No description provided for @examsOwnGroup.
  ///
  /// In en, this message translates to:
  /// **'My own exams'**
  String get examsOwnGroup;

  /// No description provided for @examsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search exams'**
  String get examsSearch;

  /// No description provided for @examsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No exam matches. Create your own below.'**
  String get examsNoMatch;

  /// No description provided for @examsCreateOwn.
  ///
  /// In en, this message translates to:
  /// **'Create my own exam'**
  String get examsCreateOwn;

  /// No description provided for @examsCreateOwnHint.
  ///
  /// In en, this message translates to:
  /// **'For any exam not in the list. Only you see it.'**
  String get examsCreateOwnHint;

  /// No description provided for @examsDone.
  ///
  /// In en, this message translates to:
  /// **'Done ({count} chosen)'**
  String examsDone(int count);

  /// No description provided for @examsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename exam'**
  String get examsRename;

  /// No description provided for @examsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Exam name'**
  String get examsNameLabel;

  /// No description provided for @examsNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Rajasthan Patwari 2026'**
  String get examsNameHint;

  /// No description provided for @examsInUse.
  ///
  /// In en, this message translates to:
  /// **'Papers, questions or notes still use this exam. Delete them first.'**
  String get examsInUse;

  /// No description provided for @examsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String examsDeleteTitle(String name);

  /// No description provided for @examsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its topics are deleted too. Exams still used by papers or notes can\'t be deleted.'**
  String get examsDeleteBody;

  /// No description provided for @examsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Exam deleted.'**
  String get examsDeleted;

  /// No description provided for @examsTitle.
  ///
  /// In en, this message translates to:
  /// **'Exams and topics'**
  String get examsTitle;

  /// No description provided for @examsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No exams chosen'**
  String get examsEmptyTitle;

  /// No description provided for @examsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose your exams in the study plan, or create your own.'**
  String get examsEmptyMessage;

  /// No description provided for @examsIntro.
  ///
  /// In en, this message translates to:
  /// **'Each exam has its own subjects and topics. PrepLoop uses them to sort the questions in your papers and to show what repeats.'**
  String get examsIntro;

  /// No description provided for @examsOwnLabel.
  ///
  /// In en, this message translates to:
  /// **'My own exam (only you see it)'**
  String get examsOwnLabel;

  /// No description provided for @examsActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get examsActions;

  /// No description provided for @examsManageTile.
  ///
  /// In en, this message translates to:
  /// **'Exams and topics'**
  String get examsManageTile;

  /// No description provided for @examsManageTileHint.
  ///
  /// In en, this message translates to:
  /// **'Add your own exams, subjects and topics'**
  String get examsManageTileHint;

  /// No description provided for @topicsExists.
  ///
  /// In en, this message translates to:
  /// **'This exam already has that topic.'**
  String get topicsExists;

  /// No description provided for @topicsDraftNeedsPapers.
  ///
  /// In en, this message translates to:
  /// **'Import at least one paper of this exam first.'**
  String get topicsDraftNeedsPapers;

  /// No description provided for @topicsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String topicsDeleteTitle(String name);

  /// No description provided for @topicsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Questions with this topic go back to “no topic”.'**
  String get topicsDeleteBody;

  /// No description provided for @topicsDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft topics with AI?'**
  String get topicsDraftTitle;

  /// No description provided for @topicsDraftNotice.
  ///
  /// In en, this message translates to:
  /// **'Up to 60 questions from your imported papers of this exam are sent to the AI service to propose subjects and topics. Nothing is saved until you choose which to keep.'**
  String get topicsDraftNotice;

  /// No description provided for @topicsDraftEmpty.
  ///
  /// In en, this message translates to:
  /// **'The AI proposed no new topics.'**
  String get topicsDraftEmpty;

  /// No description provided for @topicsDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'{count} topics added.'**
  String topicsDraftSaved(int count);

  /// No description provided for @topicsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'{exam}: topics'**
  String topicsScreenTitle(String exam);

  /// No description provided for @topicsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add topic'**
  String get topicsAdd;

  /// No description provided for @topicsScreenIntro.
  ///
  /// In en, this message translates to:
  /// **'Questions in your papers are matched to these topics by their keywords; you confirm every suggestion. Shared topics come with PrepLoop; your own you can change.'**
  String get topicsScreenIntro;

  /// No description provided for @topicsDraftAction.
  ///
  /// In en, this message translates to:
  /// **'Draft topics from my papers (AI)'**
  String get topicsDraftAction;

  /// No description provided for @topicsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No topics yet'**
  String get topicsEmptyTitle;

  /// No description provided for @topicsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add the subjects and topics of this exam\'s syllabus, e.g. Biology › Cell Biology.'**
  String get topicsEmptyMessage;

  /// No description provided for @topicsOwnLabel.
  ///
  /// In en, this message translates to:
  /// **'Your topic'**
  String get topicsOwnLabel;

  /// No description provided for @topicsSharedLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared topic'**
  String get topicsSharedLabel;

  /// No description provided for @topicsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit topic'**
  String get topicsEdit;

  /// No description provided for @topicsAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add a topic to {subject}'**
  String topicsAddTo(String subject);

  /// No description provided for @topicsSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Biology'**
  String get topicsSubjectHint;

  /// No description provided for @topicsNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Cell Biology'**
  String get topicsNameHint;

  /// No description provided for @topicsKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords (optional)'**
  String get topicsKeywords;

  /// No description provided for @topicsKeywordsHelp.
  ///
  /// In en, this message translates to:
  /// **'Words that appear in this topic\'s questions, separated by commas. Without any, the topic\'s name is used.'**
  String get topicsKeywordsHelp;

  /// No description provided for @topicsDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'AI suggestion from {count} of your questions ({model}). Keep only what fits.'**
  String topicsDraftLabel(int count, String model);

  /// No description provided for @topicsDraftKeep.
  ///
  /// In en, this message translates to:
  /// **'Add {count} topics'**
  String topicsDraftKeep(int count);

  /// No description provided for @issueUnrecognisedAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer isn\'t an option (e.g. typed-in answer)'**
  String get issueUnrecognisedAnswer;

  /// No description provided for @sessionCorrectTypedAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String sessionCorrectTypedAnswer(String answer);

  /// No description provided for @sessionTypedAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get sessionTypedAnswerLabel;

  /// No description provided for @sessionTypedAnswerHelp.
  ///
  /// In en, this message translates to:
  /// **'Type the answer, e.g. 12, 2.5 or 3142.'**
  String get sessionTypedAnswerHelp;

  /// No description provided for @sessionTypedAnswerSave.
  ///
  /// In en, this message translates to:
  /// **'Save answer'**
  String get sessionTypedAnswerSave;

  /// No description provided for @resultYourTypedAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer: {answer}'**
  String resultYourTypedAnswer(String answer);

  /// No description provided for @fieldAnswerType.
  ///
  /// In en, this message translates to:
  /// **'Answer type'**
  String get fieldAnswerType;

  /// No description provided for @answerTypeChoice.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get answerTypeChoice;

  /// No description provided for @answerTypeTyped.
  ///
  /// In en, this message translates to:
  /// **'Typed answer'**
  String get answerTypeTyped;

  /// No description provided for @fieldTypedAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct typed answer'**
  String get fieldTypedAnswer;

  /// No description provided for @fieldTypedAnswerHelp.
  ///
  /// In en, this message translates to:
  /// **'Numbers match by value (2.5 = 2.50, never rounded); other answers must match exactly, ignoring spaces and case.'**
  String get fieldTypedAnswerHelp;

  /// No description provided for @sharedBankSource.
  ///
  /// In en, this message translates to:
  /// **'Shared bank · {source}'**
  String sharedBankSource(String source);

  /// No description provided for @sharedBankReadOnly.
  ///
  /// In en, this message translates to:
  /// **'From the shared bank (read-only), shared by the PrepLoop team with permission'**
  String get sharedBankReadOnly;

  /// No description provided for @questionExplanationTitle.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get questionExplanationTitle;

  /// No description provided for @practiceIncludeShared.
  ///
  /// In en, this message translates to:
  /// **'Include the shared bank'**
  String get practiceIncludeShared;

  /// No description provided for @practiceIncludeSharedHint.
  ///
  /// In en, this message translates to:
  /// **'Verified questions from papers the PrepLoop team shared (labelled)'**
  String get practiceIncludeSharedHint;

  /// No description provided for @repeatsSharedBank.
  ///
  /// In en, this message translates to:
  /// **'Shared bank'**
  String get repeatsSharedBank;

  /// No description provided for @repeatsSharedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No shared papers yet'**
  String get repeatsSharedEmptyTitle;

  /// No description provided for @repeatsSharedEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Papers the PrepLoop team shares, with permission to share them, will appear here.'**
  String get repeatsSharedEmptyMessage;

  /// No description provided for @repeatsSmallSample.
  ///
  /// In en, this message translates to:
  /// **'Small sample: {papers} papers. Below {min} papers, a topic seen 2 or 3 times can be chance.'**
  String repeatsSmallSample(int papers, int min);

  /// No description provided for @reviewVerifyClean.
  ///
  /// In en, this message translates to:
  /// **'Verify all clean questions'**
  String get reviewVerifyClean;

  /// No description provided for @reviewVerifyCleanTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify clean questions?'**
  String get reviewVerifyCleanTitle;

  /// No description provided for @reviewVerifyCleanBody.
  ///
  /// In en, this message translates to:
  /// **'Questions with an answer and no open issues are marked verified. Questions that need a look stay for review. You can still edit any question later.'**
  String get reviewVerifyCleanBody;

  /// No description provided for @reviewVerifyCleanDone.
  ///
  /// In en, this message translates to:
  /// **'{verified} verified · {left} still need review'**
  String reviewVerifyCleanDone(int verified, int left);

  /// No description provided for @repeatsBasisShared.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} shared papers'**
  String repeatsBasisShared(int count);

  /// No description provided for @repeatsBasisSharedYears.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} shared papers ({first}–{last})'**
  String repeatsBasisSharedYears(int count, int first, int last);

  /// No description provided for @offlineSessionNote.
  ///
  /// In en, this message translates to:
  /// **'Offline practice: answers are checked on this device and uploaded when you\'re back online.'**
  String get offlineSessionNote;

  /// No description provided for @offlineMarkingNote.
  ///
  /// In en, this message translates to:
  /// **'Marked on this device: 1 point per correct answer. The server checks it again when it\'s uploaded.'**
  String get offlineMarkingNote;

  /// No description provided for @offlineReady.
  ///
  /// In en, this message translates to:
  /// **'{count} questions saved for offline practice'**
  String offlineReady(int count);

  /// No description provided for @offlineToUpload.
  ///
  /// In en, this message translates to:
  /// **'{count} offline sessions waiting to upload'**
  String offlineToUpload(int count);

  /// No description provided for @issueOptionLabelUnclear.
  ///
  /// In en, this message translates to:
  /// **'Option number unclear in the scan (check the order)'**
  String get issueOptionLabelUnclear;

  /// No description provided for @examSwitcherChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose exam'**
  String get examSwitcherChoose;

  /// No description provided for @examSwitcherTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch exam'**
  String get examSwitcherTooltip;

  /// No description provided for @examSwitcherCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current exam: {exam}'**
  String examSwitcherCurrent(String exam);

  /// No description provided for @examSwitcherTitle.
  ///
  /// In en, this message translates to:
  /// **'Which exam?'**
  String get examSwitcherTitle;

  /// No description provided for @examSwitcherHint.
  ///
  /// In en, this message translates to:
  /// **'Papers, questions, practice and repeated models show only the exam you choose.'**
  String get examSwitcherHint;

  /// No description provided for @examSwitcherManage.
  ///
  /// In en, this message translates to:
  /// **'Add or change exams'**
  String get examSwitcherManage;

  /// No description provided for @examSwitcherShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing {exam}'**
  String examSwitcherShowing(String exam);

  /// No description provided for @suggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest a feature'**
  String get suggestionsTitle;

  /// No description provided for @suggestionsIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us what would make PrepLoop more useful, or what you\'d rather remove. The PrepLoop team reads every suggestion.'**
  String get suggestionsIntro;

  /// No description provided for @suggestionsCardMessage.
  ///
  /// In en, this message translates to:
  /// **'Missing something, or is a feature in your way? Tell us.'**
  String get suggestionsCardMessage;

  /// No description provided for @suggestionsOpen.
  ///
  /// In en, this message translates to:
  /// **'Write a suggestion'**
  String get suggestionsOpen;

  /// No description provided for @suggestionKindAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get suggestionKindAdd;

  /// No description provided for @suggestionKindRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get suggestionKindRemove;

  /// No description provided for @suggestionKindChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get suggestionKindChange;

  /// No description provided for @suggestionKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get suggestionKindOther;

  /// No description provided for @suggestionField.
  ///
  /// In en, this message translates to:
  /// **'Your suggestion'**
  String get suggestionField;

  /// No description provided for @suggestionHintAdd.
  ///
  /// In en, this message translates to:
  /// **'Which feature should PrepLoop add, and how would it help you?'**
  String get suggestionHintAdd;

  /// No description provided for @suggestionHintRemove.
  ///
  /// In en, this message translates to:
  /// **'Which feature should be removed, and why?'**
  String get suggestionHintRemove;

  /// No description provided for @suggestionHintChange.
  ///
  /// In en, this message translates to:
  /// **'What should work differently?'**
  String get suggestionHintChange;

  /// No description provided for @suggestionHintOther.
  ///
  /// In en, this message translates to:
  /// **'Anything else you\'d like to tell us'**
  String get suggestionHintOther;

  /// No description provided for @suggestionTooShort.
  ///
  /// In en, this message translates to:
  /// **'Write at least {count} characters.'**
  String suggestionTooShort(int count);

  /// No description provided for @suggestionSend.
  ///
  /// In en, this message translates to:
  /// **'Send suggestion'**
  String get suggestionSend;

  /// No description provided for @suggestionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your suggestion is stored with your account so you can see its status here.'**
  String get suggestionPrivacy;

  /// No description provided for @suggestionSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your suggestion was sent.'**
  String get suggestionSent;

  /// No description provided for @suggestionTooMany.
  ///
  /// In en, this message translates to:
  /// **'You\'ve sent many suggestions today. Please try again tomorrow.'**
  String get suggestionTooMany;

  /// No description provided for @suggestionOffline.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the PrepLoop server. Try again when you\'re online.'**
  String get suggestionOffline;

  /// No description provided for @suggestionFailed.
  ///
  /// In en, this message translates to:
  /// **'The suggestion couldn\'t be sent. Please try again.'**
  String get suggestionFailed;

  /// No description provided for @suggestionsMine.
  ///
  /// In en, this message translates to:
  /// **'Your suggestions'**
  String get suggestionsMine;

  /// No description provided for @suggestionsNone.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t sent any suggestions yet.'**
  String get suggestionsNone;

  /// No description provided for @suggestionStatusNew.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get suggestionStatusNew;

  /// No description provided for @suggestionStatusRead.
  ///
  /// In en, this message translates to:
  /// **'Read by the team'**
  String get suggestionStatusRead;

  /// No description provided for @suggestionStatusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get suggestionStatusPlanned;

  /// No description provided for @suggestionStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get suggestionStatusDone;

  /// No description provided for @suggestionStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Not planned'**
  String get suggestionStatusDeclined;

  /// No description provided for @syllabusTitle.
  ///
  /// In en, this message translates to:
  /// **'Syllabus'**
  String get syllabusTitle;

  /// No description provided for @syllabusMessage.
  ///
  /// In en, this message translates to:
  /// **'Import the syllabus PDF again to add topics it lists that are missing here.'**
  String get syllabusMessage;

  /// No description provided for @syllabusMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your syllabus'**
  String get syllabusMissingTitle;

  /// No description provided for @syllabusMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Import the exam\'s syllabus PDF: its subjects and topics are added here, each with a box to tick once you\'ve revised it.'**
  String get syllabusMissingMessage;

  /// No description provided for @syllabusImport.
  ///
  /// In en, this message translates to:
  /// **'Import syllabus PDF'**
  String get syllabusImport;

  /// No description provided for @syllabusNothingFound.
  ///
  /// In en, this message translates to:
  /// **'No topics could be read from this PDF. Add them by hand, or try a clearer copy.'**
  String get syllabusNothingFound;

  /// No description provided for @syllabusDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} topics read from the syllabus ({pages} pages). Untick anything that isn\'t a topic.'**
  String syllabusDraftLabel(int count, int pages);

  /// No description provided for @syllabusUnreadable.
  ///
  /// In en, this message translates to:
  /// **'{count} pages were hard to read, so some topics may be missing.'**
  String syllabusUnreadable(int count);

  /// No description provided for @syllabusTruncated.
  ///
  /// In en, this message translates to:
  /// **'The syllabus lists more topics than one import holds; import the rest separately.'**
  String get syllabusTruncated;

  /// No description provided for @syllabusPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Add the {exam} syllabus first?'**
  String syllabusPromptTitle(String exam);

  /// No description provided for @syllabusPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'With the syllabus imported, PrepLoop lists every topic of the exam, sorts your questions into them and lets you tick each topic once revised. You can also add it later in Exams and topics.'**
  String get syllabusPromptMessage;

  /// No description provided for @syllabusPromptSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get syllabusPromptSkip;

  /// No description provided for @topicsRevisedCount.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} topics revised'**
  String topicsRevisedCount(int done, int total);

  /// No description provided for @topicRevised.
  ///
  /// In en, this message translates to:
  /// **'Revised'**
  String get topicRevised;

  /// No description provided for @topicRevisedCheckbox.
  ///
  /// In en, this message translates to:
  /// **'{topic} revised'**
  String topicRevisedCheckbox(String topic);
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
