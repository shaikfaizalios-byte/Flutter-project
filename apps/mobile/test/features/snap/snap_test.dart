import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/core/localization/content_language.dart';
import 'package:preploop/features/snap/data/snap_repository.dart';
import 'package:preploop/features/snap/presentation/snap_screen.dart';

import '../../helpers/pump_app.dart';

class FakeSnapRepository implements SnapRepository {
  final calls = <String>[];
  AppFailure? failure;

  @override
  Future<SnapReading> readPhoto({
    required String examCode,
    required String name,
    required List<int> bytes,
    required ContentLanguage language,
  }) async {
    calls.add('photo:$examCode:$name:${language.code}');
    final next = failure;
    if (next != null) throw next;
    return const SnapReading(
      text: 'A train covers 360 km in 4 hours.',
      lowConfidence: true,
      matches: [
        SnapMatch(
          kind: SnapMatchKind.question,
          label: 'chsl-2024.pdf · Q.12',
          snippet: 'A train covers 360 km in 4 hours. Find its speed.',
          verified: true,
          questionId: 'q1',
        ),
        SnapMatch(
          kind: SnapMatchKind.page,
          label: 'notes.pdf, page 3',
          snippet: 'Speed = distance',
        ),
      ],
    );
  }

  @override
  Future<List<SnapMatch>> match({required String examCode, required String text}) async {
    calls.add('match:$examCode:$text');
    return const [];
  }
}

Future<FakeSnapRepository> openSnap(WidgetTester tester, AppDatabase db) async {
  final snap = FakeSnapRepository();
  await pumpPrepLoopApp(
    tester,
    db,
    studyProfile: onboardedProfile.copyWith(examCodes: ['SSC_CHSL']),
    extraOverrides: [
      snapRepositoryProvider.overrideWithValue(snap),
      snapPhotoProvider.overrideWithValue(
        ({required bool camera}) async => (name: camera ? 'camera.jpg' : 'q.jpg', bytes: [1, 2, 3]),
      ),
    ],
  );
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Study')));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Snap a question'));
  await tester.pumpAndSettle();
  return snap;
}

Future<void> choosePhoto(WidgetTester tester) async {
  await tester.tap(find.text('Choose a photo'));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('a photo is read and matched; the learner can correct the text', (
    tester,
    db,
  ) async {
    final snap = await openSnap(tester, db);
    expect(find.byType(SnapScreen), findsOneWidget);
    expect(find.textContaining("The photo isn't kept"), findsOneWidget);
    await choosePhoto(tester);

    expect(snap.calls, ['photo:SSC_CHSL:q.jpg:en']);
    expect(find.textContaining('may have misread'), findsOneWidget);
    expect(find.text('chsl-2024.pdf · Q.12'), findsOneWidget);
    expect(find.textContaining('as read from the page'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'average speed train');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search again'));
    await tester.pumpAndSettle();
    expect(snap.calls.last, 'match:SSC_CHSL:average speed train');
    expect(find.textContaining('Nothing like it'), findsOneWidget);
  });

  testAppWidgets('a photo can be taken with the camera', (tester, db) async {
    final snap = await openSnap(tester, db);
    await tester.tap(find.text('Take a photo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(snap.calls, ['photo:SSC_CHSL:camera.jpg:en']);
  });

  testAppWidgets('a photo that cannot be read says so', (tester, db) async {
    final snap = await openSnap(tester, db);
    snap.failure = const ServerFailure(statusCode: 422, code: 'photo_unreadable');
    await choosePhoto(tester);
    expect(find.textContaining('No text could be read'), findsOneWidget);
  });
}
