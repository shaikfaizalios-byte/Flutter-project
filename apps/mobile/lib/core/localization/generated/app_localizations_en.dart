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
}
