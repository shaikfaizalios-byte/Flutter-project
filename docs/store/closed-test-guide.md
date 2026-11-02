# Closed test — guide

Google Play currently asks new **personal** developer accounts to run a closed test with at least
12 testers who stay opted in for 14 days before the app can go to production (check the current
rule for your account in Play Console; it has changed before). The test is also the best way to
see where real learners get stuck.

Part 1 is for you (the operator). Part 2 is the page you send to testers, in English and Hindi.

---

## Part 1 — Running the test (operator)

### Before inviting anyone

- [ ] Backend deployed with HTTPS (docs/deployment.md); the test build points at it, not the
      home-PC tunnel (testers can't depend on your PC being on).
- [ ] RRB NTPC formats published on that server; at least one paper per featured exam
      imported and reviewed, so mocks and "Repeated models" can be shown.
- [ ] Legal texts published at public URLs (privacy policy, terms); contact email works.
- [ ] Email delivery works (real SMTP): sign-up codes and password resets arrive.
- [ ] A feedback channel chosen and written into Part 2 (a Google Form, an email address or a
      WhatsApp/Telegram group). In-app, testers can also use **Profile → Suggest a feature**.

### Who to invite (aim for 15–20, so 12 stay)

- Adults (18+) preparing for SSC CGL/CHSL or RRB NTPC now; a few who prefer Hindi.
- Different phones: at least one budget phone (2–3 GB RAM) and one older Android version.
- People who have PDFs of previous papers, or are willing to use the ones you give them.
- Not only friends: a few strangers from an exam community give more honest feedback.

### Play Console steps

1. Testing → Closed testing → create a track; upload the signed app bundle (docs/release.md §3).
2. Add testers by email list or a Google Group; copy the opt-in link into Part 2.
3. Ask testers to stay opted in and keep the app for the whole 14 days.

### During the 14 days

| Day | What to look at |
|---|---|
| 1–2 | Did everyone get in? Sign-up email arrives? First paper upload works? Fix blockers first. |
| 3–7 | Which screens confuse people? Are imported questions right? Do reminders arrive? |
| 8–14 | Are people still coming back? What do they practise? Do mocks and the plan make sense? |

Questions to ask each tester at the end (short call or form):

1. What did you expect the app to do when you first opened it? Did it?
2. How long until you did something useful (first practice question)?
3. How well did it read your paper? Anything wrong that wasn't flagged?
4. Which screen would you open most? Which would you never open?
5. Would you pay for it? For what exactly?
6. What would make you recommend it to a friend preparing for the same exam?

Count only what you see: don't turn three opinions into "most users". Log every problem with
phone model, Android version, and the steps.

### What testers must not do

- Upload papers they have no right to share **publicly** — uploads are private to their own
  account, but screenshots they post may not be.
- Use real passwords they use elsewhere (a test is a good moment to remind them).

---

## Part 2 — Tester instructions (send this)

### English

**Thank you for testing PrepLoop!** PrepLoop helps you prepare for multiple-choice exams (SSC,
RRB and others) from your own previous-year papers. This is a test version: some things may
break, and that's exactly what we want to find.

**Join (2 minutes)**
1. Open this link on your Android phone and tap "Become a tester": `[opt-in link]`
2. Install PrepLoop from the Play Store link on that page.
3. Please keep the app installed for **14 days** — Google needs this before we can publish.

**Try these over the two weeks** (no need to do all on day one):
1. Create an account (you must be 18+). Check the code arrives by email.
2. Choose your exam (e.g. SSC CGL or RRB NTPC).
3. Upload a PDF of a previous-year paper (Study → Imported papers). Wait until it says "Ready",
   then open it: are the questions and options right? Anything wrong that wasn't flagged?
4. Practise 10–20 questions. Try once with the internet off.
5. Add a few flashcards and turn on the daily reminder. Does it arrive at your time?
6. After a few days, open **Progress**: do the weak topics and the readiness card make sense?
7. If a mock test is available for your exam, try one.
8. Switch the app language to Hindi (Profile → App language) and back.

**Tell us** (the more exact, the better): what you did, what you expected, what happened, and
your phone model. Send to: `[feedback channel]`. Ideas: Profile → **Suggest a feature**.

**Your data:** your papers and notes are private to your account. There are no ads and no
tracking. You can export or delete your account at any time (Profile).

### हिन्दी

**PrepLoop की जाँच करने के लिए धन्यवाद!** PrepLoop आपके अपने पिछले वर्षों के पेपरों से
बहुविकल्पीय परीक्षाओं (SSC, RRB आदि) की तैयारी में मदद करता है। यह जाँच संस्करण है: कुछ चीज़ें
ठीक से काम न करें, और हमें ठीक यही पता लगाना है।

**जुड़ें (2 मिनट)**
1. अपने Android फ़ोन पर यह लिंक खोलें और "Become a tester" दबाएँ: `[opt-in link]`
2. उसी पेज के Play Store लिंक से PrepLoop इंस्टॉल करें।
3. कृपया ऐप को **14 दिन** इंस्टॉल रखें — प्रकाशित करने से पहले Google को यह चाहिए।

**दो हफ़्तों में ये करके देखें** (सब पहले दिन करना ज़रूरी नहीं):
1. खाता बनाएँ (आयु 18+ होनी चाहिए)। देखें कि कोड ईमेल पर आता है।
2. अपनी परीक्षा चुनें (जैसे SSC CGL या RRB NTPC)।
3. पिछले वर्ष के पेपर की PDF अपलोड करें (Study → Imported papers)। "Ready" आने तक रुकें, फिर
   खोलें: क्या प्रश्न और विकल्प सही हैं? कुछ गलत जो चिह्नित नहीं हुआ?
4. 10–20 प्रश्नों का अभ्यास करें। एक बार इंटरनेट बंद करके भी।
5. कुछ फ़्लैशकार्ड जोड़ें और दैनिक रिमाइंडर चालू करें। क्या वह आपके समय पर आता है?
6. कुछ दिनों बाद **Progress** खोलें: क्या कमज़ोर टॉपिक और तैयारी कार्ड समझ में आते हैं?
7. अगर आपकी परीक्षा का मॉक टेस्ट उपलब्ध है, तो एक दें।
8. ऐप की भाषा हिन्दी करें (Profile → App language) और वापस बदलें।

**हमें बताएँ** (जितना सटीक, उतना अच्छा): आपने क्या किया, क्या उम्मीद थी, क्या हुआ, और आपके
फ़ोन का मॉडल। भेजें: `[feedback channel]`। सुझाव: Profile → **Suggest a feature**।

**आपका डेटा:** आपके पेपर और नोट्स आपके खाते तक निजी हैं। कोई विज्ञापन नहीं, कोई ट्रैकिंग नहीं।
आप कभी भी अपना खाता निर्यात कर सकते हैं या हटा सकते हैं (Profile)।

(The Hindi text needs a native speaker's review before sending.)
