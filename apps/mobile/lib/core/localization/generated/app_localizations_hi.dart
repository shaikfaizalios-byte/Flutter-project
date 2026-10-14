// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'PrepLoop';

  @override
  String get navHome => 'होम';

  @override
  String get navStudy => 'अध्ययन';

  @override
  String get navPractice => 'अभ्यास';

  @override
  String get navProgress => 'प्रगति';

  @override
  String get navProfile => 'प्रोफ़ाइल';

  @override
  String get homeHeadline => 'आपका अध्ययन चक्र';

  @override
  String get homeTodayTitle => 'आज मुझे क्या पढ़ना चाहिए?';

  @override
  String get homeTodayEmpty =>
      'अभी कोई अध्ययन योजना नहीं है। कॉन्सेप्ट जोड़ने या प्रश्न-पत्र आयात करने के बाद आज के सुझाए गए कार्य यहाँ दिखेंगे।';

  @override
  String get homeWeakTitle => 'मैं किन विषयों में कमज़ोर हूँ?';

  @override
  String get homeWeakEmpty =>
      'अभी पर्याप्त अभ्यास डेटा नहीं है। किसी विषय में पर्याप्त प्रश्न हल करने के बाद ही कमज़ोर विषय पहचाने जाते हैं।';

  @override
  String get homeUpcomingTitle => 'आगे क्या है?';

  @override
  String get homeUpcomingEmpty => 'कोई दोहराव या लक्ष्य निर्धारित नहीं है।';

  @override
  String get studyTitle => 'अध्ययन';

  @override
  String get conceptsSearchHint => 'कॉन्सेप्ट खोजें';

  @override
  String get conceptsEmptyTitle => 'अभी कोई कॉन्सेप्ट नहीं है';

  @override
  String get conceptsEmptyMessage =>
      'जिन विषयों और नोट्स को आप पढ़ रहे हैं, उन्हें जोड़ें। ये इसी डिवाइस पर सहेजे जाते हैं और ऑफ़लाइन भी काम करते हैं।';

  @override
  String conceptsNoResults(String query) {
    return '\"$query\" से मेल खाता कोई कॉन्सेप्ट नहीं मिला।';
  }

  @override
  String get conceptsLoadError => 'आपके कॉन्सेप्ट लोड नहीं हो सके।';

  @override
  String get conceptsAdd => 'कॉन्सेप्ट जोड़ें';

  @override
  String get conceptArchive => 'संग्रहित करें';

  @override
  String get conceptArchived => 'कॉन्सेप्ट संग्रहित किया गया';

  @override
  String get conceptSaved => 'कॉन्सेप्ट सहेजा गया';

  @override
  String get undo => 'पूर्ववत करें';

  @override
  String conceptOptions(String title) {
    return '$title के विकल्प';
  }

  @override
  String get conceptFormTitle => 'नया कॉन्सेप्ट';

  @override
  String get fieldExam => 'परीक्षा';

  @override
  String get fieldTitle => 'शीर्षक';

  @override
  String get fieldSubject => 'विषय';

  @override
  String get fieldSubjectHint => 'जैसे: मात्रात्मक अभियोग्यता';

  @override
  String get fieldTopic => 'टॉपिक';

  @override
  String get fieldTopicHint => 'जैसे: प्रतिशत';

  @override
  String get fieldSubtopic => 'उप-टॉपिक (वैकल्पिक)';

  @override
  String get fieldContentLanguage => 'सामग्री की भाषा';

  @override
  String get fieldTags => 'टैग (वैकल्पिक)';

  @override
  String get fieldTagsHint => 'टैग को कॉमा से अलग करें';

  @override
  String get fieldSourceReference => 'स्रोत (वैकल्पिक)';

  @override
  String get fieldSourceReferenceHint => 'जैसे: पुस्तक, पृष्ठ या प्रश्न-पत्र';

  @override
  String get fieldNotes => 'नोट्स (वैकल्पिक)';

  @override
  String get save => 'सहेजें';

  @override
  String get saveFailed => 'कॉन्सेप्ट सहेजा नहीं जा सका। कृपया फिर से कोशिश करें।';

  @override
  String get validationRequired => 'यह फ़ील्ड आवश्यक है।';

  @override
  String validationTooLong(int max) {
    return 'कृपया इसे $max अक्षरों या उससे कम में लिखें।';
  }

  @override
  String validationTooManyTags(int max) {
    return 'अधिकतम $max टैग का उपयोग करें।';
  }

  @override
  String get practiceTitle => 'अभ्यास';

  @override
  String get practiceEmptyTitle => 'अभ्यास सत्र';

  @override
  String get practiceEmptyMessage =>
      'प्रश्न उपलब्ध होने पर विषय-वार अभ्यास और समयबद्ध मॉक टेस्ट यहाँ दिखेंगे। यह अनुभाग आगामी अपडेट में उपलब्ध होगा।';

  @override
  String get progressTitle => 'प्रगति';

  @override
  String get progressEmptyTitle => 'अभी कोई प्रगति डेटा नहीं है';

  @override
  String get progressEmptyMessage =>
      'अभ्यास शुरू करने के बाद आपकी सटीकता और दोहराव का इतिहास यहाँ दिखेगा।';

  @override
  String get settingsTitle => 'प्रोफ़ाइल और सेटिंग्स';

  @override
  String get settingsLanguage => 'ऐप की भाषा';

  @override
  String get languageSystem => 'सिस्टम';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get settingsTheme => 'थीम';

  @override
  String get themeSystem => 'सिस्टम';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeDark => 'डार्क';

  @override
  String get settingsServer => 'सर्वर कनेक्शन';

  @override
  String get serverChecking => 'जाँच हो रही है…';

  @override
  String serverOnline(String version) {
    return 'कनेक्टेड · API $version';
  }

  @override
  String get serverOffline => 'PrepLoop सर्वर से संपर्क नहीं हो पा रहा है।';

  @override
  String get serverOfflineHint => 'ऑफ़लाइन काम करने वाली सुविधाएँ प्रभावित नहीं होतीं।';

  @override
  String get retry => 'फिर से कोशिश करें';

  @override
  String get settingsAbout => 'जानकारी';

  @override
  String aboutBuild(String appName, String flavor) {
    return '$appName · $flavor बिल्ड';
  }

  @override
  String get notFoundTitle => 'पेज नहीं मिला';

  @override
  String get goHome => 'होम पर जाएँ';

  @override
  String onboardingStep(int step, int total) {
    return 'चरण $step / $total';
  }

  @override
  String get onboardingSkipSetup => 'सेटअप छोड़ें';

  @override
  String get back => 'पीछे';

  @override
  String get next => 'आगे';

  @override
  String get onboardingFinish => 'पढ़ाई शुरू करें';

  @override
  String get onboardingWelcomeTitle => 'PrepLoop में आपका स्वागत है';

  @override
  String get onboardingWelcomeBody =>
      'आइए आपकी तैयारी सेट करें। हर चरण वैकल्पिक है, और आप बाद में प्रोफ़ाइल में अपने उत्तर बदल सकते हैं। आपके उत्तर इसी डिवाइस पर सहेजे जाते हैं।';

  @override
  String get onboardingExamTitle => 'आप किस परीक्षा की तैयारी कर रहे हैं?';

  @override
  String get onboardingExamHint => 'एक या दोनों चुनें।';

  @override
  String get onboardingDateTitle => 'आपकी परीक्षा कब है?';

  @override
  String get onboardingDateHint =>
      'अगर आपको तारीख पता है, तो PrepLoop उलटी गिनती दिखाएगा। आप इसे छोड़ सकते हैं।';

  @override
  String get onboardingDailyTitle => 'आप रोज़ कितना समय पढ़ाई कर सकते हैं?';

  @override
  String get onboardingDailyHint =>
      'व्यावहारिक समय चुनें। कभी-कभार लंबी पढ़ाई से बेहतर है रोज़ थोड़ा पढ़ना।';

  @override
  String get onboardingReminderTitle => 'PrepLoop आपको पढ़ाई की याद कब दिलाए?';

  @override
  String get onboardingReminderHint =>
      'प्रोफ़ाइल में रोज़ का रिमाइंडर चालू करें। PrepLoop सूचना की अनुमति तभी माँगेगा।';

  @override
  String get chooseDate => 'तारीख चुनें';

  @override
  String get chooseTime => 'समय चुनें';

  @override
  String get clear => 'हटाएँ';

  @override
  String get notSet => 'सेट नहीं';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get done => 'हो गया';

  @override
  String durationMinutes(int minutes) {
    return '$minutes मिनट';
  }

  @override
  String durationHours(int hours) {
    return '$hours घंटे';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours घंटे $minutes मिनट';
  }

  @override
  String get settingsStudyPlan => 'अध्ययन योजना';

  @override
  String get fieldExams => 'परीक्षाएँ';

  @override
  String get examsNotChosen => 'नहीं चुनी गई';

  @override
  String get fieldExamDate => 'परीक्षा की तारीख';

  @override
  String get fieldDailyStudy => 'रोज़ाना पढ़ाई का समय';

  @override
  String get fieldReminder => 'रिमाइंडर का समय';

  @override
  String get settingsLicences => 'ओपन-सोर्स लाइसेंस';

  @override
  String get homeChooseExamTitle => 'अपनी परीक्षा चुनें';

  @override
  String get homeChooseExamMessage =>
      'PrepLoop को अपने अनुसार बनाने के लिए SSC CGL, SSC CHSL या दोनों चुनें।';

  @override
  String get homeChooseExamAction => 'परीक्षा चुनें';

  @override
  String homeExamCountdown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन बाकी',
      one: '1 दिन बाकी',
      zero: 'आपकी परीक्षा आज है',
    );
    return '$_temp0';
  }

  @override
  String get homeExamPassed =>
      'आपकी परीक्षा की तारीख बीत चुकी है। आप इसे प्रोफ़ाइल में बदल सकते हैं।';

  @override
  String homeExamOn(String date) {
    return 'परीक्षा की तारीख: $date';
  }

  @override
  String homeConceptCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आपके $count कॉन्सेप्ट सहेजे गए हैं।',
      one: 'आपका 1 कॉन्सेप्ट सहेजा गया है।',
      zero: 'आपने अभी तक कोई कॉन्सेप्ट नहीं जोड़ा है।',
    );
    return '$_temp0';
  }

  @override
  String homeDailyGoal(String duration) {
    return 'रोज़ाना पढ़ाई का लक्ष्य: $duration';
  }

  @override
  String get homeOpenConcepts => 'कॉन्सेप्ट खोलें';

  @override
  String get homeSetExamDate => 'उलटी गिनती देखने के लिए प्रोफ़ाइल में परीक्षा की तारीख सेट करें।';

  @override
  String get conceptDetailsTitle => 'कॉन्सेप्ट';

  @override
  String get conceptEdit => 'संपादित करें';

  @override
  String get conceptEditTitle => 'कॉन्सेप्ट संपादित करें';

  @override
  String get conceptUnarchive => 'वापस लाएँ';

  @override
  String get conceptRestored => 'कॉन्सेप्ट वापस लाया गया';

  @override
  String get conceptDelete => 'हटाएँ';

  @override
  String get conceptDeleteTitle => 'यह कॉन्सेप्ट हटाएँ?';

  @override
  String conceptDeleteMessage(String title) {
    return '\"$title\" इस डिवाइस से हमेशा के लिए हटा दिया जाएगा। इसे पूर्ववत नहीं किया जा सकता।';
  }

  @override
  String get conceptDeleted => 'कॉन्सेप्ट हटाया गया';

  @override
  String get conceptNotFound => 'यह कॉन्सेप्ट अब मौजूद नहीं है।';

  @override
  String get conceptLoadError => 'यह कॉन्सेप्ट लोड नहीं हो सका।';

  @override
  String get conceptArchivedBanner => 'यह कॉन्सेप्ट संग्रहित है और आपकी मुख्य सूची में नहीं दिखता।';

  @override
  String conceptCreatedOn(String date) {
    return 'बनाया गया $date';
  }

  @override
  String conceptUpdatedOn(String date) {
    return 'अपडेट किया गया $date';
  }

  @override
  String get conceptMoreActions => 'और विकल्प';

  @override
  String get filterExam => 'परीक्षा';

  @override
  String get filterSubject => 'विषय';

  @override
  String get filterTopic => 'टॉपिक';

  @override
  String get filterAll => 'सभी';

  @override
  String get filterArchived => 'संग्रहित';

  @override
  String get filterClear => 'फ़िल्टर हटाएँ';

  @override
  String filterBy(String label) {
    return '$label से फ़िल्टर करें';
  }

  @override
  String get conceptsNoFilterResults => 'इन फ़िल्टर से मेल खाता कोई कॉन्सेप्ट नहीं मिला।';

  @override
  String get conceptsArchivedEmpty => 'कोई संग्रहित कॉन्सेप्ट नहीं है।';

  @override
  String get documentsTitle => 'आयात किए गए प्रश्न-पत्र';

  @override
  String get documentsImport => 'PDF आयात करें';

  @override
  String get documentsEmptyTitle => 'अभी कोई प्रश्न-पत्र आयात नहीं किया गया';

  @override
  String get documentsEmptyMessage =>
      'पिछले वर्षों के प्रश्न-पत्र या अध्ययन PDF आयात करें। PrepLoop हर पृष्ठ का टेक्स्ट पढ़ता है और जिन पृष्ठों को वह भरोसे से नहीं पढ़ पाता, उन्हें जाँच के लिए चिह्नित करता है।';

  @override
  String get documentsOfflineTitle => 'PrepLoop सर्वर से संपर्क नहीं हो पा रहा है';

  @override
  String get documentsOfflineMessage =>
      'प्रश्न-पत्र आयात करने के लिए इंटरनेट कनेक्शन चाहिए। आपके कॉन्सेप्ट ऑफ़लाइन भी काम करते हैं।';

  @override
  String get documentsLoadError => 'आपके आयात किए गए प्रश्न-पत्र लोड नहीं हो सके।';

  @override
  String get documentStatusQueued => 'प्रोसेस होने की प्रतीक्षा में';

  @override
  String documentStatusProcessing(int done, int total) {
    return 'पृष्ठ $done / $total पढ़ा जा रहा है';
  }

  @override
  String get documentStatusCompleted => 'तैयार';

  @override
  String get documentStatusFailed => 'प्रोसेसिंग विफल रही';

  @override
  String documentPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पृष्ठ',
      one: '1 पृष्ठ',
    );
    return '$_temp0';
  }

  @override
  String documentNeedsReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पृष्ठों की जाँच ज़रूरी है',
      one: '1 पृष्ठ की जाँच ज़रूरी है',
    );
    return '$_temp0';
  }

  @override
  String get documentErrorTimeout => 'इस दस्तावेज़ को प्रोसेस करने में बहुत समय लगा।';

  @override
  String get documentErrorSourceMissing => 'मूल फ़ाइल अब उपलब्ध नहीं है।';

  @override
  String get documentErrorGeneric => 'इस दस्तावेज़ को पढ़ते समय कुछ गड़बड़ हो गई।';

  @override
  String documentOptions(String filename) {
    return '$filename के विकल्प';
  }

  @override
  String get documentDeleteTitle => 'यह प्रश्न-पत्र हटाएँ?';

  @override
  String documentDeleteMessage(String filename) {
    return '\"$filename\" और उससे निकाला गया टेक्स्ट सर्वर से हमेशा के लिए हटा दिया जाएगा।';
  }

  @override
  String get documentDeleted => 'प्रश्न-पत्र हटाया गया';

  @override
  String importSheetTitle(String filename) {
    return '\"$filename\" आयात करें';
  }

  @override
  String get importUpload => 'अपलोड करें';

  @override
  String importUploading(String filename) {
    return '$filename अपलोड हो रहा है…';
  }

  @override
  String get importDone => 'अपलोड पूरा हुआ। प्रोसेसिंग शुरू हो गई है।';

  @override
  String get uploadErrorTooLarge => 'यह फ़ाइल अनुमत आकार से बड़ी है।';

  @override
  String get uploadErrorNotPdf => 'केवल PDF फ़ाइलें आयात की जा सकती हैं।';

  @override
  String get uploadErrorEncrypted =>
      'यह PDF पासवर्ड से सुरक्षित है। पासवर्ड हटाकर फिर से कोशिश करें।';

  @override
  String get uploadErrorInvalid => 'यह फ़ाइल खराब है या मान्य PDF नहीं है।';

  @override
  String get uploadErrorTooManyPages => 'इस PDF में बहुत अधिक पृष्ठ हैं।';

  @override
  String get uploadErrorEmpty => 'यह फ़ाइल खाली है।';

  @override
  String get uploadErrorRateLimited =>
      'आपने हाल ही में कई फ़ाइलें अपलोड की हैं। कृपया कुछ देर बाद फिर से कोशिश करें।';

  @override
  String get uploadErrorOffline => 'अपलोड नहीं हो सका: सर्वर से कनेक्शन नहीं है।';

  @override
  String get uploadErrorGeneric => 'अपलोड विफल रहा। कृपया फिर से कोशिश करें।';

  @override
  String get issueMissingAnswer => 'उत्तर नहीं मिला';

  @override
  String get issueIncompleteOptions => 'विकल्प अधूरे हैं';

  @override
  String get issueEmptyOption => 'एक विकल्प खाली है';

  @override
  String get issueDuplicateNumber => 'प्रश्न संख्या दोहराई गई है';

  @override
  String get issueAmbiguousBoundary => 'प्रश्न की सीमा स्पष्ट नहीं है';

  @override
  String get issueImageDependent => 'मूल चित्र की आवश्यकता है';

  @override
  String get issueRepeatedOptionLabels => 'अतिरिक्त विकल्प मिले (संभवतः दूसरी भाषा में)';

  @override
  String get issueAnswerNotInOptions => 'उत्तर विकल्पों से मेल नहीं खाता';

  @override
  String get issueConflictingAnswers => 'अलग-अलग उत्तर मिले';

  @override
  String get issueSourcePageNeedsReview => 'स्रोत पृष्ठ पढ़ने में कठिन था';

  @override
  String get issueNoQuestionsFound => 'कोई प्रश्न नहीं मिला';

  @override
  String get issueNumberingGaps => 'कुछ प्रश्न संख्याएँ गायब हैं';

  @override
  String get issueAnswerKeyUnmatched =>
      'उत्तर कुंजी में ऐसी संख्याएँ हैं जो प्रश्न-पत्र में नहीं हैं';

  @override
  String get issueAnswerKeyAmbiguous =>
      'हर खंड में क्रमांक फिर से शुरू होता है, इसलिए उत्तर जाँच के दौरान सेट करें';

  @override
  String get issueCountMismatch => 'प्रश्नों की संख्या आधिकारिक प्रारूप से अलग है';

  @override
  String get issueSectionCountMismatch => 'किसी खंड की संख्या आधिकारिक प्रारूप से अलग है';

  @override
  String get issueOther => 'जाँच ज़रूरी है';

  @override
  String get reviewTitle => 'प्रश्नों की जाँच';

  @override
  String get reviewQuestions => 'प्रश्नों की जाँच करें';

  @override
  String reviewSummaryVerified(int count) {
    return '$count सत्यापित';
  }

  @override
  String reviewSummaryAttention(int count) {
    return '$count पर ध्यान ज़रूरी';
  }

  @override
  String reviewSummaryMissingAnswers(int count) {
    return '$count बिना उत्तर के';
  }

  @override
  String reviewFormat(String name) {
    return 'प्रारूप: $name';
  }

  @override
  String get reviewFormatUnknown =>
      'कोई सत्यापित प्रारूप जुड़ा नहीं है, इसलिए प्रश्न-संख्या की जाँच नहीं होती।';

  @override
  String get reviewReparse => 'फिर से पार्स करें';

  @override
  String get reviewReparsed => 'प्रश्न फिर से पार्स किए गए। आपके जाँचे गए प्रश्न सुरक्षित रखे गए।';

  @override
  String get reviewSegmentationPending => 'टेक्स्ट निकाले जाने के बाद प्रश्न यहाँ दिखेंगे।';

  @override
  String get reviewSegmentationFailed => 'इस प्रश्न-पत्र से प्रश्न नहीं निकाले जा सके।';

  @override
  String get reviewNoQuestions => 'इस दृश्य में कोई प्रश्न नहीं है।';

  @override
  String get filterAllQuestions => 'सभी';

  @override
  String get filterNeedsAttention => 'ध्यान ज़रूरी';

  @override
  String get filterVerified => 'सत्यापित';

  @override
  String get filterRejected => 'अस्वीकृत';

  @override
  String documentQuestionsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रश्न मिले',
      one: '1 प्रश्न मिला',
      zero: 'कोई प्रश्न नहीं मिला',
    );
    return '$_temp0';
  }

  @override
  String questionNumberLabel(int number) {
    return 'प्र.$number';
  }

  @override
  String questionSource(String filename, int page) {
    return '$filename, पृष्ठ $page से';
  }

  @override
  String get questionLabelSource => 'आपकी PDF से';

  @override
  String get questionLabelAi => 'AI द्वारा बनाया गया';

  @override
  String get questionStatusVerified => 'सत्यापित';

  @override
  String get questionStatusRejected => 'अस्वीकृत';

  @override
  String get questionStatusUnverified => 'जाँच नहीं हुई';

  @override
  String get questionTitle => 'प्रश्न';

  @override
  String get fieldStem => 'प्रश्न का टेक्स्ट';

  @override
  String get fieldOptions => 'विकल्प';

  @override
  String fieldOption(String label) {
    return 'विकल्प $label';
  }

  @override
  String get addOption => 'विकल्प जोड़ें';

  @override
  String get fieldCorrectAnswer => 'सही उत्तर';

  @override
  String get answerNotSet => 'सेट नहीं';

  @override
  String get fieldExplanation => 'व्याख्या (वैकल्पिक)';

  @override
  String get topicSuggested => 'सुझाया गया टॉपिक। प्रश्न स्वीकृत करने पर इसकी पुष्टि हो जाती है।';

  @override
  String get topicNone => 'कोई टॉपिक नहीं';

  @override
  String get fieldImageDependent => 'मूल चित्र या छवि की आवश्यकता है';

  @override
  String sharedPassage(int first, int last) {
    return 'साझा गद्यांश (प्र.$first से प्र.$last)';
  }

  @override
  String get sourcePageText => 'स्रोत पृष्ठ का टेक्स्ट';

  @override
  String get sourcePageLoadError => 'पृष्ठ का टेक्स्ट लोड नहीं हो सका।';

  @override
  String get approve => 'स्वीकृत करें';

  @override
  String get reject => 'अस्वीकार करें';

  @override
  String get saved => 'सहेजा गया';

  @override
  String get questionApproved => 'प्रश्न स्वीकृत किया गया';

  @override
  String get questionRejected => 'प्रश्न अस्वीकार किया गया';

  @override
  String get cannotVerify => 'स्वीकृत करने से पहले सूचीबद्ध समस्याएँ ठीक करें।';

  @override
  String get openIssues => 'जाँचने योग्य समस्याएँ';

  @override
  String get bankTitle => 'प्रश्न बैंक';

  @override
  String get bankSearchHint => 'प्रश्न खोजें';

  @override
  String get bankEmptyTitle => 'अभी कोई प्रश्न नहीं है';

  @override
  String get bankEmptyMessage =>
      'अध्ययन में, फिर आयात किए गए प्रश्न-पत्र में जाकर पिछले वर्ष का प्रश्न-पत्र आयात करें। उसके प्रश्न जाँच के लिए यहाँ दिखेंगे, और जाँचे गए प्रश्नों का अभ्यास किया जा सकता है।';

  @override
  String get bankLoadError => 'प्रश्न लोड नहीं हो सके।';

  @override
  String get practiceHubTitle => 'अभ्यास';

  @override
  String get practiceStartTitle => 'प्रश्नों का अभ्यास';

  @override
  String get practiceStartMessage =>
      'समय सीमा नहीं। हर उत्तर के बाद आप देखेंगे कि वह सही है या नहीं।';

  @override
  String get practiceStart => 'अभ्यास शुरू करें';

  @override
  String get practiceSetupTitle => 'अभ्यास सेट करें';

  @override
  String get practiceMixed => 'मिश्रित (सभी विषय)';

  @override
  String get practiceSubject => 'विषय';

  @override
  String get practiceTopic => 'टॉपिक (वैकल्पिक)';

  @override
  String get practiceTopicAny => 'कोई भी टॉपिक';

  @override
  String get practiceCount => 'प्रश्नों की संख्या';

  @override
  String get practiceIncludeUnverified => 'जिन प्रश्नों की जाँच नहीं हुई, उन्हें भी शामिल करें';

  @override
  String get practiceIncludeUnverifiedHint =>
      'इन पर लेबल लगा होता है, और इनके उत्तरों में निकालने की गलतियाँ हो सकती हैं।';

  @override
  String get practiceNoQuestions =>
      'कोई जाँचा हुआ प्रश्न मेल नहीं खाता। प्रश्न बैंक में प्रश्न स्वीकृत करें, या बिना जाँचे प्रश्न शामिल करें।';

  @override
  String get mockTestsTitle => 'मॉक टेस्ट';

  @override
  String get mockTestsMessage => 'समयबद्ध टेस्ट, केवल सत्यापित आधिकारिक परीक्षा प्रारूपों से बने।';

  @override
  String get mockTestsNone => 'अभी कोई सत्यापित परीक्षा प्रारूप उपलब्ध नहीं है।';

  @override
  String mockTestDetails(int questions, int minutes) {
    return '$questions प्रश्न · $minutes मिनट';
  }

  @override
  String mockNegative(String marks) {
    return 'हर गलत उत्तर पर −$marks';
  }

  @override
  String get mockStart => 'मॉक टेस्ट शुरू करें';

  @override
  String get mockUnavailable => 'अभी पर्याप्त जाँचे हुए प्रश्न नहीं हैं:';

  @override
  String mockSectionShort(String subject, int available, int needed) {
    return '$subject: $needed में से $available';
  }

  @override
  String get mockConfirmTitle => 'मॉक टेस्ट शुरू करें?';

  @override
  String get mockConfirmMessage =>
      'टाइमर अभी शुरू होगा और ऐप बंद करने पर भी चलता रहेगा। समय पूरा होने पर टेस्ट अपने-आप सबमिट हो जाएगा।';

  @override
  String get reviewToolsTitle => 'दोहराव';

  @override
  String get bookmarksTitle => 'बुकमार्क';

  @override
  String get bookmarksEmpty => 'कोई बुकमार्क किया हुआ प्रश्न नहीं है।';

  @override
  String get incorrectTitle => 'दोबारा देखने योग्य प्रश्न';

  @override
  String get incorrectEmpty => 'दोबारा देखने के लिए कोई गलत उत्तर नहीं है।';

  @override
  String get questionBankOpen => 'प्रश्न बैंक';

  @override
  String get historyTitle => 'हाल के सत्र';

  @override
  String get historyEmpty => 'आपके अभ्यास सत्र यहाँ दिखेंगे।';

  @override
  String get historyPractice => 'अभ्यास';

  @override
  String historyMock(String name) {
    return 'मॉक: $name';
  }

  @override
  String get historyInProgress => 'जारी है';

  @override
  String historyScore(String score, String max) {
    return '$score / $max';
  }

  @override
  String sessionQuestionOf(int current, int total) {
    return 'प्रश्न $current / $total';
  }

  @override
  String get sessionNotReviewed => 'जाँच नहीं हुई';

  @override
  String get sessionPrevious => 'पिछला';

  @override
  String get sessionNext => 'अगला';

  @override
  String get sessionSubmit => 'सबमिट करें';

  @override
  String get sessionFinish => 'समाप्त करें';

  @override
  String get sessionCorrect => 'सही';

  @override
  String get sessionIncorrect => 'गलत';

  @override
  String sessionCorrectAnswer(String label) {
    return 'सही उत्तर: ($label)';
  }

  @override
  String get sessionSavedOffline => 'इस डिवाइस पर सहेजा गया। ऑनलाइन होने पर भेज दिया जाएगा।';

  @override
  String get sessionFeedbackOffline => 'ऑनलाइन होने पर परिणाम दिखेगा।';

  @override
  String get sessionSubmitTitle => 'अभी सबमिट करें?';

  @override
  String sessionUnanswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रश्नों के उत्तर नहीं दिए गए हैं।',
      one: '1 प्रश्न का उत्तर नहीं दिया गया है।',
      zero: 'सभी प्रश्नों के उत्तर दिए गए हैं।',
    );
    return '$_temp0';
  }

  @override
  String get sessionTimeUp => 'समय समाप्त। आपके सहेजे गए उत्तर सबमिट कर दिए गए।';

  @override
  String sessionTimeLeft(String time) {
    return 'शेष समय $time';
  }

  @override
  String get sessionQuestionRemoved => 'यह प्रश्न प्रश्न बैंक से हटा दिया गया था।';

  @override
  String get sessionLoadError => 'यह सत्र लोड नहीं हो सका।';

  @override
  String get sessionOfflineOpen =>
      'सत्र खोलने के लिए कनेक्शन चाहिए। सत्र के दौरान कनेक्शन टूटने पर आपके उत्तर इस डिवाइस पर सहेजे जाते हैं।';

  @override
  String get sessionPalette => 'सभी प्रश्न';

  @override
  String get sessionBookmark => 'बुकमार्क करें';

  @override
  String get sessionRemoveBookmark => 'बुकमार्क हटाएँ';

  @override
  String get sessionSubmitFailed =>
      'सबमिट नहीं हो सका। आपके उत्तर सहेजे गए हैं; ऑनलाइन होने पर फिर कोशिश करें।';

  @override
  String get resultTitle => 'परिणाम';

  @override
  String resultScore(String score, String max) {
    return '$max में से $score';
  }

  @override
  String resultAccuracy(int percent) {
    return 'सटीकता $percent%';
  }

  @override
  String get resultAccuracyNone => 'किसी प्रश्न का उत्तर नहीं दिया गया';

  @override
  String resultTime(String time) {
    return 'लगा समय $time';
  }

  @override
  String resultCounts(int correct, int wrong, int unattempted) {
    return '$correct सही · $wrong गलत · $unattempted छोड़े गए';
  }

  @override
  String get resultHowScored => 'यह स्कोर कैसे गिना गया';

  @override
  String get resultSections => 'खंड के अनुसार';

  @override
  String get resultTopics => 'टॉपिक के अनुसार';

  @override
  String get resultReviewAnswers => 'उत्तर देखें';

  @override
  String resultYourAnswer(String label) {
    return 'आपका उत्तर: ($label)';
  }

  @override
  String get resultNotAnswered => 'उत्तर नहीं दिया';

  @override
  String get resultSubmittedTimeUp => 'समय पूरा होने पर अपने-आप सबमिट हुआ।';

  @override
  String get revisionTitle => 'दोहराव';

  @override
  String get revisionDueTitle => 'आज दोहराने के लिए';

  @override
  String revisionDueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'दोहराने के लिए $count कार्ड',
      one: 'दोहराने के लिए 1 कार्ड',
    );
    return '$_temp0';
  }

  @override
  String revisionOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इनमें से $count की तारीख निकल चुकी है',
      one: 'इनमें से 1 की तारीख निकल चुकी है',
    );
    return '$_temp0';
  }

  @override
  String get revisionStart => 'दोहराव शुरू करें';

  @override
  String get revisionNothingDue => 'आज दोहराने के लिए कुछ नहीं है।';

  @override
  String revisionNextReview(String when) {
    return 'अगला दोहराव: $when';
  }

  @override
  String get revisionUpcomingTitle => 'अगले 7 दिन';

  @override
  String get revisionScheduleTitle => 'दोहराव की समय-सारिणी';

  @override
  String revisionLadder(String days) {
    return 'कार्ड जोड़ने के बाद दिन $days पर दोहराएँ';
  }

  @override
  String get revisionLadderExplanation =>
      'याद रहने पर कार्ड अगले दोहराव-दिन पर जाता है; आखिरी दिन के बाद अंतराल दोगुना होता रहता है। कठिन लगने पर छोटे अंतराल पर फिर आता है। भूल जाने पर कार्ड पहले दिन से फिर शुरू होता है।';

  @override
  String get revisionEditSchedule => 'समय-सारिणी बदलें';

  @override
  String get revisionScheduleHelp =>
      'कार्ड जोड़ने के कितने दिन बाद वह दोहराव के लिए लौटे। बदलाव आगे के दोहराव पर लागू होते हैं; कार्डों की मौजूदा तारीखें वही रहती हैं।';

  @override
  String get revisionScheduleField => 'दोहराव के दिन';

  @override
  String get revisionScheduleFieldHint => 'उदाहरण: 1, 4, 7';

  @override
  String revisionScheduleInvalid(int maxSteps, int maxDay) {
    return '1 से $maxDay के बीच 1 से $maxSteps अलग-अलग दिन लिखें।';
  }

  @override
  String get revisionScheduleReset => '1, 4, 7 रखें';

  @override
  String get revisionScheduleSaved => 'दोहराव की समय-सारिणी सहेजी गई।';

  @override
  String revisionAllCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सभी कार्ड ($count)',
      one: '1 कार्ड',
    );
    return '$_temp0';
  }

  @override
  String get revisionEmptyTitle => 'अभी कोई फ्लैशकार्ड नहीं';

  @override
  String get revisionEmptyMessage =>
      'किसी कॉन्सेप्ट के विवरण पेज से उसे दोहराव में जोड़ें, या अभ्यास → बुकमार्क या फिर से देखने वाले प्रश्नों से प्रश्न जोड़ें।';

  @override
  String get revisionLoadError => 'आपके फ्लैशकार्ड लोड नहीं हो सके।';

  @override
  String get revisionSaveError => 'सहेजा नहीं जा सका। कृपया फिर से कोशिश करें।';

  @override
  String get revisionRemove => 'हटाएँ';

  @override
  String get revisionRemoved => 'दोहराव से हटा दिया गया।';

  @override
  String get revisionDueToday => 'आज';

  @override
  String get revisionDueTomorrow => 'कल';

  @override
  String revisionDueInDays(int days) {
    return '$days दिन में';
  }

  @override
  String revisionOverdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन देर',
      one: '1 दिन देर',
    );
    return '$_temp0';
  }

  @override
  String get revisionReviewTitle => 'दोहराएँ';

  @override
  String revisionCardPosition(int position, int total) {
    return 'कार्ड $position / $total';
  }

  @override
  String get revisionShowAnswer => 'उत्तर दिखाएँ';

  @override
  String get revisionAnswer => 'उत्तर';

  @override
  String get revisionNoNotes =>
      'इस कॉन्सेप्ट के लिए कोई नोट्स नहीं हैं। जो याद है उसे याद करने की कोशिश करें।';

  @override
  String get revisionHowWell => 'आपको कितनी अच्छी तरह याद था?';

  @override
  String revisionDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आपने $count कार्ड दोहराए',
      one: 'आपने 1 कार्ड दोहराया',
    );
    return '$_temp0';
  }

  @override
  String get ratingAgain => 'भूल गया';

  @override
  String get ratingHard => 'कठिन';

  @override
  String get ratingGood => 'ठीक';

  @override
  String get ratingEasy => 'आसान';

  @override
  String get cardOriginNotes => 'आपके नोट्स';

  @override
  String get cardOriginPaper => 'आपकी PDF से';

  @override
  String cardOriginPaperPage(String file, int page) {
    return 'आपकी PDF से · $file, पृ. $page';
  }

  @override
  String get cardReasonIncorrect => 'अभ्यास में गलत उत्तर दिया';

  @override
  String get conceptAddToRevision => 'दोहराव में जोड़ें';

  @override
  String get conceptInRevision => 'दोहराव में है';

  @override
  String get revisionAddAll => 'इन्हें दोहराएँ';

  @override
  String revisionQuestionsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कार्ड दोहराव में जोड़े गए।',
      one: '1 कार्ड दोहराव में जोड़ा गया।',
      zero: 'कोई नया कार्ड नहीं जोड़ा गया।',
    );
    return '$_temp0';
  }

  @override
  String revisionQuestionsAlreadyAdded(int count) {
    return '$count पहले से दोहराव में हैं।';
  }

  @override
  String revisionQuestionsNotEligible(int count) {
    return '$count नहीं जोड़े गए: केवल जाँचे गए, उत्तर वाले और बिना चित्र वाले प्रश्न दोहराए जा सकते हैं।';
  }

  @override
  String homeRevisionNoneToday(String when) {
    return 'आज कोई दोहराव नहीं। अगला: $when।';
  }

  @override
  String get homeRevisionEmpty => 'अभी कोई फ्लैशकार्ड नहीं। कॉन्सेप्ट या प्रश्न दोहराव में जोड़ें।';

  @override
  String get reminderSwitch => 'रोज़ पढ़ाई का रिमाइंडर';

  @override
  String reminderOn(String time) {
    return 'हर दिन $time बजे';
  }

  @override
  String get reminderOff => 'बंद';

  @override
  String get reminderNeedsTime => 'चालू करने के लिए रिमाइंडर का समय चुनें।';

  @override
  String get reminderBlocked =>
      'PrepLoop के लिए सूचनाएँ बंद हैं। रिमाइंडर पाने के लिए सिस्टम सेटिंग में इन्हें अनुमति दें।';

  @override
  String get reminderFailed => 'रिमाइंडर सेट नहीं हो सका।';

  @override
  String get reminderUnsupported => 'रिमाइंडर Android और iOS ऐप में काम करते हैं।';

  @override
  String get reminderOpenSettings => 'सूचना सेटिंग खोलें';

  @override
  String get reminderNotificationTitle => 'पढ़ाई का समय';

  @override
  String get reminderNotificationBody => 'आज क्या दोहराना है, देखने के लिए PrepLoop खोलें।';

  @override
  String get reminderChannelName => 'पढ़ाई के रिमाइंडर';

  @override
  String topicAccuracy(String percent, int answered) {
    return '$answered उत्तरों में $percent सही';
  }

  @override
  String topicForgotten(int forgot, int reviews) {
    return '$reviews फ्लैशकार्ड दोहराव में $forgot बार भूले';
  }

  @override
  String planRevisionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ्लैशकार्ड दोहराएँ',
      one: '1 फ्लैशकार्ड दोहराएँ',
    );
    return '$_temp0';
  }

  @override
  String planWeakTopicTitle(String topic) {
    return '$topic का अभ्यास करें';
  }

  @override
  String get planMixedTitle => 'मिश्रित प्रश्नों का अभ्यास करें';

  @override
  String planMockTitle(String name) {
    return 'मॉक टेस्ट दें: $name';
  }

  @override
  String planMinutes(int minutes) {
    return 'लगभग $minutes मिनट';
  }

  @override
  String get planStart => 'शुरू करें';

  @override
  String reasonCardsDue(int due) {
    return 'आज $due बाकी';
  }

  @override
  String reasonCardsDueOverdue(int due, int overdue) {
    return 'आज $due बाकी, $overdue देर से';
  }

  @override
  String reasonBelowThreshold(String threshold) {
    return '$threshold से कम';
  }

  @override
  String get reasonNoPracticeData =>
      'अभी कोई अभ्यास उत्तर नहीं; अभ्यास से पता चलता है कि किन टॉपिक पर काम चाहिए';

  @override
  String reasonNoWeakTopic(int min) {
    return 'अभी कोई कमज़ोर टॉपिक नहीं मिला ($min उत्तरों के बाद टॉपिक का आकलन होता है)';
  }

  @override
  String get reasonMockNever => 'आपने अभी तक कोई मॉक टेस्ट नहीं दिया है।';

  @override
  String reasonMockSince(int days) {
    return 'पिछला मॉक टेस्ट $days दिन पहले।';
  }

  @override
  String reasonExamIn(int days) {
    return 'परीक्षा $days दिन में।';
  }

  @override
  String planGoal(int planned, int goal) {
    return 'आपके $goal मिनट के दैनिक लक्ष्य के लिए लगभग $planned मिनट की योजना।';
  }

  @override
  String get planNoGoal =>
      'योजना को अपने समय के अनुसार बनाने के लिए प्रोफ़ाइल में दैनिक अध्ययन लक्ष्य सेट करें।';

  @override
  String get planOffline => 'अभ्यास सुझावों के लिए इंटरनेट चाहिए, इसलिए केवल दोहराव की योजना है।';

  @override
  String get planEmpty => 'आज के लिए कुछ नहीं: कोई फ्लैशकार्ड बाकी नहीं है।';

  @override
  String get homeWeakOffline => 'अभ्यास आँकड़ों के लिए इंटरनेट चाहिए।';

  @override
  String homeWeakNone(String threshold) {
    return 'कोई कमज़ोर टॉपिक नहीं: पर्याप्त डेटा वाले हर टॉपिक में $threshold या उससे अधिक सही है।';
  }

  @override
  String homeWeakNeedMore(int answers, int reviews) {
    return 'अभी पर्याप्त डेटा नहीं। किसी टॉपिक का आकलन $answers अभ्यास उत्तरों या $reviews फ्लैशकार्ड दोहराव के बाद होता है।';
  }

  @override
  String get homeSeeProgress => 'प्रगति देखें';

  @override
  String get progressSummaryTitle => 'अभ्यास का सारांश';

  @override
  String progressAnswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अभ्यास उत्तर',
      one: '1 अभ्यास उत्तर',
    );
    return '$_temp0';
  }

  @override
  String progressAccuracy(String percent) {
    return '$percent सही';
  }

  @override
  String progressSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सत्र',
      one: '1 सत्र',
    );
    return '$_temp0';
  }

  @override
  String progressDailyTitle(int days) {
    return 'उत्तर दिए गए प्रश्न, पिछले $days दिन';
  }

  @override
  String progressChartSummary(int total, int days) {
    return 'पिछले $days दिनों में $total';
  }

  @override
  String get progressSubjectsTitle => 'विषय के अनुसार';

  @override
  String get progressNoAnswers => 'अभी कोई अभ्यास उत्तर नहीं।';

  @override
  String progressSubjectRow(String percent, int answered) {
    return '$answered उत्तरों में $percent सही';
  }

  @override
  String progressNotEnough(int answered, int min) {
    return 'अभी पर्याप्त उत्तर नहीं ($min में से $answered)';
  }

  @override
  String get progressMocksTitle => 'मॉक टेस्ट';

  @override
  String get progressMocksEmpty => 'अभी तक कोई मॉक टेस्ट नहीं दिया।';

  @override
  String progressMockScore(String score, String max) {
    return '$score / $max';
  }

  @override
  String get progressMockTimeUp => 'समय समाप्त होने पर जमा हुआ';

  @override
  String get progressTopicsTitle => 'टॉपिक';

  @override
  String get progressTopicsEmpty =>
      'अभ्यास किए गए प्रश्नों या फ्लैशकार्ड का टॉपिक होने पर टॉपिक परिणाम दिखेंगे।';

  @override
  String get progressWeakBadge => 'कमज़ोर';

  @override
  String get progressTrendImproving => 'सुधार हो रहा है';

  @override
  String get progressTrendSteady => 'स्थिर';

  @override
  String get progressTrendDeclining => 'गिरावट';

  @override
  String progressNeedsData(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count और टॉपिक का आकलन करने के लिए अधिक डेटा चाहिए।',
      one: '1 और टॉपिक का आकलन करने के लिए अधिक डेटा चाहिए।',
    );
    return '$_temp0';
  }

  @override
  String get progressRevisionTitle => 'फ्लैशकार्ड याददाश्त';

  @override
  String progressRevisionSummary(int reviews, int forgot, int days) {
    return 'पिछले $days दिनों में $reviews दोहराव, $forgot बार भूले';
  }

  @override
  String progressRevisionEmpty(int days) {
    return 'पिछले $days दिनों में कोई फ्लैशकार्ड दोहराव नहीं।';
  }

  @override
  String get progressOffline => 'अभ्यास आँकड़े लोड नहीं हो सके। अपना इंटरनेट कनेक्शन जाँचें।';

  @override
  String progressRules(String accuracy, int answers, String forget, int reviews, int recentDays) {
    return 'कोई टॉपिक कमज़ोर तब माना जाता है जब कम से कम $answers उत्तरों के बाद $accuracy से कम सही हो, या कम से कम $reviews फ्लैशकार्ड दोहराव में से $forget या अधिक में भूले हों। रुझान पिछले $recentDays दिनों की तुलना पहले के उत्तरों से करता है।';
  }

  @override
  String get aiAssistTitle => 'AI सहायता';

  @override
  String get aiReviewNote =>
      'AI का आउटपुट एक मसौदा है। इस पर \"AI द्वारा बनाया गया\" लिखा होता है और शिक्षार्थियों को दिखाने से पहले इसकी जाँच ज़रूरी है।';

  @override
  String aiProvenance(String model, String version) {
    return '$model द्वारा AI से बनाया गया (प्रॉम्प्ट $version)';
  }

  @override
  String get aiBasedOnQuestion => 'एक जाँचे गए प्रश्न के आधार पर';

  @override
  String get aiDraftLabel => 'AI द्वारा बनाया गया मसौदा, जाँचा नहीं गया';

  @override
  String get aiExplanationApproved => 'AI द्वारा बनाई गई व्याख्या (स्वीकृत)';

  @override
  String get aiExplanationLabel => 'AI द्वारा बनाई गई व्याख्या';

  @override
  String get aiUnsure =>
      'AI को दिए गए उत्तर के सही होने पर संदेह था। स्वीकृत करने से पहले उत्तर जाँचें।';

  @override
  String get aiApprove => 'स्वीकृत करें';

  @override
  String get aiEditApprove => 'संपादित करके स्वीकृत करें';

  @override
  String get aiDraftExplanation => 'AI से व्याख्या का मसौदा बनाएँ';

  @override
  String get aiSuggestTopic => 'AI से टॉपिक सुझाएँ';

  @override
  String get aiNoTopic => 'AI को कोई मेल खाता टॉपिक नहीं मिला। खुद चुनें।';

  @override
  String get aiGenerateSimilar => 'मिलते-जुलते अभ्यास प्रश्न बनाएँ';

  @override
  String get aiApproveFirst =>
      'पहले इस प्रश्न को स्वीकृत करें; AI केवल जाँचे गए, उत्तर वाले प्रश्नों से काम करता है।';

  @override
  String get aiGenerateTitle => 'अभ्यास प्रश्न बनाएँ';

  @override
  String get aiGenerate => 'बनाएँ';

  @override
  String get aiGenerateFromQuestionNotice =>
      'उसी टॉपिक पर AI नए प्रश्न लिखता है। ये AI द्वारा बनाए गए और बिना जाँचे प्रश्न के रूप में सहेजे जाते हैं, और कभी पिछले वर्ष के प्रश्न नहीं माने जाते।';

  @override
  String get aiGenerateFromConcept => 'मेरे नोट्स से अभ्यास प्रश्न (AI)';

  @override
  String get aiConceptNotice =>
      'प्रश्न लिखने के लिए कॉन्सेप्ट का शीर्षक और आपके नोट्स AI सेवा को भेजे जाते हैं। प्रश्न AI द्वारा बनाए गए के रूप में सहेजे जाते हैं और अभ्यास से पहले प्रश्न बैंक में जाँच ज़रूरी है।';

  @override
  String aiGenerated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AI प्रश्न जाँच के लिए प्रश्न बैंक में जोड़े गए।',
      one: '1 AI प्रश्न जाँच के लिए प्रश्न बैंक में जोड़ा गया।',
      zero: 'कोई उपयोगी प्रश्न नहीं बना।',
    );
    return '$_temp0';
  }

  @override
  String aiGeneratedRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count जाँच में अस्वीकार हुए।',
      one: '1 जाँच में अस्वीकार हुआ।',
    );
    return '$_temp0';
  }

  @override
  String get aiErrorOffline => 'आप ऑफ़लाइन हैं। AI सहायता के लिए इंटरनेट चाहिए।';

  @override
  String get aiErrorDisabled => 'सर्वर पर AI सहायता सेट नहीं है।';

  @override
  String get aiErrorUnavailable =>
      'AI सेवा अभी उपलब्ध नहीं है। कृपया थोड़ी देर बाद फिर कोशिश करें।';

  @override
  String get aiErrorRateLimited => 'बहुत अधिक AI अनुरोध। कृपया बाद में फिर कोशिश करें।';

  @override
  String get aiErrorNotEligible =>
      'AI केवल जाँचे गए, उत्तर वाले और बिना चित्र वाले प्रश्नों से काम करता है।';

  @override
  String get aiErrorExplanationExists => 'इस प्रश्न की पहले से व्याख्या है।';

  @override
  String get aiErrorTopicSet => 'इस प्रश्न का पहले से टॉपिक है।';

  @override
  String get aiErrorGeneric => 'कुछ गलत हो गया। कृपया फिर से कोशिश करें।';

  @override
  String get reportTitle => 'समस्या बताएँ';

  @override
  String get reportNote => 'क्या गलत है? (वैकल्पिक)';

  @override
  String get reportSend => 'रिपोर्ट भेजें';

  @override
  String get reportSent => 'धन्यवाद। प्रश्न फिर से जाँच के लिए भेजा गया।';

  @override
  String get reportWrongAnswer => 'उत्तर गलत है';

  @override
  String get reportUnclear => 'प्रश्न स्पष्ट नहीं है';

  @override
  String get reportIncorrectContent => 'सामग्री गलत है';

  @override
  String get reportOther => 'कुछ और';

  @override
  String get practiceIncludeAi => 'AI द्वारा बनाए गए प्रश्न शामिल करें';

  @override
  String get practiceIncludeAiHint =>
      'इन पर \"AI द्वारा बनाया गया\" लिखा होता है और ये पिछले वर्ष के प्रश्न नहीं हैं। मॉक टेस्ट में इनका उपयोग कभी नहीं होता।';

  @override
  String get topicSuggestedByAi => 'AI द्वारा सुझाया गया। पुष्टि करें या बदलें।';

  @override
  String get issueLearnerReport => 'शिक्षार्थी द्वारा रिपोर्ट किया गया';

  @override
  String get issueAiLanguageReview => 'AI द्वारा लिखी हिंदी: भाषा जाँचें';
}
