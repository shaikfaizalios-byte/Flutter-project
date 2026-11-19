# Accessibility audit

What was checked in the app (Phase 7), how, what was found and fixed, and what is still open.
Automated checks run with every `flutter test`; the manual items need a real device.

## How it is checked

| Area | How | Where |
|---|---|---|
| Screen-reader labels | Flutter's `labeledTapTargetGuideline`: every tappable thing has a label | `test/a11y/accessibility_test.dart`, `test/a11y/screens_accessibility_test.dart` |
| Tap-target size | `androidTapTargetGuideline` (48 × 48) and `iOSTapTargetGuideline` (44 × 44) | same |
| Contrast | `textContrastGuideline` (WCAG AA: 4.5:1 for text, 3:1 for large text), light and dark | same |
| Large text | Every screen laid out at 2× text size; any overflow fails the test | same |
| Reduce motion | With the device's "remove animations" on, pages open without a transition | `screens_accessibility_test.dart` |
| Icon buttons | A scan of the code: every `IconButton` has a tooltip (its spoken label) | this audit (0 without) |

Screens covered: the five tabs and sign-in (existing), plus a practice question, question
review, snap a question, current affairs, revision, imported papers and ladder topics.

## Found and fixed

- A one-line question in practice was selectable text only 24 px tall: press-and-hold selects
  it, so it is a tap target below the minimum. Selectable question text now keeps a 48 px
  minimum height (`RichQuestionText`).
- Page transitions ignored the device's "remove animations" setting (only the ladder's moving
  icon followed it). The app now opens pages without a transition when it is on
  (`AppTheme.noTransitions`, applied in `app.dart`).

## Already in place (checked, no change needed)

- Colour is never the only signal. The exam-style question palette tells statuses apart by shape
  as well as colour (square, rounded top, rounded bottom, circle, with a dot for "answered and
  marked"), with spoken labels per question. Right and wrong answers show a tick or a cross icon
  besides the colour.
- Images have spoken descriptions: paper pages ("Page 3 of 12") and question figures (which
  kind of figure and its page: "Figure from the paper (page 4)").
- Hindi and other scripts use bundled fonts, so text never falls back to boxes on the device.
- Text size follows the device setting everywhere (one fixed-size exception: the short "S1"
  source tags in AI answers, which are badges, not reading text).

## Still open (needs a device or a person)

- A real screen-reader pass with TalkBack (Android) and VoiceOver (iOS): reading order, what is
  announced after answering a question, and the mock-test timer. Automated checks prove labels
  exist, not that the order and wording make sense.
- Switch access and keyboard-only use on the web app.
- Hindi labels were written without a native speaker's review (as for all Hindi text).
- Colours inside question figures come from the papers themselves and can't be changed.
