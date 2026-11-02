import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/features/concepts/data/local_concepts_repository.dart';
import 'package:preploop/features/concepts/domain/concept.dart';
import 'package:preploop/features/sync/data/sync_api.dart';

import '../../helpers/pump_app.dart';
import '../auth/auth_flow_test.dart' show openAccount;
import '../concepts/concept_detail_and_filters_test.dart' show addConcept, openStudy;

void main() {
  testAppWidgets('a conflict copy explains itself on its page', (tester, db) async {
    await addConcept(tester, db, title: 'Linear equations', tags: [syncConflictTag]);
    await pumpPrepLoopApp(tester, db);
    await openStudy(tester);

    await tester.tap(find.text('Linear equations'));
    await tester.pumpAndSettle();

    expect(find.text('Changed on two devices'), findsOneWidget);
    expect(find.textContaining('the note with the same title holds the other'), findsOneWidget);
  });

  testAppWidgets('Profile says when a sync kept both versions of a note', (tester, db) async {
    final note = await addConcept(tester, db, title: 'Original');
    final server = FakeSyncServer();
    await pumpPrepLoopApp(tester, db, syncServer: server);
    await openAccount(tester);
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    // Another device edits the note on the server, and this device edits it too.
    final stored = server.data('concept', note.id)!;
    final seq = (await server.pull(0)).changes.single.seq;
    await server.push([
      SyncChange(
        entity: 'concept',
        id: note.id,
        data: {...stored, 'title': 'Other device'},
        baseSeq: seq,
      ),
    ]);
    await seed(
      tester,
      () => LocalConceptsRepository(db).update(
        note.id,
        const ConceptDraft(
          examCode: 'SSC_CGL',
          title: 'This device',
          subject: 'Maths',
          topic: 'Algebra',
          language: ContentLanguage.english,
        ),
      ),
    );
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1 note was changed on two devices; both versions were kept.'),
      findsOneWidget,
    );
  });
}
