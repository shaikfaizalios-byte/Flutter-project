import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';

/// A short quotation about learning, practice or discipline. Only well-documented sayings are
/// listed (many famous "quotes" online are misattributed); Hindi versions are translations.
@immutable
class Quote {
  const Quote({required this.en, required this.hi, required this.author});

  final String en;
  final String hi;
  final String author;
}

const quotes = <Quote>[
  Quote(
    en: 'Arise, awake, and stop not till the goal is reached.',
    hi: 'उठो, जागो और तब तक मत रुको जब तक लक्ष्य प्राप्त न हो जाए।',
    author: 'Swami Vivekananda',
  ),
  Quote(
    en: 'Take up one idea. Make that one idea your life.',
    hi: 'एक विचार लो। उसी एक विचार को अपना जीवन बना लो।',
    author: 'Swami Vivekananda',
  ),
  Quote(
    en: 'We are what we repeatedly do. Excellence, then, is not an act, but a habit.',
    hi: 'हम वही हैं जो हम बार-बार करते हैं। उत्कृष्टता कोई एक काम नहीं, एक आदत है।',
    author: 'Will Durant',
  ),
  Quote(en: 'Well begun is half done.', hi: 'अच्छी शुरुआत आधा काम है।', author: 'Aristotle'),
  Quote(
    en: 'Genius is one per cent inspiration and ninety-nine per cent perspiration.',
    hi: 'प्रतिभा एक प्रतिशत प्रेरणा और निन्यानबे प्रतिशत पसीना है।',
    author: 'Thomas Edison',
  ),
  Quote(
    en: 'Concentration is the secret of strength.',
    hi: 'एकाग्रता ही शक्ति का रहस्य है।',
    author: 'Ralph Waldo Emerson',
  ),
  Quote(en: 'Knowledge is power.', hi: 'ज्ञान ही शक्ति है।', author: 'Francis Bacon'),
  Quote(
    en: 'Repetition is the mother of learning.',
    hi: 'दोहराना ही सीखने की जननी है।',
    author: 'Latin proverb',
  ),
  Quote(
    en: 'Slow and steady wins the race.',
    hi: 'धीमे और लगातार चलने वाला ही दौड़ जीतता है।',
    author: 'Aesop',
  ),
  Quote(
    en: 'Success is the sum of small efforts, repeated day in and day out.',
    hi: 'सफलता छोटे-छोटे प्रयासों का जोड़ है, जो रोज़-रोज़ दोहराए जाते हैं।',
    author: 'Robert Collier',
  ),
  Quote(
    en: 'Discipline is the bridge between goals and accomplishment.',
    hi: 'अनुशासन लक्ष्य और उपलब्धि के बीच का पुल है।',
    author: 'Jim Rohn',
  ),
  Quote(
    en: 'Practice does not make perfect. Only perfect practice makes perfect.',
    hi: 'अभ्यास से पूर्णता नहीं आती। केवल सही अभ्यास से पूर्णता आती है।',
    author: 'Vince Lombardi',
  ),
  Quote(
    en: 'The beautiful thing about learning is that no one can take it away from you.',
    hi: 'सीखने की सबसे सुंदर बात यह है कि इसे कोई आपसे छीन नहीं सकता।',
    author: 'B. B. King',
  ),
  Quote(
    en: 'What we learn with pleasure we never forget.',
    hi: 'जो हम आनंद से सीखते हैं, उसे कभी नहीं भूलते।',
    author: 'Alfred Mercier',
  ),
  Quote(
    en: 'You have to dream before your dreams can come true.',
    hi: 'सपने सच होने से पहले आपको सपने देखने होंगे।',
    author: 'A. P. J. Abdul Kalam',
  ),
  Quote(
    en: 'You have a right to your work, but never to its fruits.',
    hi: 'कर्म पर ही तुम्हारा अधिकार है, उसके फलों पर कभी नहीं।',
    author: 'Bhagavad Gita 2.47',
  ),
];

/// Today's quote: the same all day, a different one each day. [offset] moves to the next
/// ones (the learner's "another" button).
Quote quoteFor(CalendarDate day, {int offset = 0}) {
  final index = (CalendarDate(2026, 1, 1).daysUntil(day) + offset) % quotes.length;
  return quotes[index < 0 ? index + quotes.length : index];
}
