# Google Play store listing — draft (English and Hindi)

Draft for the first release (India; SSC and RRB featured). Before submitting:

- [ ] Every claim below is true **in the build you upload** (check the "Only if" notes).
- [ ] The Hindi text has been reviewed by a native speaker (it hasn't yet).
- [ ] Character counts are checked in Play Console (limits: name 30, short description 80,
      full description 4000).
- [ ] Data safety answers come from [../legal/play-data-safety.md](../legal/play-data-safety.md).

Rules for this listing (from the product rules in CLAUDE.md): no "guaranteed selection", no rank or
pass predictions, no claim that questions are official unless they are, no invented exam facts
(counts, marks, cut-offs), no fake ratings or user numbers.

---

## English

**App name** (30): `PrepLoop: Prep from Papers`

**Short description** (80):
`Turn your old exam papers into practice, revision and a clear study plan.`

**Full description:**

```
Study from the papers you already have.

PrepLoop turns your previous-year papers and notes into a personal practice and revision system
for multiple-choice exams. SSC CGL, SSC CHSL and RRB NTPC are featured, and you can add any other
exam with your own subjects and topics.

IMPORT YOUR PAPERS
• Upload a PDF paper; PrepLoop reads it (including scanned pages) and finds the questions,
  options and answer keys.
• Anything it is unsure about is flagged for you to check. Nothing is silently "fixed".
• Read the original page, solve the paper as printed, or review and correct questions.

SEE WHAT REPEATS
• Questions are grouped by subject, topic and question type.
• See which topics and question types come up again across your papers, and which syllabus
  topics have not appeared yet. Counts come only from papers you have reviewed.

PRACTISE AND REVISE
• Topic-wise or mixed practice with instant feedback, also offline.
• Timed mock tests for exams with a verified official format (SSC CGL Tier-I, SSC CHSL Tier-I,
  RRB NTPC CBT), marked exactly as the official notice states.
• Flashcards with scheduled revision, and a daily reminder you control.

KNOW WHERE YOU STAND
• Weak topics with the reason for each (accuracy, repeated mistakes, time per question).
• A daily study plan that explains every item.
• A readiness view showing how much of your syllabus you have covered. PrepLoop never predicts
  your score or your chance of selection.

BUILT TO BE HONEST
• Mock formats come only from official notices, with the source shown.
• No ads. No tracking or analytics. Your papers stay private to your account.
• Export or delete your data at any time.

Available in English and Hindi.

PrepLoop is an independent study tool. It is not affiliated with SSC, the Railway Recruitment
Boards or any exam body.
```

Only if — remove the line before uploading if it isn't true in that build:
- "RRB NTPC CBT" mock formats: only once the RRB formats are published on the **production**
  server (`python -m app.cli.exam_formats publish`).
- "No ads": true today; keep it true.
- Do **not** add AI features (explanations, quick answers, lessons) until AI is switched on
  in production and its quality has been checked; then add a line labelled as AI-generated.
- Do **not** mention starter / shared papers until the operator has published some with rights.

---

## हिन्दी

**ऐप का नाम** (30): `PrepLoop: पेपर से तैयारी`

**संक्षिप्त विवरण** (80):
`अपने पुराने परीक्षा पेपरों से अभ्यास, रिवीजन और साफ़ अध्ययन योजना बनाएँ।`

**पूरा विवरण:**

```
जो पेपर आपके पास हैं, उन्हीं से पढ़ाई करें।

PrepLoop आपके पिछले वर्षों के पेपरों और नोट्स को बहुविकल्पीय परीक्षाओं के लिए आपकी अपनी
अभ्यास और रिवीजन प्रणाली में बदलता है। SSC CGL, SSC CHSL और RRB NTPC प्रमुख हैं, और आप
किसी भी दूसरी परीक्षा को अपने विषयों और टॉपिकों के साथ जोड़ सकते हैं।

अपने पेपर जोड़ें
• PDF पेपर अपलोड करें; PrepLoop उसे पढ़ता है (स्कैन किए पेज भी) और प्रश्न, विकल्प और
  उत्तर-कुंजी ढूँढता है।
• जिस पर संदेह हो, उसे आपकी जाँच के लिए चिह्नित किया जाता है। कुछ भी चुपचाप "सुधारा" नहीं जाता।
• मूल पेज पढ़ें, छपे क्रम में पेपर हल करें, या प्रश्नों की समीक्षा और सुधार करें।

देखें क्या दोहराया जाता है
• प्रश्न विषय, टॉपिक और प्रश्न-प्रकार के अनुसार समूहित होते हैं।
• देखें कौन-से टॉपिक और प्रश्न-प्रकार आपके पेपरों में बार-बार आते हैं, और सिलेबस के कौन-से
  टॉपिक अभी तक नहीं आए। गिनती केवल आपके जाँचे हुए पेपरों से होती है।

अभ्यास और रिवीजन
• टॉपिक-वार या मिश्रित अभ्यास, तुरंत फ़ीडबैक के साथ, ऑफ़लाइन भी।
• सत्यापित आधिकारिक प्रारूप वाली परीक्षाओं के लिए समयबद्ध मॉक टेस्ट (SSC CGL Tier-I,
  SSC CHSL Tier-I, RRB NTPC CBT), अंक ठीक वैसे जैसे आधिकारिक सूचना में लिखे हैं।
• निर्धारित रिवीजन वाले फ़्लैशकार्ड, और आपके नियंत्रण में दैनिक रिमाइंडर।

जानें आप कहाँ हैं
• कमज़ोर टॉपिक, हर एक का कारण सहित (सटीकता, दोहराई गई गलतियाँ, प्रति प्रश्न समय)।
• दैनिक अध्ययन योजना, जिसका हर कदम समझाया गया है।
• तैयारी का दृश्य, जो बताता है कि सिलेबस का कितना हिस्सा आपने पूरा किया है। PrepLoop कभी
  आपके अंक या चयन की संभावना का अनुमान नहीं लगाता।

ईमानदारी से बना
• मॉक प्रारूप केवल आधिकारिक सूचनाओं से, स्रोत के साथ।
• कोई विज्ञापन नहीं। कोई ट्रैकिंग या एनालिटिक्स नहीं। आपके पेपर आपके खाते तक निजी रहते हैं।
• अपना डेटा कभी भी निर्यात करें या हटाएँ।

अंग्रेज़ी और हिन्दी में उपलब्ध।

PrepLoop एक स्वतंत्र अध्ययन साधन है। इसका SSC, रेलवे भर्ती बोर्ड या किसी परीक्षा संस्था से
कोई संबंध नहीं है।
```

The same "Only if" notes apply to the Hindi text.

---

## Screenshots (phone, 1080 × 1920 or larger; 4–8 per language)

Use real screens from a test account with **clearly sample data**: never a real person's name,
never invented "results". Each caption is short and true.

| # | Screen | How to get it | Caption (EN) | Caption (HI) |
|---|---|---|---|---|
| 1 | Home "Today" card with a plan | Account with a few practice answers and due flashcards | A daily plan that explains itself | हर कदम समझाने वाली दैनिक योजना |
| 2 | Imported papers, one "Ready · N questions found · M need a look" | Upload a generated sample paper | Upload a PDF, get the questions | PDF अपलोड करें, प्रश्न पाएँ |
| 3 | Question review with a flagged issue | Open a question that has an issue | Unsure? It's flagged, not guessed | संदेह हो तो चिह्नित, अनुमान नहीं |
| 4 | Repeated models | 3+ reviewed papers with confirmed topics | See which topics repeat | देखें कौन-से टॉपिक दोहराते हैं |
| 5 | Practice question with feedback | Any practice session | Practise by topic, even offline | टॉपिक-वार अभ्यास, ऑफ़लाइन भी |
| 6 | Mock card with the format source | Practice tab, SSC CHSL mock | Mocks from the official format | आधिकारिक प्रारूप से मॉक टेस्ट |
| 7 | Progress: weak topics + Readiness | After ~30 answers | Know your weak topics and why | कमज़ोर टॉपिक और उनके कारण |
| 8 | Revision card review | A few flashcards due | Revise at the right time | सही समय पर रिवीजन |

Sample papers for screenshots: generate them (services/api/tests/pdf_factory.py) or use papers
you have the right to show. Do not show real copyrighted papers you don't have rights to.

**Feature graphic** (1024 × 500): app name, the short description, no exam-body logos
(they are not yours to use).

## Other Play Console fields

- **Category:** Education. **Tags:** exam preparation, test preparation.
- **Target audience:** 18 and over (sign-up requires confirming age 18+; see `MINIMUM_AGE`).
- **Contains ads:** No.
- **In-app purchases:** No until Play Billing is configured; then Yes (PrepLoop Plus).
- **Content rating:** answer the questionnaire honestly (education; user-generated content =
  learners' own private papers, not shared publicly).
- **Privacy policy URL / contact email:** from your domain (pending).
