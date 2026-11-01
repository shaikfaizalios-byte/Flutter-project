import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/question_bank/domain/shared_report_kind.dart';

import '../../helpers/pump_app.dart';
import 'question_bank_test.dart' show openPractice, openQuestion;

void main() {
  testAppWidgets('a shared question can be reported to the PrepLoop team', (tester, db) async {
    final questions = FakeQuestionsRepository([
      bankQuestion(sharedSource: 'SSC CHSL 2024 (official paper)'),
    ]);
    await pumpPrepLoopApp(tester, db, questions: questions);
    await openPractice(tester);
    await openQuestion(tester, 'What is 20%');

    await tester.tap(find.byTooltip('Report this shared paper'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining("shouldn't be shared"));
    await tester.pumpAndSettle();
    final send = find.widgetWithText(FilledButton, 'Send report');
    expect(tester.widget<FilledButton>(send).onPressed, isNull); // needs a description
    await tester.enterText(find.byType(TextField), 'This page is from my published book.');
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(questions.sharedReports.single.$1, 'q1');
    expect(questions.sharedReports.single.$2, SharedReportKind.rights);
    expect(find.text('Thanks. The PrepLoop team will review it.'), findsOneWidget);
  });
}
