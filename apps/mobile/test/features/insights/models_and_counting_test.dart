import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/localization/generated/app_localizations.dart';
import 'package:preploop/features/exams/data/exams_repository.dart';
import 'package:preploop/features/exams/domain/exam_topics.dart';
import 'package:preploop/features/exams/presentation/topic_models_screen.dart';
import 'package:preploop/features/insights/domain/repeats.dart';

import '../../helpers/fake_exams.dart';

const shared = TopicModel(id: 'm1', topicId: 't', name: 'Shared one', own: false);
const mine = TopicModel(id: 'm2', topicId: 't', name: 'My model', own: true);

Future<FakeExamsRepository> pump(WidgetTester tester, List<TopicModel> models) async {
  final exams = FakeExamsRepository()..models = models;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [examsRepositoryProvider.overrideWithValue(exams)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopicModelsScreen(topicId: 't', topicName: 'Percentage'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return exams;
}

void main() {
  RepeatCounts counts(double? marks) => RepeatCounts(questions: 1, papers: 1, marks: marks);
  TopicRepeat topic(String name, double? marks) =>
      TopicRepeat(topicId: name, subject: 'S', name: name, confirmed: counts(marks), unreviewed: 0);

  test('a report reads its counting unit, and older reports count papers', () {
    final json = <String, dynamic>{
      'papers': {'total': 1, 'dated': 0, 'undated': 1, 'years': <int>[]},
      'topics': <dynamic>[],
      'similar_groups': <dynamic>[],
    };
    expect(RepeatsReport.fromJson(json).countingUnit, 'paper');
    expect(RepeatsReport.fromJson({...json, 'counting_unit': 'session'}).countingUnit, 'session');
  });

  test('marks are read, and missing marks stay missing', () {
    final read = RepeatCounts.fromJson({
      'questions': 1,
      'papers': 1,
      'marks': 15,
      'years': <dynamic>[],
    });
    expect(read.marks, 15.0);
    expect(
      RepeatCounts.fromJson({'questions': 1, 'papers': 1, 'years': <dynamic>[]}).marks,
      isNull,
    );
  });

  test('a name suggestion is read', () {
    final read = NameSuggestion.fromJson({
      'topic_id': 't',
      'topic_name': 'Percentage',
      'papers': 3,
      'questions': [
        {
          'question_id': 'q1',
          'document_filename': 'a.pdf',
          'stem_excerpt': 'A train',
          'verified': true,
        },
      ],
    });
    expect((read.topicName, read.papers), ('Percentage', 3));
    expect(read.questions.single.questionId, 'q1');
  });

  test('topics with the most marks come first, unknown marks last, ties keep their order', () {
    final sorted = byMarks([
      topic('none', null),
      topic('five', 5),
      topic('ten', 10),
      topic('also-five', 5),
    ]);
    expect(sorted.map((t) => t.name), ['ten', 'five', 'also-five', 'none']);
  });

  test('marks only matter when they differ', () {
    expect(marksVary([topic('a', null), topic('b', null)]), isFalse);
    expect(marksVary([topic('a', 5), topic('b', 5)]), isFalse);
    expect(marksVary([topic('a', 5), topic('b', 10)]), isTrue);
    expect(marksVary([topic('a', 5), topic('b', null)]), isTrue);
  });

  testWidgets('shared models are read-only', (tester) async {
    await pump(tester, const [shared]);
    expect(find.text('Shared one'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('own models can be renamed', (tester) async {
    final exams = await pump(tester, const [shared, mine]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Better name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(exams.calls, contains('renameModel:m2:Better name'));
  });

  testWidgets('merging offers the other models', (tester) async {
    final exams = await pump(tester, const [shared, mine]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shared one').last);
    await tester.pumpAndSettle();
    expect(exams.calls, contains('mergeModel:m2:m1'));
  });

  testWidgets('merging needs another model to merge into', (tester) async {
    await pump(tester, const [mine]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Merge'), findsNothing);
  });

  testWidgets('a blank name is not saved', (tester) async {
    final exams = await pump(tester, const []);
    await tester.tap(find.text('Add a model'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(exams.calls.where((c) => c.startsWith('createModel')), isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('answer formats are added on request', (tester) async {
    final exams = await pump(tester, const []);
    await tester.tap(find.text('Add answer formats'));
    await tester.pumpAndSettle();
    expect(exams.calls, contains('addDefaultModels:t'));
  });
}
