import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/exams/domain/exam_topics.dart';

import '../../helpers/pump_app.dart';
import 'exams_test.dart' show openMyExams;

const suggestion = CanonicalTopic(
  nodeId: 'n-percent',
  label: 'Percentage',
  subjectLabel: 'Quantitative Aptitude',
  confirmed: false,
);

Future<FakeExamsRepository> openTopics(
  WidgetTester tester,
  AppDatabase db,
  List<ExamTopic> topics,
) async {
  final exams = FakeExamsRepository()..topicsByExam['SSC_CGL'] = topics;
  await pumpPrepLoopApp(
    tester,
    db,
    exams: exams,
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CGL']),
  );
  await openMyExams(tester);
  await tester.tap(find.widgetWithText(ListTile, 'SSC CGL'));
  await tester.pumpAndSettle();
  return exams;
}

void main() {
  test('a canonical link is read from the server', () {
    final topic = ExamTopic.fromJson({
      'id': 't1',
      'subject': 'Maths',
      'name': 'Percentages',
      'own': true,
      'keywords': <dynamic>[],
      'canonical': {
        'node_id': 'n1',
        'key': 'quantitative-aptitude/percentage',
        'label': 'Percentage',
        'subject_label': 'Quantitative Aptitude',
        'status': 'suggested',
      },
    });
    expect((topic.canonical?.label, topic.canonical?.confirmed), ('Percentage', false));
    final old = ExamTopic.fromJson({
      'id': 't2',
      'subject': 'Maths',
      'name': 'Algebra',
      'own': true,
      'keywords': <dynamic>[],
    });
    expect(old.canonical, isNull); // older servers send none
  });

  testAppWidgets('the learner confirms that their topic is the shared one', (tester, db) async {
    final exams = await openTopics(tester, db, [
      const ExamTopic(
        id: 't1',
        subject: 'Maths',
        name: 'Percentages',
        own: true,
        canonical: suggestion,
      ),
    ]);

    await scrollTo(tester, find.text('Yes, same'));
    expect(
      find.text('Same as the shared topic "Percentage" (Quantitative Aptitude)?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Yes, same'));
    await tester.pumpAndSettle();

    expect(exams.calls, contains('canonical:t1:n-percent:true'));
    expect(
      find.text('Counts as the shared topic "Percentage" (Quantitative Aptitude)'),
      findsOneWidget,
    );
    expect(find.text('Yes, same'), findsNothing);
  });

  testAppWidgets('saying no removes the suggestion', (tester, db) async {
    final exams = await openTopics(tester, db, [
      const ExamTopic(
        id: 't1',
        subject: 'Maths',
        name: 'Percentages',
        own: true,
        canonical: suggestion,
      ),
    ]);

    await scrollTo(tester, find.text('No'));
    await tester.tap(find.widgetWithText(TextButton, 'No'));
    await tester.pumpAndSettle();

    expect(exams.calls, contains('canonical:t1:n-percent:false'));
    expect(find.textContaining('Same as the shared topic'), findsNothing);
  });
}
