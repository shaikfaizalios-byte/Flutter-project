import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';

import '../../helpers/pump_app.dart';
import '../settings/settings_screen_test.dart' show openProfile;
import 'practice_flow_test.dart' show pumpPractice;

const weeklyMock = MockTestView(
  code: 'SSC_CHSL_2026_TIER1',
  name: 'SSC CHSL 2026 Tier-I',
  available: true,
  totalQuestions: 100,
  durationMinutes: 60,
  negativeMarks: 0.5,
  sections: [SectionAvailabilityView(subject: 'English Language', needed: 25, available: 30)],
  weeklyAvailable: true,
  weeklyLabel: '2026-W47',
);

void main() {
  testAppWidgets('the weekly fixed paper starts as the same paper for everyone', (
    tester,
    db,
  ) async {
    final repo = await pumpPractice(tester, db, mocks: [weeklyMock]);
    final button = find.textContaining("This week's fixed paper · 2026-W47");
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('the same questions from the shared bank'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start mock test').last);
    await tester.pumpAndSettle();
    expect(repo.weeklyStarts, ['SSC_CHSL_2026_TIER1']);
  });

  testAppWidgets('no weekly paper is offered when the shared bank has too few questions', (
    tester,
    db,
  ) async {
    const plain = MockTestView(
      code: 'SSC_CHSL_2026_TIER1',
      name: 'SSC CHSL 2026 Tier-I',
      available: true,
      totalQuestions: 100,
      sections: [],
    );
    await pumpPractice(tester, db, mocks: [plain]);
    await scrollTo(tester, find.widgetWithText(FilledButton, 'Start mock test'));
    expect(find.textContaining("This week's fixed paper"), findsNothing);
  });

  testAppWidgets('comparing scores is off until the learner turns it on', (tester, db) async {
    final repo = await pumpPractice(tester, db);
    await openProfile(tester);
    final toggle = find.widgetWithText(SwitchListTile, 'Compare my scores');
    await scrollTo(tester, toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.textContaining('once 100 of them'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(repo.percentileOptIn, isTrue);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
  });
}
