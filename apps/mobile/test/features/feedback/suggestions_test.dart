import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/feedback/data/feedback_repository.dart';

import '../../helpers/fake_feedback.dart';
import '../../helpers/pump_app.dart';
import '../settings/study_plan_section_test.dart' show openProfile;

Future<void> openSuggestions(WidgetTester tester) async {
  await openProfile(tester);
  await scrollTo(tester, find.text('Write a suggestion'));
  await tester.tap(find.text('Write a suggestion'));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('a learner sends a suggestion and sees it with its status', (tester, db) async {
    final feedback = FakeFeedbackRepository();
    await pumpPrepLoopApp(tester, db, feedback: feedback);
    await openSuggestions(tester);

    expect(find.text("You haven't sent any suggestions yet."), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.enterText(find.byType(TextFormField), 'too short');
    await tester.tap(find.text('Send suggestion'));
    await tester.pumpAndSettle();
    expect(find.text('Write at least 10 characters.'), findsOneWidget);
    expect(feedback.sent, isEmpty);

    await tester.enterText(find.byType(TextFormField), 'Remove the daily streak pop-up');
    await tester.tap(find.text('Send suggestion'));
    await tester.pumpAndSettle();
    expect(feedback.sent.single.kind, SuggestionKind.remove);
    expect(feedback.sent.single.text, 'Remove the daily streak pop-up');
    expect(find.text('Thanks! Your suggestion was sent.'), findsOneWidget);
    expect(find.text('Remove the daily streak pop-up'), findsOneWidget);
    expect(find.textContaining('Remove · Sent'), findsOneWidget);
  });

  testAppWidgets('too many suggestions in a day is explained', (tester, db) async {
    final feedback = FakeFeedbackRepository()
      ..failure = const ServerFailure(statusCode: 429, code: 'rate_limited');
    await pumpPrepLoopApp(tester, db, feedback: feedback);
    await openSuggestions(tester);

    await tester.enterText(find.byType(TextFormField), 'Please add a formula sheet');
    await tester.tap(find.text('Send suggestion'));
    await tester.pumpAndSettle();
    expect(
      find.text("You've sent many suggestions today. Please try again tomorrow."),
      findsOneWidget,
    );
  });
}
