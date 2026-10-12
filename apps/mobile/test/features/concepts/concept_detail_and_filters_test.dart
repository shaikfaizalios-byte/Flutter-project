import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/concepts/domain/concepts_repository.dart';

import '../../helpers/pump_app.dart';

Future<Concept> addConcept(
  WidgetTester tester,
  AppDatabase db, {
  required String title,
  String exam = 'SSC_CGL',
  String subject = 'Maths',
  String topic = 'Algebra',
  String notes = '',
  List<String> tags = const [],
}) => seed(
  tester,
  () => LocalConceptsRepository(db).create(
    ConceptDraft(
      examCode: exam,
      title: title,
      subject: subject,
      topic: topic,
      notes: notes,
      tags: tags,
      language: ContentLanguage.english,
    ),
  ),
);

Future<void> openStudy(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
  await tester.pumpAndSettle();
}

Future<void> chooseFilter(WidgetTester tester, String label, String option) async {
  await tester.tap(find.byTooltip('Filter by $label'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

List<String> visibleTitles(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((t) => (t.title! as Text).data!)
    .toList();

void main() {
  group('details', () {
    testAppWidgets('tapping a concept opens its details', (tester, db) async {
      await addConcept(
        tester,
        db,
        title: 'Linear equations',
        notes: 'ax + b = 0',
        tags: ['formula'],
      );
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);

      await tester.tap(find.text('Linear equations'));
      await tester.pumpAndSettle();

      expect(find.text('Concept'), findsOneWidget);
      expect(find.text('Maths › Algebra'), findsOneWidget);
      expect(find.text('#formula'), findsOneWidget);
      expect(find.text('ax + b = 0'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testAppWidgets('editing updates the concept', (tester, db) async {
      final concept = await addConcept(tester, db, title: 'Old title');
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);
      await tester.tap(find.text('Old title'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit concept'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Old title'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Old title'), 'New title');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('New title'), findsOneWidget);
      final stored = await seed(
        tester,
        () => LocalConceptsRepository(db).watchById(concept.id).first,
      );
      expect(stored!.title, 'New title');
      expect(stored.createdAt, concept.createdAt);
    });

    testAppWidgets('delete asks for confirmation; cancel keeps the concept', (tester, db) async {
      await addConcept(tester, db, title: 'Keep me');
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);
      await tester.tap(find.text('Keep me'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this concept?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Keep me'), findsOneWidget);
      expect(await seed(tester, () => LocalConceptsRepository(db).watch().first), hasLength(1));
    });

    testAppWidgets('confirmed delete removes the concept permanently', (tester, db) async {
      await addConcept(tester, db, title: 'Delete me');
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);
      await tester.tap(find.text('Delete me'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Concept deleted'), findsOneWidget);
      expect(find.text('No concepts yet'), findsOneWidget);
    });

    testAppWidgets('archived concepts show a banner and can be restored', (tester, db) async {
      final concept = await addConcept(tester, db, title: 'Old notes');
      await seed(tester, () => LocalConceptsRepository(db).setArchived(concept.id, archived: true));
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old notes'));
      await tester.pumpAndSettle();

      expect(find.text('This concept is archived and hidden from your main list.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();

      expect(find.text('Concept restored'), findsOneWidget);
      expect(find.textContaining('is archived'), findsNothing);
    });
  });

  group('filters', () {
    Future<void> seedMixed(WidgetTester tester, AppDatabase db) async {
      await addConcept(tester, db, title: 'Ratios', subject: 'Maths', topic: 'Ratio');
      await addConcept(tester, db, title: 'Averages', subject: 'Maths', topic: 'Average');
      await addConcept(
        tester,
        db,
        title: 'Synonyms',
        exam: 'SSC_CHSL',
        subject: 'English',
        topic: 'Vocabulary',
      );
    }

    testAppWidgets('filter by exam', (tester, db) async {
      await seedMixed(tester, db);
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);

      await chooseFilter(tester, 'Exam', 'SSC CHSL');

      expect(visibleTitles(tester), ['Synonyms']);
    });

    testAppWidgets('subject and topic choices come from the data', (tester, db) async {
      await seedMixed(tester, db);
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);

      await chooseFilter(tester, 'Subject', 'Maths');
      expect(visibleTitles(tester)..sort(), ['Averages', 'Ratios']);

      await tester.tap(find.byTooltip('Filter by Topic'));
      await tester.pumpAndSettle();
      // Only topics within Maths are offered.
      expect(find.text('Vocabulary'), findsNothing);
      await tester.tap(find.text('Ratio').last);
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Ratios']);
    });

    testAppWidgets('clear filters restores the full list', (tester, db) async {
      await seedMixed(tester, db);
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);
      await chooseFilter(tester, 'Exam', 'SSC CHSL');

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), hasLength(3));
      expect(find.text('Clear filters'), findsNothing);
    });

    testAppWidgets('no matches shows a filter-specific empty state', (tester, db) async {
      await addConcept(tester, db, title: 'Only CGL');
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);

      await chooseFilter(tester, 'Exam', 'SSC CHSL');

      expect(find.text('No concepts match these filters.'), findsOneWidget);
    });

    testAppWidgets('archived view lists only archived concepts', (tester, db) async {
      final archived = await addConcept(tester, db, title: 'Archived one');
      await addConcept(tester, db, title: 'Active one');
      await seed(
        tester,
        () => LocalConceptsRepository(db).setArchived(archived.id, archived: true),
      );
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);

      expect(visibleTitles(tester), ['Active one']);
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), ['Archived one']);
    });

    testAppWidgets('empty archive has its own message', (tester, db) async {
      await addConcept(tester, db, title: 'Active');
      await pumpPrepLoopApp(tester, db);
      await openStudy(tester);

      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();

      expect(find.text('No archived concepts.'), findsOneWidget);
    });
  });

  group('repository', () {
    test('facets are distinct case-insensitively and grouped by subject', () async {
      final repo = LocalConceptsRepository(createTestDatabase());
      ConceptDraft d(String exam, String subject, String topic) => ConceptDraft(
        examCode: exam,
        title: 't',
        subject: subject,
        topic: topic,
        language: ContentLanguage.english,
      );
      await repo.create(d('SSC_CGL', 'Maths', 'Ratio'));
      await repo.create(d('SSC_CGL', 'maths', 'ratio'));
      await repo.create(d('SSC_CHSL', 'English', 'Idioms'));

      final facets = await repo.watchFacets().first;

      expect(facets.examCodes, ['SSC_CGL', 'SSC_CHSL']);
      expect(facets.subjects, hasLength(2));
      expect(facets.topicsFor('MATHS'), hasLength(1));
      expect(facets.topicsFor(null), hasLength(2));
    });

    test('update keeps id and createdAt, bumps updatedAt, validates', () async {
      var now = DateTime.utc(2026, 10, 12);
      final repo = LocalConceptsRepository(createTestDatabase(), clock: () => now);
      final created = await repo.create(
        const ConceptDraft(
          examCode: 'SSC_CGL',
          title: 'A',
          subject: 'S',
          topic: 'T',
          language: ContentLanguage.english,
        ),
      );
      now = now.add(const Duration(hours: 1));

      final updated = await repo.update(
        created.id,
        const ConceptDraft(
          examCode: 'SSC_CHSL',
          title: 'B',
          subject: 'S',
          topic: 'T',
          language: ContentLanguage.hindi,
        ),
      );

      expect(updated.id, created.id);
      expect(updated.title, 'B');
      expect(updated.language, ContentLanguage.hindi);
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt, now);
      await expectLater(
        repo.update(
          created.id,
          const ConceptDraft(
            examCode: 'SSC_CGL',
            title: ' ',
            subject: 'S',
            topic: 'T',
            language: ContentLanguage.english,
          ),
        ),
        throwsA(isA<InvalidConceptException>()),
      );
      await expectLater(
        repo.update(
          'missing',
          const ConceptDraft(
            examCode: 'SSC_CGL',
            title: 'X',
            subject: 'S',
            topic: 'T',
            language: ContentLanguage.english,
          ),
        ),
        throwsA(isA<ConceptNotFoundException>()),
      );
    });

    test('delete, watchById and active count', () async {
      final repo = LocalConceptsRepository(createTestDatabase());
      final a = await repo.create(
        const ConceptDraft(
          examCode: 'SSC_CGL',
          title: 'A',
          subject: 'S',
          topic: 'T',
          language: ContentLanguage.english,
        ),
      );
      final b = await repo.create(
        const ConceptDraft(
          examCode: 'SSC_CGL',
          title: 'B',
          subject: 'S',
          topic: 'T',
          language: ContentLanguage.english,
        ),
      );
      await repo.setArchived(b.id, archived: true);
      expect(await repo.watchActiveCount().first, 1);

      await repo.delete(a.id);

      expect(await repo.watchById(a.id).first, isNull);
      expect(await repo.watchActiveCount().first, 0);
      expect(await repo.watch(const ConceptQuery(archived: true)).first, hasLength(1));
    });
  });
}
