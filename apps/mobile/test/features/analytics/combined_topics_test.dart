import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/app_features.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/analytics/domain/analytics_models.dart';
import 'package:preploop/features/analytics/presentation/combined_topics_card.dart';

import '../../helpers/pump_app.dart';
import 'progress_flow_test.dart' show openProgress, sampleStats, scrollProgress;

final profilesOn = appFeaturesProvider.overrideWithValue(const AppFeatures(examProfiles: true));
const kinematics = CanonicalTopic(
  name: 'Kinematics',
  answered: 30,
  correct: 21,
  exams: [
    ExamTopicCounts(examCode: 'SSC_CHSL', answered: 10, correct: 9),
    ExamTopicCounts(examCode: 'SSC_CGL', answered: 20, correct: 12),
  ],
);

Future<FakeAnalyticsRepository> pumpProgress(
  WidgetTester tester,
  AppDatabase db, {
  List<String> exams = const ['SSC_CHSL', 'SSC_CGL'],
  bool flag = true,
  List<CanonicalTopic> topics = const [kinematics],
}) async {
  final analytics = FakeAnalyticsRepository(data: sampleStats())..canonicalTopics = topics;
  await pumpPrepLoopApp(
    tester,
    db,
    analytics: analytics,
    studyProfile: onboardedProfile.copyWith(examCodes: exams),
    extraOverrides: [if (flag) profilesOn],
  );
  await openProgress(tester);
  await scrollProgress(tester, find.byType(CombinedTopicsCard));
  return analytics;
}

void main() {
  test('reads the server counts', () {
    final topic = CanonicalTopic.fromJson({
      'key': 'physics/kinematics',
      'name': 'Kinematics',
      'answered': 3,
      'correct': 2,
      'exams': [
        {'exam_code': 'JEE_MAIN', 'answered': 3, 'correct': 2},
      ],
    });
    expect((topic.name, topic.answered, topic.correct), ('Kinematics', 3, 2));
    expect(topic.exams.single.examCode, 'JEE_MAIN');
  });

  testAppWidgets('two exams show a topic combined and per exam', (tester, db) async {
    final analytics = await pumpProgress(tester, db);
    await tester.pumpAndSettle();
    expect(find.text('21 of 30'), findsOneWidget);
    expect(find.textContaining('9 of 10'), findsOneWidget);
    expect(find.textContaining('12 of 20'), findsOneWidget);
    expect(analytics.canonicalExams, ['SSC_CHSL', 'SSC_CGL']);
  });

  testAppWidgets('one exam asks for nothing and shows no card', (tester, db) async {
    final analytics = await pumpProgress(tester, db, exams: const ['SSC_CHSL']);
    expect(find.text('Kinematics', skipOffstage: false), findsNothing);
    expect(analytics.canonicalExams, isEmpty);
  });

  testAppWidgets('no shared answers means no card', (tester, db) async {
    await pumpProgress(tester, db, topics: const []);
    expect(find.text('Across your exams', skipOffstage: false), findsNothing);
  });

  testAppWidgets('with the flag off nothing is asked for', (tester, db) async {
    final analytics = await pumpProgress(tester, db, flag: false);
    expect(find.text('Kinematics', skipOffstage: false), findsNothing);
    expect(analytics.canonicalExams, isEmpty);
  });
}
