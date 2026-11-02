import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';

import '../../helpers/pump_app.dart';
import 'practice_flow_test.dart' show TestClock, chslMock, pumpPractice;

/// Two one-question sections of 15 minutes (the fake pool has two questions).
const plan = [
  TimedSectionView(name: 'Reasoning', firstPosition: 1, lastPosition: 1, minutes: 15),
  TimedSectionView(name: 'General Awareness', firstPosition: 2, lastPosition: 2, minutes: 15),
];

Future<FakePracticeRepository> startSectionalMock(
  WidgetTester tester,
  AppDatabase db,
  TestClock clock,
) async {
  final repo = await pumpPractice(tester, db, clock: clock, mocks: [chslMock]);
  repo.mockSections = plan;
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Start mock test'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Start mock test'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Start mock test').last);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  test('only the open section is open', () {
    final session = PracticeSessionView(
      id: 's',
      mode: SessionMode.mock,
      submitted: false,
      startedAt: DateTime.utc(2026),
      serverNow: DateTime.utc(2026),
      items: const [],
      sections: plan,
      currentSection: 1,
    );
    expect(session.openSection?.name, 'General Awareness');
    expect((session.isOpen(1), session.isOpen(2)), (false, true));
  });

  testAppWidgets('a sectional mock shows its section, its own timer and Finish section', (
    tester,
    db,
  ) async {
    final clock = TestClock();
    await startSectionalMock(tester, db, clock);

    expect(find.text('Section 1 of 2: Reasoning'), findsOneWidget);
    expect(find.textContaining('own 15-minute timer'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget); // the section's time, not the hour
    expect(find.widgetWithText(FilledButton, 'Finish section'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
  });

  testAppWidgets('finishing a section opens the next and there is no way back', (tester, db) async {
    final clock = TestClock();
    final repo = await startSectionalMock(tester, db, clock);

    await tester.tap(find.widgetWithText(FilledButton, 'Finish section'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 question in this section is unanswered'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish section').last);
    await tester.pumpAndSettle();

    expect(repo.finishedSections, [0]);
    expect(find.text('Section 2 of 2: General Awareness'), findsOneWidget);
    expect(find.text('Second?'), findsOneWidget);
    final previous = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Previous'));
    expect(previous.onPressed, isNull);
  });

  testAppWidgets("when a section's time is up the next one opens by itself", (tester, db) async {
    final clock = TestClock();
    await startSectionalMock(tester, db, clock);

    clock.now = clock.now.add(const Duration(minutes: 15, seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Section 2 of 2: General Awareness'), findsOneWidget);
    expect(find.textContaining("Time's up for that section"), findsOneWidget);
  });
}
