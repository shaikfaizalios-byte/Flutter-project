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
  String get conceptsSearchHint => 'Search concepts';

  @override
  String get conceptsEmptyTitle => 'No concepts yet';

  @override
  String get conceptsEmptyMessage =>
      'Add the topics and notes you are studying. They are saved on this device and work offline.';

  @override
  String conceptsNoResults(String query) {
    return 'No concepts match \"$query\".';
  }

  @override
  String get conceptsLoadError => 'Your concepts could not be loaded.';

  @override
  String get conceptsAdd => 'Add concept';

  @override
  String get conceptArchive => 'Archive';

  @override
  String get conceptArchived => 'Concept archived';

  @override
  String get conceptSaved => 'Concept saved';

  @override
  String get undo => 'Undo';

  @override
  String conceptOptions(String title) {
    return 'Options for $title';
  }

  @override
  String get conceptFormTitle => 'New concept';

  @override
  String get fieldExam => 'Exam';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldSubject => 'Subject';

  @override
  String get fieldSubjectHint => 'e.g. Quantitative Aptitude';

  @override
  String get fieldTopic => 'Topic';

  @override
  String get fieldTopicHint => 'e.g. Percentage';

  @override
  String get fieldSubtopic => 'Subtopic (optional)';

  @override
  String get fieldContentLanguage => 'Content language';

  @override
  String get fieldTags => 'Tags (optional)';

  @override
  String get fieldTagsHint => 'Separate tags with commas';

  @override
  String get fieldSourceReference => 'Source (optional)';

  @override
  String get fieldSourceReferenceHint => 'e.g. book, page, or paper';

  @override
  String get fieldNotes => 'Notes (optional)';

  @override
  String get save => 'Save';

  @override
  String get saveFailed => 'The concept could not be saved. Please try again.';

  @override
  String get validationRequired => 'This field is required.';

  @override
  String validationTooLong(int max) {
    return 'Please shorten this to $max characters or fewer.';
  }

  @override
  String validationTooManyTags(int max) {
    return 'Use at most $max tags.';
  }

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

  @override
  String onboardingStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get onboardingSkipSetup => 'Skip setup';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get onboardingFinish => 'Start studying';

  @override
  String get onboardingWelcomeTitle => 'Welcome to PrepLoop';

  @override
  String get onboardingWelcomeBody =>
      'Let\'s set up your preparation. Every step is optional, and you can change your answers later in Profile. Your answers are stored on this device.';

  @override
  String get onboardingExamTitle => 'Which exam are you preparing for?';

  @override
  String get onboardingExamHint => 'Select one or both.';

  @override
  String get onboardingDateTitle => 'When is your exam?';

  @override
  String get onboardingDateHint =>
      'If you know the date, PrepLoop shows a countdown. You can skip this.';

  @override
  String get onboardingDailyTitle => 'How much time can you study each day?';

  @override
  String get onboardingDailyHint =>
      'Choose a realistic amount. Studying a little every day works better than occasional long sessions.';

  @override
  String get onboardingReminderTitle => 'When should PrepLoop remind you to study?';

  @override
  String get onboardingReminderHint =>
      'Reminders will be switched on in a later update. Your preferred time is saved now.';

  @override
  String get chooseDate => 'Choose date';

  @override
  String get chooseTime => 'Choose time';

  @override
  String get clear => 'Clear';

  @override
  String get notSet => 'Not set';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get settingsStudyPlan => 'Study plan';

  @override
  String get fieldExams => 'Exams';

  @override
  String get examsNotChosen => 'Not chosen';

  @override
  String get fieldExamDate => 'Exam date';

  @override
  String get fieldDailyStudy => 'Daily study time';

  @override
  String get fieldReminder => 'Reminder time';

  @override
  String get settingsLicences => 'Open-source licences';

  @override
  String get homeChooseExamTitle => 'Choose your exam';

  @override
  String get homeChooseExamMessage => 'Select SSC CGL, SSC CHSL or both to personalise PrepLoop.';

  @override
  String get homeChooseExamAction => 'Choose exam';

  @override
  String homeExamCountdown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days to go',
      one: '1 day to go',
      zero: 'Your exam is today',
    );
    return '$_temp0';
  }

  @override
  String get homeExamPassed => 'Your exam date has passed. You can update it in Profile.';

  @override
  String homeExamOn(String date) {
    return 'Exam date: $date';
  }

  @override
  String homeConceptCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count concepts saved.',
      one: 'You have 1 concept saved.',
      zero: 'You have not added any concepts yet.',
    );
    return '$_temp0';
  }

  @override
  String homeDailyGoal(String duration) {
    return 'Daily study goal: $duration';
  }

  @override
  String get homePlanComingSoon =>
      'A personalised daily plan will appear here once practice and revision are available.';

  @override
  String get homeOpenConcepts => 'Open concepts';

  @override
  String get homeSetExamDate => 'Set your exam date in Profile to see a countdown.';

  @override
  String get conceptDetailsTitle => 'Concept';

  @override
  String get conceptEdit => 'Edit';

  @override
  String get conceptEditTitle => 'Edit concept';

  @override
  String get conceptUnarchive => 'Restore';

  @override
  String get conceptRestored => 'Concept restored';

  @override
  String get conceptDelete => 'Delete';

  @override
  String get conceptDeleteTitle => 'Delete this concept?';

  @override
  String conceptDeleteMessage(String title) {
    return '\"$title\" will be permanently deleted from this device. This cannot be undone.';
  }

  @override
  String get conceptDeleted => 'Concept deleted';

  @override
  String get conceptNotFound => 'This concept no longer exists.';

  @override
  String get conceptLoadError => 'This concept could not be loaded.';

  @override
  String get conceptArchivedBanner => 'This concept is archived and hidden from your main list.';

  @override
  String conceptCreatedOn(String date) {
    return 'Created $date';
  }

  @override
  String conceptUpdatedOn(String date) {
    return 'Updated $date';
  }

  @override
  String get conceptMoreActions => 'More actions';

  @override
  String get filterExam => 'Exam';

  @override
  String get filterSubject => 'Subject';

  @override
  String get filterTopic => 'Topic';

  @override
  String get filterAll => 'All';

  @override
  String get filterArchived => 'Archived';

  @override
  String get filterClear => 'Clear filters';

  @override
  String filterBy(String label) {
    return 'Filter by $label';
  }

  @override
  String get conceptsNoFilterResults => 'No concepts match these filters.';

  @override
  String get conceptsArchivedEmpty => 'No archived concepts.';
}
