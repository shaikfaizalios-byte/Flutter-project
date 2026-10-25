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
  String get navFeaturesTitle => 'Features';

  @override
  String get homeShortcutsTitle => 'Go straight to';

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
      'Switch on the daily reminder in Profile. PrepLoop asks for notification permission only then.';

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
  String get homeChooseExamMessage =>
      'Choose the exams you\'re preparing for to personalise PrepLoop.';

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

  @override
  String get documentsTitle => 'Imported papers';

  @override
  String get documentsImport => 'Import PDF';

  @override
  String get documentsEmptyTitle => 'No papers imported yet';

  @override
  String get documentsEmptyMessage =>
      'Import previous-year papers or study PDFs. PrepLoop reads the text page by page and flags pages it cannot read reliably for review.';

  @override
  String get documentsOfflineTitle => 'Can\'t reach the PrepLoop server';

  @override
  String get documentsOfflineMessage =>
      'Importing papers needs an internet connection. Your concepts still work offline.';

  @override
  String get documentsLoadError => 'Your imported papers could not be loaded.';

  @override
  String get documentStatusQueued => 'Waiting to be processed';

  @override
  String documentStatusProcessing(int done, int total) {
    return 'Reading page $done of $total';
  }

  @override
  String get documentStatusCompleted => 'Ready';

  @override
  String get documentStatusFailed => 'Processing failed';

  @override
  String documentPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String documentNeedsReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages need review',
      one: '1 page needs review',
    );
    return '$_temp0';
  }

  @override
  String get documentErrorTimeout => 'This document took too long to process.';

  @override
  String get documentErrorSourceMissing => 'The original file is no longer available.';

  @override
  String get documentErrorGeneric => 'Something went wrong while reading this document.';

  @override
  String documentOptions(String filename) {
    return 'Options for $filename';
  }

  @override
  String get documentDeleteTitle => 'Delete this paper?';

  @override
  String documentDeleteMessage(String filename) {
    return '\"$filename\" and the text extracted from it will be permanently deleted from the server.';
  }

  @override
  String get documentDeleted => 'Paper deleted';

  @override
  String importSheetTitle(String filename) {
    return 'Import \"$filename\"';
  }

  @override
  String get importUpload => 'Upload';

  @override
  String importUploading(String filename) {
    return 'Uploading $filename…';
  }

  @override
  String get importDone => 'Upload complete. Processing has started.';

  @override
  String get uploadErrorTooLarge => 'This file is larger than the allowed size.';

  @override
  String get uploadErrorNotPdf => 'Only PDF files can be imported.';

  @override
  String get uploadErrorEncrypted =>
      'This PDF is password-protected. Remove the password and try again.';

  @override
  String get uploadErrorInvalid => 'This file is damaged or is not a valid PDF.';

  @override
  String get uploadErrorTooManyPages => 'This PDF has too many pages.';

  @override
  String get uploadErrorEmpty => 'This file is empty.';

  @override
  String get uploadErrorRateLimited =>
      'You have uploaded several files recently. Please wait a while and try again.';

  @override
  String get uploadErrorOffline => 'Could not upload: there is no connection to the server.';

  @override
  String get uploadErrorGeneric => 'The upload failed. Please try again.';

  @override
  String get issueMissingAnswer => 'Answer not found';

  @override
  String get issueIncompleteOptions => 'Options incomplete';

  @override
  String get issueEmptyOption => 'An option is empty';

  @override
  String get issueDuplicateNumber => 'Question number repeated';

  @override
  String get issueAmbiguousBoundary => 'Question boundary unclear';

  @override
  String get issueImageDependent => 'Needs the original figure';

  @override
  String get issueRepeatedOptionLabels => 'Extra options found (possibly a second language)';

  @override
  String get issueAnswerNotInOptions => 'Answer does not match the options';

  @override
  String get issueConflictingAnswers => 'Different answers found';

  @override
  String get issueSourcePageNeedsReview => 'Source page was hard to read';

  @override
  String get issueNoQuestionsFound => 'No questions were found';

  @override
  String get issueNumberingGaps => 'Some question numbers are missing';

  @override
  String get issueAnswerKeyUnmatched => 'Answer key has numbers that are not in the paper';

  @override
  String get issueAnswerKeyAmbiguous =>
      'Numbering restarts in each section, so answers must be set during review';

  @override
  String get issueCountMismatch => 'Question count differs from the official format';

  @override
  String get issueSectionCountMismatch => 'A section\'s count differs from the official format';

  @override
  String get issueOther => 'Needs review';

  @override
  String get reviewTitle => 'Review questions';

  @override
  String get reviewQuestions => 'Review questions';

  @override
  String reviewSummaryVerified(int count) {
    return '$count verified';
  }

  @override
  String reviewSummaryAttention(int count) {
    return '$count need attention';
  }

  @override
  String reviewSummaryMissingAnswers(int count) {
    return '$count without an answer';
  }

  @override
  String reviewFormat(String name) {
    return 'Format: $name';
  }

  @override
  String get reviewFormatUnknown =>
      'No verified format linked, so question-count checks are skipped.';

  @override
  String get reviewReparse => 'Parse again';

  @override
  String get reviewReparsed => 'Questions parsed again. Your reviewed questions were kept.';

  @override
  String get reviewSegmentationPending =>
      'Questions will appear after the text has been extracted.';

  @override
  String get reviewSegmentationFailed => 'Questions could not be parsed from this paper.';

  @override
  String get reviewNoQuestions => 'No questions in this view.';

  @override
  String get filterAllQuestions => 'All';

  @override
  String get filterNeedsAttention => 'Needs attention';

  @override
  String get filterVerified => 'Verified';

  @override
  String get filterRejected => 'Rejected';

  @override
  String documentQuestionsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions found',
      one: '1 question found',
      zero: 'No questions found',
    );
    return '$_temp0';
  }

  @override
  String questionNumberLabel(int number) {
    return 'Q.$number';
  }

  @override
  String questionSource(String filename, int page) {
    return 'From $filename, page $page';
  }

  @override
  String get questionLabelSource => 'From your PDF';

  @override
  String get questionLabelAi => 'AI-generated';

  @override
  String get questionStatusVerified => 'Verified';

  @override
  String get questionStatusRejected => 'Rejected';

  @override
  String get questionStatusUnverified => 'Not reviewed';

  @override
  String get questionTitle => 'Question';

  @override
  String get fieldStem => 'Question text';

  @override
  String get fieldOptions => 'Options';

  @override
  String fieldOption(String label) {
    return 'Option $label';
  }

  @override
  String get addOption => 'Add option';

  @override
  String get fieldCorrectAnswer => 'Correct answer';

  @override
  String get answerNotSet => 'Not set';

  @override
  String get fieldExplanation => 'Explanation (optional)';

  @override
  String get topicSuggested => 'Suggested topic. Approving the question confirms it.';

  @override
  String get topicNone => 'No topic';

  @override
  String get fieldImageDependent => 'Needs the original figure or image';

  @override
  String sharedPassage(int first, int last) {
    return 'Shared passage (Q.$first to Q.$last)';
  }

  @override
  String get sourcePageText => 'Source page text';

  @override
  String get sourcePageLoadError => 'The page text could not be loaded.';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get saved => 'Saved';

  @override
  String get questionApproved => 'Question approved';

  @override
  String get questionRejected => 'Question rejected';

  @override
  String get cannotVerify => 'Fix the listed problems before approving.';

  @override
  String get openIssues => 'Problems to check';

  @override
  String get bankTitle => 'Question bank';

  @override
  String get bankSearchHint => 'Search questions';

  @override
  String get bankEmptyTitle => 'No questions yet';

  @override
  String get bankEmptyMessage =>
      'Import a previous-year paper in Study, then Imported papers. Its questions appear here for review, and reviewed questions can be practised.';

  @override
  String get bankLoadError => 'Questions could not be loaded.';

  @override
  String get practiceHubTitle => 'Practice';

  @override
  String get practiceStartTitle => 'Practice questions';

  @override
  String get practiceStartMessage => 'Untimed. You see whether you are right after each answer.';

  @override
  String get practiceStart => 'Start practice';

  @override
  String get practiceSetupTitle => 'Set up practice';

  @override
  String get practiceMixed => 'Mixed (all subjects)';

  @override
  String get practiceSubject => 'Subject';

  @override
  String get practiceTopic => 'Topic (optional)';

  @override
  String get practiceTopicAny => 'Any topic';

  @override
  String get practiceCount => 'Number of questions';

  @override
  String get practiceIncludeUnverified => 'Include questions not yet reviewed';

  @override
  String get practiceIncludeUnverifiedHint =>
      'They are labelled, and their answers may contain extraction mistakes.';

  @override
  String get practiceNoQuestions =>
      'No reviewed questions match. Approve questions in the question bank, or include ones not yet reviewed.';

  @override
  String get mockTestsTitle => 'Mock tests';

  @override
  String get mockTestsMessage => 'Timed tests built only from verified official exam formats.';

  @override
  String get mockTestsNone => 'No verified exam formats are available yet.';

  @override
  String mockTestDetails(int questions, int minutes) {
    return '$questions questions · $minutes min';
  }

  @override
  String mockNegative(String marks) {
    return '−$marks per wrong answer';
  }

  @override
  String get mockStart => 'Start mock test';

  @override
  String get mockUnavailable => 'Not enough reviewed questions yet:';

  @override
  String mockSectionShort(String subject, int available, int needed) {
    return '$subject: $available of $needed';
  }

  @override
  String get mockConfirmTitle => 'Start the mock test?';

  @override
  String get mockConfirmMessage =>
      'The timer starts now and keeps running even if you close the app. The test is submitted automatically when time is up.';

  @override
  String get reviewToolsTitle => 'Review';

  @override
  String get bookmarksTitle => 'Bookmarks';

  @override
  String get bookmarksEmpty => 'No bookmarked questions.';

  @override
  String get incorrectTitle => 'Questions to revisit';

  @override
  String get incorrectEmpty => 'No incorrect answers to review.';

  @override
  String get questionBankOpen => 'Question bank';

  @override
  String get historyTitle => 'Recent sessions';

  @override
  String get historyEmpty => 'Your practice sessions will appear here.';

  @override
  String get historyPractice => 'Practice';

  @override
  String historyMock(String name) {
    return 'Mock: $name';
  }

  @override
  String get historyInProgress => 'In progress';

  @override
  String historyScore(String score, String max) {
    return '$score / $max';
  }

  @override
  String sessionQuestionOf(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get sessionNotReviewed => 'Not yet reviewed';

  @override
  String get sessionPrevious => 'Previous';

  @override
  String get sessionNext => 'Next';

  @override
  String get sessionSubmit => 'Submit';

  @override
  String get sessionFinish => 'Finish';

  @override
  String get sessionCorrect => 'Correct';

  @override
  String get sessionIncorrect => 'Incorrect';

  @override
  String sessionCorrectAnswer(String label) {
    return 'Correct answer: ($label)';
  }

  @override
  String get sessionSavedOffline =>
      'Saved on this device. It will be sent when you are back online.';

  @override
  String get sessionFeedbackOffline => 'Feedback will appear when you are back online.';

  @override
  String get sessionSubmitTitle => 'Submit now?';

  @override
  String sessionUnanswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions are unanswered.',
      one: '1 question is unanswered.',
      zero: 'All questions are answered.',
    );
    return '$_temp0';
  }

  @override
  String get sessionTimeUp => 'Time is up. Your saved answers were submitted.';

  @override
  String sessionTimeLeft(String time) {
    return 'Time left $time';
  }

  @override
  String get sessionQuestionRemoved => 'This question was removed from the question bank.';

  @override
  String get sessionLoadError => 'This session could not be loaded.';

  @override
  String get sessionOfflineOpen =>
      'Opening a session needs a connection. Answers you give during a session are saved on this device if the connection drops.';

  @override
  String get sessionPalette => 'All questions';

  @override
  String get sessionBookmark => 'Bookmark';

  @override
  String get sessionRemoveBookmark => 'Remove bookmark';

  @override
  String get sessionSubmitFailed =>
      'Could not submit. Your answers are saved; try again when you are online.';

  @override
  String get resultTitle => 'Result';

  @override
  String resultScore(String score, String max) {
    return '$score of $max';
  }

  @override
  String resultAccuracy(int percent) {
    return 'Accuracy $percent%';
  }

  @override
  String get resultAccuracyNone => 'No questions attempted';

  @override
  String resultTime(String time) {
    return 'Time taken $time';
  }

  @override
  String resultCounts(int correct, int wrong, int unattempted) {
    return '$correct correct · $wrong wrong · $unattempted unattempted';
  }

  @override
  String get resultHowScored => 'How this score was calculated';

  @override
  String get resultSections => 'By section';

  @override
  String get resultTopics => 'By topic';

  @override
  String get resultReviewAnswers => 'Review answers';

  @override
  String resultYourAnswer(String label) {
    return 'Your answer: ($label)';
  }

  @override
  String get resultNotAnswered => 'Not answered';

  @override
  String get resultSubmittedTimeUp => 'Submitted automatically when time was up.';

  @override
  String get revisionTitle => 'Revision';

  @override
  String get revisionDueTitle => 'Due today';

  @override
  String revisionDueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards to revise',
      one: '1 card to revise',
    );
    return '$_temp0';
  }

  @override
  String revisionOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count of them are overdue',
      one: '1 of them is overdue',
    );
    return '$_temp0';
  }

  @override
  String get revisionStart => 'Start revision';

  @override
  String get revisionNothingDue => 'Nothing to revise today.';

  @override
  String revisionNextReview(String when) {
    return 'Next review: $when';
  }

  @override
  String get revisionUpcomingTitle => 'Next 7 days';

  @override
  String get revisionScheduleTitle => 'Revision schedule';

  @override
  String revisionLadder(String days) {
    return 'Review on day $days after adding a card';
  }

  @override
  String get revisionLadderExplanation =>
      'Remembering moves a card to the next review day; after the last one the gap keeps doubling. Hard repeats with a shorter gap. Forgetting starts the card again from the first day.';

  @override
  String get revisionEditSchedule => 'Change schedule';

  @override
  String get revisionScheduleHelp =>
      'Days after you add a card when it comes back for review. Changes apply to future reviews; cards keep their current due dates.';

  @override
  String get revisionScheduleField => 'Review days';

  @override
  String get revisionScheduleFieldHint => 'For example: 1, 4, 7';

  @override
  String revisionScheduleInvalid(int maxSteps, int maxDay) {
    return 'Enter 1 to $maxSteps different days between 1 and $maxDay.';
  }

  @override
  String get revisionScheduleReset => 'Use 1, 4, 7';

  @override
  String get revisionScheduleSaved => 'Revision schedule saved.';

  @override
  String revisionAllCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All cards ($count)',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String get revisionEmptyTitle => 'No flashcards yet';

  @override
  String get revisionEmptyMessage =>
      'Add a concept to revision from its details page, or add questions from Practice → Bookmarks or Questions to revisit.';

  @override
  String get revisionLoadError => 'Could not load your flashcards.';

  @override
  String get revisionSaveError => 'Could not save. Please try again.';

  @override
  String get revisionRemove => 'Remove';

  @override
  String get revisionRemoved => 'Removed from revision.';

  @override
  String get revisionDueToday => 'Today';

  @override
  String get revisionDueTomorrow => 'Tomorrow';

  @override
  String revisionDueInDays(int days) {
    return 'In $days days';
  }

  @override
  String revisionOverdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String get revisionReviewTitle => 'Revise';

  @override
  String revisionCardPosition(int position, int total) {
    return 'Card $position of $total';
  }

  @override
  String get revisionShowAnswer => 'Show answer';

  @override
  String get revisionAnswer => 'Answer';

  @override
  String get revisionNoNotes => 'No notes for this concept. Try to recall what you know about it.';

  @override
  String get revisionHowWell => 'How well did you remember it?';

  @override
  String revisionDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You revised $count cards',
      one: 'You revised 1 card',
    );
    return '$_temp0';
  }

  @override
  String get ratingAgain => 'Forgot';

  @override
  String get ratingHard => 'Hard';

  @override
  String get ratingGood => 'Good';

  @override
  String get ratingEasy => 'Easy';

  @override
  String get cardOriginNotes => 'Your notes';

  @override
  String get cardOriginPaper => 'From your PDF';

  @override
  String cardOriginPaperPage(String file, int page) {
    return 'From your PDF · $file, p. $page';
  }

  @override
  String get cardReasonIncorrect => 'Answered wrong in practice';

  @override
  String get conceptAddToRevision => 'Add to revision';

  @override
  String get conceptInRevision => 'In revision';

  @override
  String get revisionAddAll => 'Revise these';

  @override
  String revisionQuestionsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards added to revision.',
      one: '1 card added to revision.',
      zero: 'No new cards added.',
    );
    return '$_temp0';
  }

  @override
  String revisionQuestionsAlreadyAdded(int count) {
    return '$count already in revision.';
  }

  @override
  String revisionQuestionsNotEligible(int count) {
    return '$count not added: only reviewed questions with an answer and no figure can be revised.';
  }

  @override
  String homeRevisionNoneToday(String when) {
    return 'No revision due today. Next: $when.';
  }

  @override
  String get homeRevisionEmpty => 'No flashcards yet. Add concepts or questions to revision.';

  @override
  String get reminderSwitch => 'Daily study reminder';

  @override
  String reminderOn(String time) {
    return 'Every day at $time';
  }

  @override
  String get reminderOff => 'Off';

  @override
  String get reminderNeedsTime => 'Choose a reminder time to switch it on.';

  @override
  String get reminderBlocked =>
      'Notifications are turned off for PrepLoop. Allow them in system settings to get reminders.';

  @override
  String get reminderFailed => 'The reminder could not be set.';

  @override
  String get reminderUnsupported => 'Reminders work in the Android and iOS apps.';

  @override
  String get reminderOpenSettings => 'Open notification settings';

  @override
  String get reminderNotificationTitle => 'Time to study';

  @override
  String get reminderNotificationBody => 'Open PrepLoop to see what to revise today.';

  @override
  String get reminderChannelName => 'Study reminders';

  @override
  String topicAccuracy(String percent, int answered) {
    return '$percent correct over $answered answers';
  }

  @override
  String topicForgotten(int forgot, int reviews) {
    return 'forgotten in $forgot of $reviews flashcard reviews';
  }

  @override
  String planRevisionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Revise $count flashcards',
      one: 'Revise 1 flashcard',
    );
    return '$_temp0';
  }

  @override
  String planWeakTopicTitle(String topic) {
    return 'Practise $topic';
  }

  @override
  String get planMixedTitle => 'Practise mixed questions';

  @override
  String planMockTitle(String name) {
    return 'Take a mock test: $name';
  }

  @override
  String planMinutes(int minutes) {
    return 'about $minutes min';
  }

  @override
  String get planStart => 'Start';

  @override
  String reasonCardsDue(int due) {
    return '$due due today';
  }

  @override
  String reasonCardsDueOverdue(int due, int overdue) {
    return '$due due today, $overdue overdue';
  }

  @override
  String reasonBelowThreshold(String threshold) {
    return 'below $threshold';
  }

  @override
  String get reasonNoPracticeData =>
      'No practice answers yet; practising shows which topics need work';

  @override
  String reasonNoWeakTopic(int min) {
    return 'No weak topic found yet (a topic is judged after $min answers)';
  }

  @override
  String get reasonMockNever => 'You have not taken a mock test yet.';

  @override
  String reasonMockSince(int days) {
    return 'Last mock test $days days ago.';
  }

  @override
  String reasonExamIn(int days) {
    return 'Exam in $days days.';
  }

  @override
  String planGoal(int planned, int goal) {
    return 'About $planned min planned for your $goal-minute daily goal.';
  }

  @override
  String get planNoGoal => 'Set a daily study goal in Profile to fit the plan to your time.';

  @override
  String get planOffline => 'Practice suggestions need a connection, so only revision is planned.';

  @override
  String get planEmpty => 'Nothing planned for today: no flashcards are due.';

  @override
  String get homeWeakOffline => 'Practice statistics need a connection.';

  @override
  String homeWeakNone(String threshold) {
    return 'No weak topics: every topic with enough data is at $threshold correct or better.';
  }

  @override
  String homeWeakNeedMore(int answers, int reviews) {
    return 'Not enough data yet. A topic is judged after $answers practice answers or $reviews flashcard reviews.';
  }

  @override
  String get homeSeeProgress => 'See progress';

  @override
  String get progressSummaryTitle => 'Practice overview';

  @override
  String progressAnswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count practice answers',
      one: '1 practice answer',
    );
    return '$_temp0';
  }

  @override
  String progressAccuracy(String percent) {
    return '$percent correct';
  }

  @override
  String progressSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String progressDailyTitle(int days) {
    return 'Questions answered, last $days days';
  }

  @override
  String progressChartSummary(int total, int days) {
    return '$total in the last $days days';
  }

  @override
  String get progressSubjectsTitle => 'By subject';

  @override
  String get progressNoAnswers => 'No practice answers yet.';

  @override
  String progressSubjectRow(String percent, int answered) {
    return '$percent correct over $answered answers';
  }

  @override
  String progressNotEnough(int answered, int min) {
    return 'Not enough answers yet ($answered of $min)';
  }

  @override
  String get progressMocksTitle => 'Mock tests';

  @override
  String get progressMocksEmpty => 'No mock tests taken yet.';

  @override
  String progressMockScore(String score, String max) {
    return '$score / $max';
  }

  @override
  String get progressMockTimeUp => 'Submitted when time ran out';

  @override
  String get progressTopicsTitle => 'Topics';

  @override
  String get progressTopicsEmpty =>
      'Topic results appear once practised questions or flashcards have a topic.';

  @override
  String get progressWeakBadge => 'Weak';

  @override
  String get progressTrendImproving => 'Improving';

  @override
  String get progressTrendSteady => 'Steady';

  @override
  String get progressTrendDeclining => 'Declining';

  @override
  String progressNeedsData(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more topics need more data before they are judged.',
      one: '1 more topic needs more data before it is judged.',
    );
    return '$_temp0';
  }

  @override
  String get progressRevisionTitle => 'Flashcard recall';

  @override
  String progressRevisionSummary(int reviews, int forgot, int days) {
    return '$reviews reviews, forgotten $forgot times in the last $days days';
  }

  @override
  String progressRevisionEmpty(int days) {
    return 'No flashcard reviews in the last $days days.';
  }

  @override
  String get progressOffline => 'Practice statistics could not be loaded. Check your connection.';

  @override
  String progressRules(String accuracy, int answers, String forget, int reviews, int recentDays) {
    return 'A topic is weak when it is below $accuracy correct after at least $answers answers, or forgotten in $forget or more of at least $reviews flashcard reviews. Trends compare the last $recentDays days with earlier answers.';
  }

  @override
  String get aiAssistTitle => 'AI assistance';

  @override
  String get aiReviewNote =>
      'AI output is a draft. It is labelled \"AI-generated\" and must be reviewed before learners see it.';

  @override
  String aiProvenance(String model, String version) {
    return 'AI-generated by $model (prompt $version)';
  }

  @override
  String get aiBasedOnQuestion => 'based on a reviewed question';

  @override
  String get aiDraftLabel => 'AI-generated draft, not reviewed';

  @override
  String get aiExplanationApproved => 'AI-generated explanation (approved)';

  @override
  String get aiExplanationLabel => 'AI-generated explanation';

  @override
  String get aiUnsure =>
      'The AI was not sure the given answer is right. Check the answer before approving.';

  @override
  String get aiApprove => 'Approve';

  @override
  String get aiEditApprove => 'Edit and approve';

  @override
  String get aiDraftExplanation => 'Draft an explanation with AI';

  @override
  String get aiSuggestTopic => 'Suggest a topic with AI';

  @override
  String get aiNoTopic => 'The AI found no matching topic. Choose one yourself.';

  @override
  String get aiGenerateSimilar => 'Generate similar practice questions';

  @override
  String get aiApproveFirst =>
      'Approve this question first; AI only works from reviewed questions with an answer.';

  @override
  String get aiGenerateTitle => 'Generate practice questions';

  @override
  String get aiGenerate => 'Generate';

  @override
  String get aiGenerateFromQuestionNotice =>
      'New questions are written by AI on the same topic. They are saved as AI-generated and unreviewed, and never count as previous-year questions.';

  @override
  String get aiGenerateFromConcept => 'Practice questions from my notes (AI)';

  @override
  String get aiConceptNotice =>
      'The concept title and your notes are sent to the AI service to write questions. The questions are saved as AI-generated and need review in the question bank before practice.';

  @override
  String aiGenerated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AI questions added to the question bank for review.',
      one: '1 AI question added to the question bank for review.',
      zero: 'No usable questions were generated.',
    );
    return '$_temp0';
  }

  @override
  String aiGeneratedRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count were rejected by the checks.',
      one: '1 was rejected by the checks.',
    );
    return '$_temp0';
  }

  @override
  String get aiErrorOffline => 'You are offline. AI assistance needs a connection.';

  @override
  String get aiErrorDisabled => 'AI assistance is not set up on the server.';

  @override
  String get aiErrorUnavailable =>
      'The AI service is not available right now. Please try again in a moment.';

  @override
  String get aiErrorRateLimited => 'Too many AI requests. Please try again later.';

  @override
  String get aiErrorNotEligible =>
      'AI can only work from reviewed questions with an answer and no figure.';

  @override
  String get aiErrorExplanationExists => 'This question already has an explanation.';

  @override
  String get aiErrorTopicSet => 'This question already has a topic.';

  @override
  String get aiErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get reportTitle => 'Report a problem';

  @override
  String get reportNote => 'What is wrong? (optional)';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSent => 'Thanks. The question goes back for review.';

  @override
  String get reportWrongAnswer => 'The answer is wrong';

  @override
  String get reportUnclear => 'The question is unclear';

  @override
  String get reportIncorrectContent => 'The content is incorrect';

  @override
  String get reportOther => 'Something else';

  @override
  String get practiceIncludeAi => 'Include AI-generated questions';

  @override
  String get practiceIncludeAiHint =>
      'They are labelled \"AI-generated\" and are not previous-year questions. Mock tests never use them.';

  @override
  String get topicSuggestedByAi => 'Suggested by AI. Confirm or change it.';

  @override
  String get issueLearnerReport => 'Reported by a learner';

  @override
  String get issueAiLanguageReview => 'AI-written Hindi: check the language';

  @override
  String get authSignInTitle => 'Sign in to your study account.';

  @override
  String get authCreateTitle => 'Create your study account.';

  @override
  String get authSessionExpired => 'You were signed out. Please sign in again.';

  @override
  String get authName => 'Name (optional)';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailInvalid => 'Enter a valid email address.';

  @override
  String get authPassword => 'Password';

  @override
  String authPasswordHint(int min) {
    return 'At least $min characters';
  }

  @override
  String get authPasswordRequired => 'Enter your password.';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authCreate => 'Create account';

  @override
  String get authNoAccount => 'New here? Create an account';

  @override
  String authAgeConfirm(int age) {
    return 'I am $age or older';
  }

  @override
  String authAgeRequired(int age) {
    return 'You must be $age or older to create an account.';
  }

  @override
  String get authHaveAccount => 'Already have an account? Sign in';

  @override
  String get authSyncNote =>
      'Your concepts, flashcards and study plan are saved to your account, so you can continue on another device. Imported papers and practice results are kept on the server for your account only.';

  @override
  String get authErrorCredentials => 'Email or password is not correct.';

  @override
  String get authErrorEmailTaken => 'An account with this email already exists. Sign in instead.';

  @override
  String get authErrorRateLimited => 'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get authErrorInvalid => 'Check the email and password and try again.';

  @override
  String get authErrorOffline => 'You are offline. Connect to the internet to continue.';

  @override
  String get authErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get accountTitle => 'Account';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncInProgress => 'Syncing…';

  @override
  String get syncNever => 'Not synced yet';

  @override
  String syncDone(String when) {
    return 'Synced $when';
  }

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String syncOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Offline. $count changes will sync when you are back online.',
      zero: 'Offline. Changes will sync when you are back online.',
    );
    return '$_temp0';
  }

  @override
  String get syncFailed => 'Could not sync. It will be retried.';

  @override
  String get accountExport => 'Copy my data';

  @override
  String get accountExported => 'Your data was copied as JSON. Paste it into a file to keep it.';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutTitle => 'Sign out?';

  @override
  String get accountSignOutMessage =>
      'Your study data will be removed from this device. It stays in your account.';

  @override
  String accountSignOutUnsynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes have not synced yet and will be lost if you sign out now.',
      one: '1 change has not synced yet and will be lost if you sign out now.',
    );
    return '$_temp0';
  }

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountDeleteTitle => 'Delete your account?';

  @override
  String get accountDeleteMessage =>
      'This permanently deletes your account and everything in it: concepts, flashcards, imported papers, questions and practice history. It cannot be undone. Enter your password to confirm.';

  @override
  String get accountDeleteConfirm => 'Delete permanently';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authErrorCode => 'That code is not valid or has expired. Request a new one.';

  @override
  String get resetTitle => 'Reset password';

  @override
  String get resetIntro => 'Enter your account email. We will send you a 6-digit code.';

  @override
  String get resetCodeSent =>
      'If an account exists for this email, we sent a 6-digit code. It expires in 15 minutes.';

  @override
  String get resetCode => '6-digit code';

  @override
  String get resetCodeInvalid => 'Enter the 6-digit code from the email.';

  @override
  String get resetNewPassword => 'New password';

  @override
  String get resetSend => 'Send code';

  @override
  String get resetSave => 'Set new password';

  @override
  String get resetResend => 'Send a new code';

  @override
  String get resetDone => 'Password changed. Sign in with your new password.';

  @override
  String get legalPrivacy => 'Privacy policy';

  @override
  String get legalTerms => 'Terms of use';

  @override
  String get legalLoadError => 'Could not open the document.';

  @override
  String get verifyTitle => 'Confirm your email';

  @override
  String get verifyMessage =>
      'Confirming your email lets you reset your password if you forget it.';

  @override
  String get verifyAction => 'Confirm';

  @override
  String get verifyCodeSent => 'We sent a 6-digit code to your email.';

  @override
  String get verifyConfirm => 'Confirm';

  @override
  String get verifyDone => 'Email confirmed.';

  @override
  String get close => 'Close';

  @override
  String figureLabel(int page) {
    return 'Figure from the paper (page $page)';
  }

  @override
  String figureOptionLabel(int page) {
    return 'Option figure from the paper (page $page)';
  }

  @override
  String figureOriginalLabel(int page) {
    return 'Question as printed in the paper (page $page)';
  }

  @override
  String get figureLoadError => 'Couldn\'t load the figure.';

  @override
  String get figuresFromPaper => 'Figures from the paper (shown as printed)';

  @override
  String get issueUnreadableText => 'Some characters couldn\'t be read';

  @override
  String get issueFiguresNotExtracted => 'Some figures couldn\'t be extracted';

  @override
  String reviewSummaryFigures(int count) {
    return '$count with figures';
  }

  @override
  String reviewSummaryUnreadable(int count) {
    return '$count with unreadable text';
  }

  @override
  String get topicsCardTitle => 'Subjects and topics';

  @override
  String topicsSummary(int suggested, int unassigned) {
    return '$suggested suggested · $unassigned without a topic';
  }

  @override
  String topicsAcceptAll(int count) {
    return 'Accept all suggestions ($count)';
  }

  @override
  String get topicsAcceptConfirmTitle => 'Accept all suggestions?';

  @override
  String get topicsAcceptConfirmBody =>
      'Every suggested topic and question type of this paper becomes confirmed. Rejected questions are skipped, and you can still change any of them afterwards.';

  @override
  String get topicsAcceptAction => 'Accept all';

  @override
  String topicsAccepted(int count) {
    return '$count topics accepted.';
  }

  @override
  String topicsAiSuggest(int count) {
    return 'Suggest topics with AI ($count questions)';
  }

  @override
  String get topicsAiNotice =>
      'The text of these questions is sent to the AI service. Its suggestions are labelled AI and need your confirmation.';

  @override
  String get topicsAiConfirm => 'Send to AI';

  @override
  String topicsAiRunning(int remaining) {
    return 'Asking the AI… $remaining left';
  }

  @override
  String topicsAiDone(int suggested, int noMatch) {
    return 'AI suggested $suggested topics. $noMatch questions had no match.';
  }

  @override
  String get topicsRulesNote =>
      'Suggestions come from keyword rules (and the AI if you ask). Each one shows why it was made.';

  @override
  String topicSuggestionReason(String reason) {
    return 'Why: $reason';
  }

  @override
  String get repeatsTitle => 'Repeated models';

  @override
  String get repeatsHubMessage =>
      'See which topics and question types came up most often in the papers you imported, so you don\'t miss them.';

  @override
  String get repeatsOpen => 'See repeated models';

  @override
  String get repeatsEmptyTitle => 'No papers yet';

  @override
  String get repeatsEmptyMessage =>
      'Import previous papers. PrepLoop counts how often each topic and question type appears in them.';

  @override
  String get repeatsImportPapers => 'Import papers';

  @override
  String get repeatsNeedsReviewTitle => 'Review topics to count them';

  @override
  String get repeatsNeedsReviewMessage =>
      'Topics are only suggestions so far. Open a paper and accept its suggestions (or approve questions) to count them here.';

  @override
  String get repeatsSimilarTitle => 'Worded alike in different papers';

  @override
  String get repeatsSimilarNote =>
      'Found by comparing wording, with numbers ignored. A hint, not a reviewed classification: check before relying on it.';

  @override
  String repeatsBasis(int count) {
    return 'Based on $count of your papers';
  }

  @override
  String repeatsBasisYears(int count, int first, int last) {
    return 'Based on $count of your papers ($first–$last)';
  }

  @override
  String repeatsUndated(int count) {
    return '$count papers have no confirmed date, so they aren\'t in the year counts. Confirm dates on each paper\'s review screen.';
  }

  @override
  String get repeatsReviewedNote =>
      'Counts use questions whose topic or type you have confirmed. Unconfirmed suggestions are shown separately.';

  @override
  String repeatsMostPapersRule(int percent, int min) {
    return '“Seen in most papers” means in at least $percent% of your papers, once you have $min or more.';
  }

  @override
  String repeatsInPapers(int papers, int total, int questions) {
    return 'In $papers of $total papers · $questions questions';
  }

  @override
  String repeatsUnreviewed(int count) {
    return '+$count not yet reviewed';
  }

  @override
  String get repeatsSeenInMost => 'Seen in most papers';

  @override
  String repeatsByYear(String years) {
    return 'By year: $years';
  }

  @override
  String get repeatsPractise => 'Practise';

  @override
  String get repeatsPractiseTopic => 'Practise this topic';

  @override
  String repeatsWithoutPattern(int count) {
    return '$count other questions in this topic (no named type)';
  }

  @override
  String get repeatsSimilarUnclassified => 'No topic yet';

  @override
  String repeatsSimilarPapers(int papers, int total) {
    return 'In $papers of $total papers';
  }

  @override
  String get fieldPattern => 'Question type';

  @override
  String get patternNone => 'No type';

  @override
  String get patternSuggested => 'Suggested type. Approving the question confirms it.';

  @override
  String patternsSuggestedCount(int count) {
    return '$count question types suggested';
  }

  @override
  String topicsAcceptedWithPatterns(int topics, int patterns) {
    return '$topics topics and $patterns question types accepted.';
  }

  @override
  String get paperDateTitle => 'When was this paper held?';

  @override
  String get paperDateMissing => 'Not known yet';

  @override
  String get paperDateUnknownConfirmed => 'Date not known';

  @override
  String get paperDateConfirmed => 'Confirmed. Used in year counts.';

  @override
  String get paperDateSuggested => 'Suggested: confirm it to use it in year counts';

  @override
  String get paperDateWhy => 'Set the date to see which years a topic appeared in.';

  @override
  String get paperDateConfirm => 'Confirm';

  @override
  String get paperDateEdit => 'Change';

  @override
  String get paperDateSet => 'Set date';

  @override
  String get paperDateSaved => 'Paper date saved.';

  @override
  String paperShift(int shift) {
    return 'Shift $shift';
  }

  @override
  String get paperYear => 'Year';

  @override
  String get paperShiftLabel => 'Shift';

  @override
  String get paperDateNotKnown => 'Not known';

  @override
  String get paperDatePickDay => 'Pick the day (optional)';

  @override
  String get repeatsYourPapers => 'Your papers';

  @override
  String get repeatsAllLearners => 'All learners';

  @override
  String get radarShareTitle => 'Repeat Radar';

  @override
  String get radarShareSwitch => 'Share my counts with the Repeat Radar';

  @override
  String get radarShareWhat =>
      'Only how many questions of each topic and question type your reviewed papers had, with the paper\'s exam date and shift. Never question text, your papers or your account details. Turning this off removes your counts at once.';

  @override
  String radarShareEligible(int count) {
    return '$count of your papers can join (they need a confirmed date and shift).';
  }

  @override
  String get radarEmptyTitle => 'Not enough shared data yet';

  @override
  String radarEmptyMessage(int min) {
    return 'A paper shift appears here once at least $min learners have reviewed it and their counts agree. Turn on sharing below and confirm your papers\' date and shift to help.';
  }

  @override
  String radarBasis(int shifts) {
    return 'Based on $shifts exam shifts reviewed by learners';
  }

  @override
  String radarBasisYears(int shifts, int first, int last) {
    return 'Based on $shifts exam shifts reviewed by learners ($first–$last)';
  }

  @override
  String radarHowCounted(int min) {
    return 'Each shift counts only when at least $min learners reviewed it, and a number is shown only when their counts agree. One person can\'t change these numbers.';
  }

  @override
  String radarWithheld(int count) {
    return '$count counts are hidden because learners\' numbers didn\'t agree.';
  }

  @override
  String radarMostRule(int percent, int min) {
    return '“In most shifts” means in at least $percent% of the shifts, once there are $min or more.';
  }

  @override
  String radarInShifts(int shifts, int total, int questions) {
    return 'In $shifts of $total shifts · $questions questions';
  }

  @override
  String get radarSeenInMost => 'In most shifts';

  @override
  String radarShiftsByYear(String years) {
    return 'Shifts by year: $years';
  }

  @override
  String get delete => 'Delete';

  @override
  String get examsMore => 'More exams';

  @override
  String get examsOwnGroup => 'My own exams';

  @override
  String get examsSearch => 'Search exams';

  @override
  String get examsNoMatch => 'No exam matches. Create your own below.';

  @override
  String get examsCreateOwn => 'Create my own exam';

  @override
  String get examsCreateOwnHint => 'For any exam not in the list. Only you see it.';

  @override
  String examsDone(int count) {
    return 'Done ($count chosen)';
  }

  @override
  String get examsRename => 'Rename exam';

  @override
  String get examsNameLabel => 'Exam name';

  @override
  String get examsNameHint => 'e.g. Rajasthan Patwari 2026';

  @override
  String get examsInUse => 'Papers, questions or notes still use this exam. Delete them first.';

  @override
  String examsDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get examsDeleteBody =>
      'Its topics are deleted too. Exams still used by papers or notes can\'t be deleted.';

  @override
  String get examsDeleted => 'Exam deleted.';

  @override
  String get examsTitle => 'Exams and topics';

  @override
  String get examsEmptyTitle => 'No exams chosen';

  @override
  String get examsEmptyMessage => 'Choose your exams below, or create your own.';

  @override
  String get examsIntro =>
      'Each exam has its own subjects and topics. PrepLoop uses them to sort the questions in your papers and to show what repeats.';

  @override
  String get examsOwnLabel => 'My own exam (only you see it)';

  @override
  String get examsActions => 'More actions';

  @override
  String get examsManageTile => 'Exams and topics';

  @override
  String get examsManageTileHint => 'Add your own exams, subjects and topics';

  @override
  String get topicsExists => 'This exam already has that topic.';

  @override
  String get topicsDraftNeedsPapers => 'Import at least one paper of this exam first.';

  @override
  String topicsDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get topicsDeleteBody => 'Questions with this topic go back to “no topic”.';

  @override
  String get topicsDraftTitle => 'Draft topics with AI?';

  @override
  String get topicsDraftNotice =>
      'Up to 60 questions from your imported papers of this exam are sent to the AI service to propose subjects and topics. Nothing is saved until you choose which to keep.';

  @override
  String get topicsDraftEmpty => 'The AI proposed no new topics.';

  @override
  String topicsDraftSaved(int count) {
    return '$count topics added.';
  }

  @override
  String topicsScreenTitle(String exam) {
    return '$exam: topics';
  }

  @override
  String get topicsAdd => 'Add topic';

  @override
  String get topicsScreenIntro =>
      'Questions in your papers are matched to these topics by their keywords; you confirm every suggestion. Shared topics come with PrepLoop; your own you can change.';

  @override
  String get topicsDraftAction => 'Draft topics from my papers (AI)';

  @override
  String get topicsEmptyTitle => 'No topics yet';

  @override
  String get topicsEmptyMessage =>
      'Add the subjects and topics of this exam\'s syllabus, e.g. Biology › Cell Biology.';

  @override
  String get topicsOwnLabel => 'Your topic';

  @override
  String get topicsSharedLabel => 'Shared topic';

  @override
  String get topicsEdit => 'Edit topic';

  @override
  String topicsAddTo(String subject) {
    return 'Add a topic to $subject';
  }

  @override
  String get topicsSubjectHint => 'e.g. Biology';

  @override
  String get topicsNameHint => 'e.g. Cell Biology';

  @override
  String get topicsKeywords => 'Keywords (optional)';

  @override
  String get topicsKeywordsHelp =>
      'Words that appear in this topic\'s questions, separated by commas. Without any, the topic\'s name is used.';

  @override
  String topicsDraftLabel(int count, String model) {
    return 'AI suggestion from $count of your questions ($model). Keep only what fits.';
  }

  @override
  String topicsDraftKeep(int count) {
    return 'Add $count topics';
  }

  @override
  String get issueUnrecognisedAnswer => 'Answer isn\'t an option (e.g. typed-in answer)';

  @override
  String sessionCorrectTypedAnswer(String answer) {
    return 'Correct answer: $answer';
  }

  @override
  String get sessionTypedAnswerLabel => 'Your answer';

  @override
  String get sessionTypedAnswerHelp => 'Type the answer, e.g. 12, 2.5 or 3142.';

  @override
  String get sessionTypedAnswerSave => 'Save answer';

  @override
  String resultYourTypedAnswer(String answer) {
    return 'Your answer: $answer';
  }

  @override
  String get fieldAnswerType => 'Answer type';

  @override
  String get answerTypeChoice => 'Options';

  @override
  String get answerTypeTyped => 'Typed answer';

  @override
  String get fieldTypedAnswer => 'Correct typed answer';

  @override
  String get fieldTypedAnswerHelp =>
      'Numbers match by value (2.5 = 2.50, never rounded); other answers must match exactly, ignoring spaces and case.';

  @override
  String sharedBankSource(String source) {
    return 'Shared bank · $source';
  }

  @override
  String get sharedBankReadOnly =>
      'From the shared bank (read-only), shared by the PrepLoop team with permission';

  @override
  String get questionExplanationTitle => 'Explanation';

  @override
  String get practiceIncludeShared => 'Include the shared bank';

  @override
  String get practiceIncludeSharedHint =>
      'Verified questions from papers the PrepLoop team shared (labelled)';

  @override
  String get repeatsSharedBank => 'Shared bank';

  @override
  String get repeatsSharedEmptyTitle => 'No shared papers yet';

  @override
  String get repeatsSharedEmptyMessage =>
      'Papers the PrepLoop team shares, with permission to share them, will appear here.';

  @override
  String repeatsSmallSample(int papers, int min) {
    return 'Small sample: $papers papers. Below $min papers, a topic seen 2 or 3 times can be chance.';
  }

  @override
  String get reviewVerifyClean => 'Verify all clean questions';

  @override
  String get reviewVerifyCleanTitle => 'Verify clean questions?';

  @override
  String get reviewVerifyCleanBody =>
      'Questions with an answer and no open issues are marked verified. Questions that need a look stay for review. You can still edit any question later.';

  @override
  String reviewVerifyCleanDone(int verified, int left) {
    return '$verified verified · $left still need review';
  }

  @override
  String repeatsBasisShared(int count) {
    return 'Based on $count shared papers';
  }

  @override
  String repeatsBasisSharedYears(int count, int first, int last) {
    return 'Based on $count shared papers ($first–$last)';
  }

  @override
  String get offlineSessionNote =>
      'Offline practice: answers are checked on this device and uploaded when you\'re back online.';

  @override
  String get offlineMarkingNote =>
      'Marked on this device: 1 point per correct answer. The server checks it again when it\'s uploaded.';

  @override
  String offlineReady(int count) {
    return '$count questions saved for offline practice';
  }

  @override
  String offlineToUpload(int count) {
    return '$count offline sessions waiting to upload';
  }

  @override
  String get issueOptionLabelUnclear => 'Option number unclear in the scan (check the order)';

  @override
  String get examSwitcherChoose => 'Choose exam';

  @override
  String get examSwitcherTooltip => 'Switch exam';

  @override
  String examSwitcherCurrent(String exam) {
    return 'Current exam: $exam';
  }

  @override
  String get examSwitcherTitle => 'Which exam?';

  @override
  String get examSwitcherHint =>
      'Papers, questions, practice and repeated models show only the exam you choose.';

  @override
  String get examSwitcherManage => 'Add or change exams';

  @override
  String examSwitcherShowing(String exam) {
    return 'Showing $exam';
  }

  @override
  String get suggestionsTitle => 'Suggest a feature';

  @override
  String get suggestionsIntro =>
      'Tell us what would make PrepLoop more useful, or what you\'d rather remove. The PrepLoop team reads every suggestion.';

  @override
  String get suggestionsCardMessage => 'Missing something, or is a feature in your way? Tell us.';

  @override
  String get suggestionsOpen => 'Write a suggestion';

  @override
  String get suggestionKindAdd => 'Add';

  @override
  String get suggestionKindRemove => 'Remove';

  @override
  String get suggestionKindChange => 'Change';

  @override
  String get suggestionKindOther => 'Other';

  @override
  String get suggestionField => 'Your suggestion';

  @override
  String get suggestionHintAdd => 'Which feature should PrepLoop add, and how would it help you?';

  @override
  String get suggestionHintRemove => 'Which feature should be removed, and why?';

  @override
  String get suggestionHintChange => 'What should work differently?';

  @override
  String get suggestionHintOther => 'Anything else you\'d like to tell us';

  @override
  String suggestionTooShort(int count) {
    return 'Write at least $count characters.';
  }

  @override
  String get suggestionSend => 'Send suggestion';

  @override
  String get suggestionPrivacy =>
      'Your suggestion is stored with your account so you can see its status here.';

  @override
  String get suggestionSent => 'Thanks! Your suggestion was sent.';

  @override
  String get suggestionTooMany => 'You\'ve sent many suggestions today. Please try again tomorrow.';

  @override
  String get suggestionOffline =>
      'Can\'t reach the PrepLoop server. Try again when you\'re online.';

  @override
  String get suggestionFailed => 'The suggestion couldn\'t be sent. Please try again.';

  @override
  String get suggestionsMine => 'Your suggestions';

  @override
  String get suggestionsNone => 'You haven\'t sent any suggestions yet.';

  @override
  String get suggestionStatusNew => 'Sent';

  @override
  String get suggestionStatusRead => 'Read by the team';

  @override
  String get suggestionStatusPlanned => 'Planned';

  @override
  String get suggestionStatusDone => 'Done';

  @override
  String get suggestionStatusDeclined => 'Not planned';

  @override
  String get syllabusTitle => 'Syllabus';

  @override
  String get syllabusMessage =>
      'Import the syllabus PDF again to add topics it lists that are missing here.';

  @override
  String get syllabusMissingTitle => 'Add your syllabus';

  @override
  String get syllabusMissingMessage =>
      'Import the exam\'s syllabus PDF: its subjects and topics are added here, each with a box to tick once you\'ve revised it.';

  @override
  String get syllabusImport => 'Import syllabus PDF';

  @override
  String get syllabusNothingFound =>
      'No topics could be read from this PDF. Add them by hand, or try a clearer copy.';

  @override
  String syllabusDraftLabel(int count, int pages) {
    return '$count topics read from the syllabus ($pages pages). Untick anything that isn\'t a topic.';
  }

  @override
  String syllabusUnreadable(int count) {
    return '$count pages were hard to read, so some topics may be missing.';
  }

  @override
  String get syllabusTruncated =>
      'The syllabus lists more topics than one import holds; import the rest separately.';

  @override
  String syllabusPromptTitle(String exam) {
    return 'Add the $exam syllabus first?';
  }

  @override
  String get syllabusPromptMessage =>
      'With the syllabus imported, PrepLoop lists every topic of the exam, sorts your questions into them and lets you tick each topic once revised. You can also add it later in Exams and topics.';

  @override
  String get syllabusPromptSkip => 'Skip for now';

  @override
  String topicsRevisedCount(int done, int total) {
    return '$done of $total topics revised';
  }

  @override
  String get topicRevised => 'Revised';

  @override
  String topicRevisedCheckbox(String topic) {
    return '$topic revised';
  }

  @override
  String get syllabusType => 'Type or paste syllabus';

  @override
  String get syllabusTypeHelp =>
      'No PDF? Write the syllabus here: subjects as headings, topics one per line or separated by commas. PrepLoop picks out the topics for you to check.';

  @override
  String get syllabusTypeField => 'Syllabus';

  @override
  String get syllabusTypeExample =>
      'Quantitative Aptitude:\nPercentage, Ratio, Time and Work\nReasoning:\n- Analogy\n- Coding-Decoding';

  @override
  String get syllabusTypeRead => 'Find topics';

  @override
  String get syllabusTypedNothingFound =>
      'No topics found. Put each topic on its own line, or write \"Subject: topic, topic\".';

  @override
  String syllabusTypedDraftLabel(int count) {
    return '$count topics found in what you wrote. Untick anything that isn\'t a topic.';
  }

  @override
  String get topicsSelect => 'Select';

  @override
  String get topicsSelectAll => 'All';

  @override
  String topicsSelected(int count) {
    return '$count selected';
  }

  @override
  String topicSelectCheckbox(String topic) {
    return 'Select $topic';
  }

  @override
  String topicsRemoveSelected(int count) {
    return 'Remove $count';
  }

  @override
  String topicsRemoveTitle(int count) {
    return 'Remove $count topics?';
  }

  @override
  String get topicsRemoveBody =>
      'Questions in these topics stay in your bank, without a topic. Revision ticks for them are removed.';

  @override
  String topicsRemoved(int count) {
    return '$count topics removed.';
  }

  @override
  String get syllabusTypedName => 'Typed syllabus';

  @override
  String syllabusSectionInfo(int count, String date) {
    return '$count topics · imported $date';
  }

  @override
  String get syllabusRemove => 'Remove this syllabus and its topics';

  @override
  String syllabusRemoveTitle(String name) {
    return 'Remove \"$name\"?';
  }

  @override
  String syllabusRemoveBody(int count) {
    return 'Its $count topics are removed too. Questions in them stay in your bank, without a topic.';
  }

  @override
  String get paperQuestionsTitle => 'Questions from your papers';

  @override
  String paperQuestionsTitleExam(String exam) {
    return 'Questions from your $exam papers';
  }

  @override
  String paperQuestionsCount(int count) {
    return '$count questions match';
  }

  @override
  String paperQuestionsNone(String text) {
    return 'No questions in your imported papers match \"$text\".';
  }

  @override
  String paperQuestionsSeeAll(int count) {
    return 'See all $count';
  }

  @override
  String get paperQuestionsOffline =>
      'Questions can\'t be searched without a connection to the PrepLoop server.';

  @override
  String get webSearchGoogle => 'Search on Google';

  @override
  String get webSearchLearnMore => 'Learn more on Google';

  @override
  String get webSearchOpenFailed => 'Couldn\'t open the browser.';

  @override
  String get quickAnswerTitle => 'Quick AI answer';

  @override
  String get quickAnswerOffer =>
      'Get a short AI answer from your own papers and notes. Your search and the matching parts of your material are sent to the AI service.';

  @override
  String get quickAnswerAsk => 'Ask AI';

  @override
  String get quickAnswerLoading => 'Asking the AI…';

  @override
  String quickAnswerCaution(String model) {
    return 'Written by AI ($model). It can be wrong: check it before relying on it, and use Google for deeper reading.';
  }

  @override
  String get quickAnswerTurnOff => 'Stop automatic AI answers';

  @override
  String get plusTitle => 'PrepLoop Plus';

  @override
  String get plusCardMessage =>
      'AI help on top of free studying: quick answers, explanations and practice questions.';

  @override
  String get plusOpen => 'See PrepLoop Plus';

  @override
  String get plusStatusTitle => 'Your plan';

  @override
  String plusActiveUntil(String date) {
    return 'Plus is active until $date';
  }

  @override
  String get plusInactive => 'Free plan';

  @override
  String get plusTestLabel => 'Test subscription: nothing was paid.';

  @override
  String get plusOperatorLabel => 'Given to you by the PrepLoop team.';

  @override
  String plusStartTest(int days) {
    return 'Start a $days-day test';
  }

  @override
  String get plusTestExplained =>
      'This server is for testing, so you can try Plus for free. Nothing is charged.';

  @override
  String get plusEndTest => 'End test subscription';

  @override
  String get plusNotForSaleYet => 'Plus can\'t be bought yet. It will be offered here soon.';

  @override
  String get plusIncludesTitle => 'What Plus includes';

  @override
  String get plusFeatureQuickAnswers =>
      'Quick AI answers when nothing in your papers matches a search';

  @override
  String get plusFeatureExplanations => 'AI explanations for questions from your papers';

  @override
  String get plusFeatureQuestions => 'AI practice questions on a question or a concept';

  @override
  String get plusFeaturePaperTopics => 'AI topic suggestions for a whole paper';

  @override
  String get plusFeatureTopicDraft => 'AI topic list for an exam from your papers';

  @override
  String plusAllowance(int count) {
    return 'Up to $count AI requests a month.';
  }

  @override
  String get plusAiLabelled => 'Everything AI writes is labelled as AI and can be wrong.';

  @override
  String get plusAiOffOnServer => 'AI isn\'t switched on on this server yet.';

  @override
  String get plusUsageTitle => 'AI use this month';

  @override
  String plusUsage(int used, int allowance) {
    return '$used of $allowance AI requests used';
  }

  @override
  String plusResets(String date) {
    return 'Starts again on $date';
  }

  @override
  String get plusFreeTitle => 'Free for everyone';

  @override
  String get plusFreeMessage =>
      'Importing papers, the question bank, practice, mock tests, revision, reminders and progress stay free.';

  @override
  String get plusLoadFailed => 'Plus details couldn\'t be loaded. Check your connection.';

  @override
  String get plusChangeFailed => 'That didn\'t work. Please try again.';

  @override
  String get searchAnswerTitle => 'AI answer from your material';

  @override
  String get searchAnswerLoading => 'Searching your material…';

  @override
  String get searchAnswerSources => 'Sources';

  @override
  String get searchAnswerUnchecked => 'Not checked by a reviewer';

  @override
  String get searchAnswerNotCovered =>
      'Your material doesn\'t cover this. A general AI answer instead:';

  @override
  String searchAnswerCaution(String model) {
    return 'Written by AI ($model) only from the sources above. It can still be wrong: open a source to check it.';
  }

  @override
  String get aiReadTitle => 'Read with AI';

  @override
  String get aiReadNothingFound =>
      'PrepLoop couldn\'t find questions in this paper. Its layout may be new to PrepLoop. AI can read the pages like a person would.';

  @override
  String get aiReadOffer =>
      'Questions missing or split wrongly? AI can read the pages like a person would.';

  @override
  String get aiReadButton => 'Read with AI';

  @override
  String get aiReadAgain => 'Read again with AI';

  @override
  String get aiReadPrivacy =>
      'The pages of this paper are sent to the AI service. Reviewed questions are kept.';

  @override
  String get aiReadConfirmTitle => 'Read this paper with AI?';

  @override
  String aiReadConfirmBody(int pages) {
    return 'AI will read the $pages pages of this paper (images and text are sent to the AI service). The questions PrepLoop found and you haven\'t reviewed are replaced; questions you verified or rejected are kept. Check every question against the source page before verifying it.';
  }

  @override
  String get aiReadStart => 'Read with AI';

  @override
  String get aiReadQueued => 'Waiting to start…';

  @override
  String aiReadProgress(int done, int total) {
    return 'AI is reading the paper: page $done of $total';
  }

  @override
  String get aiReadFailed => 'AI couldn\'t read this paper. Please try again later.';

  @override
  String aiReadDoneLabel(int count) {
    return '$count questions read by AI';
  }

  @override
  String get aiReadDoneMessage =>
      'AI can misread. Questions whose wording isn\'t on the page, and questions from scanned pages, are flagged: compare them with the source page before verifying.';

  @override
  String get questionReadByAi => 'Read by AI';

  @override
  String get issueAiTextMismatch => 'Wording differs from the page';

  @override
  String get issueAiReadUnchecked => 'Read by AI from a scan';

  @override
  String get searchAnswerFromPapers => 'From your papers';

  @override
  String get searchAnswerSimple => 'In simple words (AI)';

  @override
  String conceptsNoResultsPapersAbove(String text) {
    return 'None of your own concepts match \"$text\". Matches from your papers are shown above.';
  }

  @override
  String get answerTypeWritten => 'Written answer';

  @override
  String get fieldModelAnswer => 'Answer (as written in the notes)';

  @override
  String get fieldModelAnswerHelp =>
      'For Q&A notes and interview questions. These are revised as flashcards, not practised as multiple choice.';

  @override
  String get writtenFlashcardsTitle => 'Flashcards from these notes';

  @override
  String writtenFlashcardsMessage(int count) {
    return '$count verified questions have written answers. Revise them as flashcards: question in front, answer behind.';
  }

  @override
  String get writtenFlashcardsButton => 'Make flashcards';

  @override
  String get writtenFlashcardsNeedVerify =>
      'This paper has questions with written answers. Verify them to revise them as flashcards.';

  @override
  String get questionWrittenAnswer => 'Written answer';

  @override
  String get focusStartTitle => 'Start a focus session';

  @override
  String get focusMinutesLabel => 'How long?';

  @override
  String focusMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get focusWhatLabel => 'What will you work on?';

  @override
  String get focusDoRevision => 'Revise flashcards';

  @override
  String get focusDoPractice => 'Practise questions';

  @override
  String get focusDoStudy => 'Read your notes and papers';

  @override
  String get focusTip =>
      'One task only. Silence notifications and keep your phone away. After the session, take a 5-minute break: short breaks help you remember.';

  @override
  String focusBarLeft(String time) {
    return 'Focus · $time left';
  }

  @override
  String get focusEnd => 'End';

  @override
  String get focusEndTitle => 'End this focus session?';

  @override
  String focusEndBody(int minutes) {
    return 'You\'ve focused for $minutes min. That time still counts.';
  }

  @override
  String get focusKeepGoing => 'Keep going';

  @override
  String get focusDoneTitle => 'Focus session complete';

  @override
  String focusDoneBody(int minutes) {
    return 'You focused for $minutes minutes. Take a short break, then come back.';
  }

  @override
  String focusDoneGoal(int done, int goal) {
    return 'Today\'s goal reached: $done of $goal min.';
  }

  @override
  String focusDoneToday(int done, int goal) {
    return 'Today: $done of $goal min.';
  }

  @override
  String focusDoneTodayNoGoal(int done) {
    return 'Today: $done min focused.';
  }

  @override
  String get focusDoneOk => 'Back to studying';

  @override
  String momentumStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak',
      one: '1-day streak',
      zero: 'Start your streak today',
    );
    return '$_temp0';
  }

  @override
  String get momentumStreakRule =>
      'Any practice, revision or focus time counts. One rest day a week keeps a streak going.';

  @override
  String momentumGoal(int done, int goal) {
    return '$done of $goal min focused today';
  }

  @override
  String momentumNoGoal(int done) {
    return '$done min focused today';
  }

  @override
  String get momentumSetGoal => 'Set a daily goal';

  @override
  String momentumAnswered(int count) {
    return '$count questions answered';
  }

  @override
  String momentumReviewed(int count) {
    return '$count cards reviewed';
  }

  @override
  String get momentumStart => 'Start a focus session';

  @override
  String momentumRunning(String time) {
    return 'Focus running · $time left';
  }

  @override
  String get quoteAnother => 'Another';

  @override
  String conceptExamNote(String exam) {
    return 'Saved under $exam. Switch exams from Home.';
  }

  @override
  String importExamNote(String exam) {
    return 'Adds to $exam. To add to another exam, switch exams from Home.';
  }

  @override
  String get examsPreparingFor => 'Exams you\'re preparing for';

  @override
  String get conceptsNoneInTopic => 'No concepts here yet. Add one with the button above.';

  @override
  String get masteryNotStarted => 'Not started';

  @override
  String get masteryLearning => 'Learning';

  @override
  String get masteryPractising => 'Practising';

  @override
  String get masteryStrong => 'Strong';

  @override
  String get masteryMastered => 'Mastered';

  @override
  String masteryLevelLabel(String level) {
    return 'Level: $level';
  }

  @override
  String get masterySyllabusTitle => 'Your syllabus';

  @override
  String get masteryEditSyllabus => 'Edit syllabus';

  @override
  String get masteryAddSyllabus => 'Add syllabus';

  @override
  String get masteryNoSyllabus =>
      'Add your syllabus to see its subjects and topics here, each with your level.';

  @override
  String masterySubjectProgress(int strong, int total) {
    return '$strong of $total strong';
  }

  @override
  String masteryRules(int days, int answers, String strong, int mastered, String masteredPercent) {
    return 'Levels use the last $days days. Learning: under $answers answers. Strong: $strong correct or more. Mastered: $mastered+ answers at $masteredPercent or more, and marked revised.';
  }

  @override
  String get masteryOffline =>
      'Practice results need a connection, so levels use your flashcards and revised marks only.';

  @override
  String masteryNoAnswers(int days) {
    return 'No practice answers in the last $days days';
  }

  @override
  String get masteryNextNotStarted => 'Start with a few practice questions or a concept.';

  @override
  String masteryNextLearning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Answer $count more questions to see your level.',
      one: 'Answer 1 more question to see your level.',
    );
    return '$_temp0';
  }

  @override
  String masteryNextPractising(String percent) {
    return 'Aim for $percent correct, and keep its flashcards remembered.';
  }

  @override
  String masteryNextStrong(int answers, String percent) {
    return 'To master it: $answers+ answers at $percent correct, then mark it revised.';
  }

  @override
  String get masteryNextMastered => 'Mastered. Revise it now and then to keep it.';

  @override
  String get masteryPractise => 'Practise';

  @override
  String get masteryAddConcept => 'Add a concept';

  @override
  String get masteryUpdateFailed => 'Couldn\'t save that. Check your connection and try again.';
}
