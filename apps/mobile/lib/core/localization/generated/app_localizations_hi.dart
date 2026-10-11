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
  String get studyEmptyTitle => 'आपकी अध्ययन सामग्री यहाँ रहेगी';

  @override
  String get studyEmptyMessage =>
      'कॉन्सेप्ट, फ़्लैशकार्ड और आयात किए गए प्रश्न-पत्र यहाँ दिखेंगे। यह अनुभाग आगामी अपडेट में उपलब्ध होगा।';

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
  String get settingsPreferencesNote =>
      'ये प्राथमिकताएँ अभी सहेजी नहीं जातीं और ऐप दोबारा शुरू होने पर रीसेट हो जाती हैं।';

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
}
