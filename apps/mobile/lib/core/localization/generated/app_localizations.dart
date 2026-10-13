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
  /// **'Reminders will be switched on in a later update. Your preferred time is saved now.'**
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
  /// **'Select SSC CGL, SSC CHSL or both to personalise PrepLoop.'**
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

  /// No description provided for @homePlanComingSoon.
  ///
  /// In en, this message translates to:
  /// **'A personalised daily plan will appear here once practice and revision are available.'**
  String get homePlanComingSoon;

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
  /// **'Import a previous-year paper in Study, then Imported papers. Its questions appear here for review. Practice sessions arrive in a later update.'**
  String get bankEmptyMessage;

  /// No description provided for @bankLoadError.
  ///
  /// In en, this message translates to:
  /// **'Questions could not be loaded.'**
  String get bankLoadError;
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
