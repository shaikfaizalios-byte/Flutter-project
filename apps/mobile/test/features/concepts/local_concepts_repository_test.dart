import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';

import '../../helpers/pump_app.dart';

ConceptDraft draft({
  String title = 'Percentage basics',
  String topic = 'Percentage',
  String notes = '',
  List<String> tags = const [],
  ContentLanguage language = ContentLanguage.english,
}) => ConceptDraft(
  examCode: 'SSC_CGL',
  title: title,
  subject: 'Quantitative Aptitude',
  topic: topic,
  language: language,
  notes: notes,
  tags: tags,
);

void main() {
  late AppDatabase db;
  late DateTime now;
  late LocalConceptsRepository repo;

  setUp(() {
    db = createTestDatabase();
    now = DateTime.utc(2026, 10, 12, 9);
    repo = LocalConceptsRepository(db, clock: () => now);
  });

  test('create normalises input and assigns id and timestamps', () async {
    final concept = await repo.create(
      const ConceptDraft(
        examCode: 'SSC_CHSL',
        title: '  Synonyms  ',
        subject: 'English',
        topic: 'Vocabulary',
        subtopic: '  ',
        language: ContentLanguage.hindi,
        tags: ['PYQ', 'pyq', ' ', 'Formula'],
        sourceReference: '',
      ),
    );

    expect(concept.id, hasLength(36));
    expect(concept.title, 'Synonyms');
    expect(concept.subtopic, isNull);
    expect(concept.sourceReference, isNull);
    expect(concept.tags, ['pyq', 'formula']);
    expect(concept.language, ContentLanguage.hindi);
    expect(concept.createdAt, now);
    expect(concept.updatedAt, now);
  });

  test('create rejects invalid drafts without writing', () async {
    final invalid = draft(title: '   ', tags: List.generate(21, (i) => 't$i'));

    await expectLater(
      repo.create(invalid),
      throwsA(
        isA<InvalidConceptException>().having((e) => e.errors, 'errors', {
          'title': FieldError.required,
          'tags': FieldError.tooMany,
        }),
      ),
    );
    expect(await repo.watch().first, isEmpty);
  });

  test('watch orders by most recently updated first', () async {
    await repo.create(draft(title: 'Older'));
    now = now.add(const Duration(minutes: 1));
    await repo.create(draft(title: 'Newer'));

    final titles = (await repo.watch().first).map((c) => c.title);

    expect(titles, ['Newer', 'Older']);
  });

  test('search matches title, notes and topic, including Hindi text', () async {
    await repo.create(draft(title: 'Ratio tricks', topic: 'Ratio'));
    await repo.create(draft(title: 'Percent', notes: 'successive discount'));
    await repo.create(
      draft(title: 'प्रतिशत सूत्र', topic: 'प्रतिशत', language: ContentLanguage.hindi),
    );

    Future<List<String>> search(String q) async =>
        (await repo.watch(query: q).first).map((c) => c.title).toList();

    expect(await search('RATIO'), ['Ratio tricks']);
    expect(await search('discount'), ['Percent']);
    expect(await search('प्रतिशत'), ['प्रतिशत सूत्र']);
    expect(await search('  '), hasLength(3));
  });

  test('search treats LIKE wildcards literally', () async {
    await repo.create(draft(title: 'Plain'));
    await repo.create(draft(title: '10% discount'));
    await repo.create(draft(title: 'snake_case'));

    expect((await repo.watch(query: '%').first).map((c) => c.title), ['10% discount']);
    expect((await repo.watch(query: '_').first).map((c) => c.title), ['snake_case']);
  });

  test('archive hides a concept, keeps the first timestamp, and can be undone', () async {
    final concept = await repo.create(draft());
    final archivedAt = now.add(const Duration(hours: 1));
    now = archivedAt;

    await repo.setArchived(concept.id, archived: true);
    now = now.add(const Duration(hours: 1));
    await repo.setArchived(concept.id, archived: true);

    expect(await repo.watch().first, isEmpty);
    final archived = (await repo.watch(includeArchived: true).first).single;
    expect(archived.archivedAt, archivedAt);

    await repo.setArchived(concept.id, archived: false);
    expect((await repo.watch().first).single.isArchived, isFalse);
  });

  test('watch re-emits when data changes', () async {
    final emissions = repo.watch().map((list) => list.length);
    final expectation = expectLater(emissions, emitsInOrder([0, 1]));

    await Future<void>.delayed(Duration.zero);
    await repo.create(draft());

    await expectation;
  });
}
