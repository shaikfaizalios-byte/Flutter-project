import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';

import '../../helpers/pump_app.dart';

Future<void> openStudy(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> seedConcept(WidgetTester tester, AppDatabase db, String title, {String? topic}) =>
    seed(
      tester,
      () => LocalConceptsRepository(db).create(
        ConceptDraft(
          examCode: 'SSC_CGL',
          title: title,
          subject: 'Maths',
          topic: topic ?? title.split(' ').first,
          language: ContentLanguage.english,
        ),
      ),
    );

void main() {
  testAppWidgets('shows an empty state when there are no concepts', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openStudy(tester);

    expect(find.text('No concepts yet'), findsOneWidget);
    expect(find.text('Add concept'), findsOneWidget);
  });

  testAppWidgets('creates a concept and lists it', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openStudy(tester);

    await tester.tap(find.text('Add concept'));
    await tester.pumpAndSettle();
    expect(find.text('New concept'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing, reason: 'form is full screen');

    await tester.tap(find.text('SSC CHSL'));
    await tester.enterText(field('Title'), 'Synonyms set 1');
    await tester.enterText(field('Subject'), 'English');
    await tester.enterText(field('Topic'), 'Vocabulary');
    await tester.enterText(field('Tags (optional)'), 'PYQ, words');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Concept saved'), findsOneWidget);
    expect(find.text('Synonyms set 1'), findsOneWidget);
    expect(find.text('SSC CHSL · English › Vocabulary'), findsOneWidget);

    final stored = await seed(tester, () => LocalConceptsRepository(db).watch().first);
    expect(stored.single.tags, ['pyq', 'words']);
    expect(stored.single.examCode, 'SSC_CHSL');
  });

  testAppWidgets('validates required fields and does not save', (tester, db) async {
    await pumpPrepLoopApp(tester, db);
    await openStudy(tester);
    await tester.tap(find.text('Add concept'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required.'), findsNWidgets(3));
    expect(find.text('New concept'), findsOneWidget);
    expect(await seed(tester, () => LocalConceptsRepository(db).watch().first), isEmpty);
  });

  testAppWidgets('search filters and reports no matches', (tester, db) async {
    await seedConcept(tester, db, 'Ratio tricks');
    await seedConcept(tester, db, 'Percentage basics');
    await pumpPrepLoopApp(tester, db);
    await openStudy(tester);

    await tester.enterText(find.byType(SearchBar), 'ratio');
    await tester.pumpAndSettle();
    expect(find.text('Ratio tricks'), findsOneWidget);
    expect(find.text('Percentage basics'), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No concepts match "zzz".'), findsOneWidget);
  });

  testAppWidgets('archiving removes the concept and undo restores it', (tester, db) async {
    await seedConcept(tester, db, 'Coding-decoding', topic: 'Coding');
    await pumpPrepLoopApp(tester, db);
    await openStudy(tester);

    await tester.tap(find.byTooltip('Options for Coding-decoding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Coding-decoding'), findsNothing);
    expect(find.text('Concept archived'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Coding-decoding'), findsOneWidget);
  });

  testAppWidgets('concept screens are localised in Hindi', (tester, db) async {
    await pumpPrepLoopApp(tester, db, deviceLocale: const Locale('hi'));
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('अध्ययन')),
    );
    await tester.pumpAndSettle();

    expect(find.text('अभी कोई कॉन्सेप्ट नहीं है'), findsOneWidget);
    await tester.tap(find.text('कॉन्सेप्ट जोड़ें'));
    await tester.pumpAndSettle();
    expect(find.text('नया कॉन्सेप्ट'), findsOneWidget);
  });
}
