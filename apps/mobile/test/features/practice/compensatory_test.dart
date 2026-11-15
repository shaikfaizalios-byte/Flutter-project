import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/practice/application/practice_providers.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';

import '../../helpers/pump_app.dart';
import 'practice_flow_test.dart' show chslMock, pumpPractice;

const withRule = MockTestView(
  code: 'SSC_CHSL_2026_TIER1',
  name: 'SSC CHSL 2026 Tier-I',
  available: true,
  totalQuestions: 100,
  durationMinutes: 60,
  negativeMarks: 0.5,
  sections: [SectionAvailabilityView(subject: 'English Language', needed: 25, available: 30)],
  compensatoryMinutesPerHour: 20,
  compensatoryReference: 'Sample notice, para 1',
);

Future<void> startMock(WidgetTester tester) async {
  await scrollTo(tester, find.widgetWithText(FilledButton, 'Start mock test'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Start mock test'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Start mock test').last);
  await tester.pumpAndSettle();
}

Future<void> declare(WidgetTester tester, AppDatabase db) =>
    tester.runAsync(() => setCompensatoryTime(db, true));

void main() {
  testAppWidgets('declared compensatory time is asked for when the notice states a rule', (
    tester,
    db,
  ) async {
    await declare(tester, db);
    final repo = await pumpPractice(tester, db, mocks: [withRule]);
    await scrollTo(tester, find.textContaining('+20 min per hour'));
    expect(
      find.textContaining('+20 min per hour compensatory time (Sample notice, para 1)'),
      findsOneWidget,
    );
    await startMock(tester);
    expect(repo.compensatoryStarts, ['SSC_CHSL_2026_TIER1']);
  });

  testAppWidgets('without a rule in the notice, none is added and the card says so', (
    tester,
    db,
  ) async {
    await declare(tester, db);
    final repo = await pumpPractice(tester, db, mocks: [chslMock]);
    await scrollTo(tester, find.textContaining('states no compensatory time'));
    expect(find.textContaining('states no compensatory time'), findsOneWidget);
    await startMock(tester);
    expect(repo.compensatoryStarts, isEmpty);
  });

  testAppWidgets('not declared: nothing is shown or asked for', (tester, db) async {
    final repo = await pumpPractice(tester, db, mocks: [withRule]);
    await scrollTo(tester, find.widgetWithText(FilledButton, 'Start mock test'));
    expect(find.textContaining('compensatory time'), findsNothing);
    await startMock(tester);
    expect(repo.compensatoryStarts, isEmpty);
  });
}
