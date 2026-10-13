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
      'रिमाइंडर आगामी अपडेट में चालू होंगे। आपका पसंदीदा समय अभी सहेजा जाएगा।';

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
  String get homePlanComingSoon =>
      'अभ्यास और दोहराव उपलब्ध होने पर आपकी व्यक्तिगत दैनिक योजना यहाँ दिखेगी।';

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
}
