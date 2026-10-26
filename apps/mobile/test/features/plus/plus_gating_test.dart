import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/core/widgets/search_field.dart';

import '../../helpers/pump_app.dart';
import '../concepts/concept_flow_test.dart' show openStudy;
import '../concepts/paper_search_test.dart' show paperQuestions;

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(AppSearchField), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('without Plus the search offers Plus instead of AI, and sends nothing', (
    tester,
    db,
  ) async {
    final ai = FakeAiRepository(enabled: true, requiresPlus: true);
    await pumpPrepLoopApp(
      tester,
      db,
      ai: ai,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await search(tester, 'kotlin coroutines');

    expect(
      find.text('AI answers from your papers, explained simply, are part of PrepLoop Plus.'),
      findsOneWidget,
    );
    expect(find.text('Ask AI'), findsNothing);
    expect(ai.calls, isEmpty);
    // Studying stays free: the paper search and Google still work.
    expect(find.text('Search on Google'), findsOneWidget);

    await tester.tap(find.text('See Plus'));
    await tester.pumpAndSettle();
    expect(find.text('PrepLoop Plus'), findsWidgets);
  });

  testAppWidgets('with Plus the search offers AI as before', (tester, db) async {
    final ai = FakeAiRepository(enabled: true, requiresPlus: true, plusActive: true);
    await pumpPrepLoopApp(
      tester,
      db,
      ai: ai,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await search(tester, 'kotlin coroutines');

    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.text('See Plus'), findsNothing);
  });

  testAppWidgets('a used-up monthly allowance is explained', (tester, db) async {
    final ai = FakeAiRepository(enabled: true, requiresPlus: true, plusActive: true)
      ..failure = const ServerFailure(statusCode: 429, code: 'ai_allowance_used');
    await pumpPrepLoopApp(
      tester,
      db,
      ai: ai,
      questions: paperQuestions,
      studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    );
    await openStudy(tester);
    await search(tester, 'kotlin coroutines');
    await tester.tap(find.text('Ask AI'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining("You've used this month's AI requests"), findsOneWidget);
  });
}
