import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:preploop/app/app_features.dart';
import 'package:preploop/app/routes.dart';
import 'package:preploop/features/exams/domain/syllabus_tree.dart';
import 'package:preploop/features/exams/presentation/syllabus_tree_screen.dart';
import 'package:preploop/features/insights/domain/repeats.dart';

import '../../helpers/pump_app.dart';

final profilesOn = appFeaturesProvider.overrideWithValue(const AppFeatures(examProfiles: true));

SyllabusVersion version(String id, String name, {int? year, bool inForce = false}) =>
    SyllabusVersion(
      id: id,
      name: name,
      own: false,
      inForce: inForce,
      effectiveYear: year,
      tree: [
        SyllabusNode(
          name: 'Physics $id',
          levelLabel: 'Subject',
          children: const [
            SyllabusNode(
              name: 'Mechanics',
              levelLabel: 'Unit',
              children: [SyllabusNode(name: 'Projectiles', levelLabel: 'Topic')],
            ),
          ],
        ),
      ],
    );

void main() {
  test('an outline becomes a tree of any depth', () {
    final tree = parseOutline('Physics\n  Mechanics\n    Kinematics\n  Optics\n\nEssay\n');
    expect(tree.map((n) => n.name), ['Physics', 'Essay']);
    expect(tree[0].children.map((n) => n.name), ['Mechanics', 'Optics']);
    expect(tree[0].children[0].children.single.name, 'Kinematics');
    expect(tree[1].children, isEmpty);
  });

  test('a jump of several levels counts as one, and blank text is no tree', () {
    final tree = parseOutline('A\n      B\n  C');
    expect(tree.single.children.map((n) => n.name), ['B', 'C']);
    expect(parseOutline('  \n\n'), isEmpty);
  });

  test('a tree is sent with only what it states', () {
    expect(const SyllabusNode(name: 'A').toJson(), {'name': 'A'});
    expect(parseOutline('A\n  B').single.toJson(), {
      'name': 'A',
      'children': [
        {'name': 'B'},
      ],
    });
  });

  test('a dropped topic is read from the server, and is false when left out', () {
    final json = {'topic_id': 't', 'subject': 's', 'name': 'n'};
    expect(TopicRef.fromJson(json).dropped, isFalse);
    expect(TopicRef.fromJson({...json, 'dropped': true}).dropped, isTrue);
  });

  testAppWidgets('versions and the tree are shown; a syllabus can be built by hand', (
    tester,
    db,
  ) async {
    final exams = FakeExamsRepository()
      ..versions = [
        version('a', 'Old syllabus'),
        version('b', 'New syllabus', year: 2024, inForce: true),
      ];
    await pumpPrepLoopApp(tester, db, exams: exams, extraOverrides: [profilesOn]);
    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push<void>(AppRoutes.examSyllabus('SSC_CGL')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SyllabusTreeScreen), findsOneWidget);
    expect(find.text('In force'), findsOneWidget);
    expect(find.text('Physics b'), findsOneWidget);
    await tester.tap(find.text('Physics b'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mechanics'));
    await tester.pumpAndSettle();
    expect(find.text('Projectiles'), findsOneWidget);

    await tester.tap(find.text('Old syllabus'));
    await tester.pumpAndSettle();
    expect(find.text('Physics a'), findsOneWidget);

    await tester.tap(find.text('Build a syllabus'));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), 'My syllabus');
    await tester.enterText(fields.at(1), '2026');
    await tester.enterText(fields.at(2), 'Maths\n  Algebra');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(exams.builtName, 'My syllabus');
    expect(exams.builtYear, 2026);
    expect(exams.builtTree!.single.children.single.name, 'Algebra');
  });
}
