import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/plus/data/plus_repository.dart';

/// PrepLoop Plus in memory: not subscribed, 300 AI requests a month, test mode as given.
/// [failure] makes every call fail.
class FakePlusRepository implements PlusRepository {
  FakePlusRepository({this.testMode = false, this.used = 0});

  bool testMode;
  int used;
  PlusSource? source;
  DateTime? activeUntil;
  AppFailure? failure;
  final calls = <String>[];

  PlusStatus get _status => PlusStatus(
    active: source != null,
    source: source,
    activeUntil: activeUntil,
    aiUsedThisMonth: used,
    aiMonthlyAllowance: 300,
    periodResetsAt: DateTime.utc(2026, 11),
    testMode: testMode,
  );

  @override
  Future<PlusStatus> status() async {
    if (failure != null) throw failure!;
    return _status;
  }

  @override
  Future<PlusStatus> startTest({int days = plusTestDays}) async {
    calls.add('start:$days');
    if (failure != null) throw failure!;
    source = PlusSource.test;
    activeUntil = DateTime.utc(2026, 10, 1).add(Duration(days: days));
    return _status;
  }

  @override
  Future<PlusStatus> endTest() async {
    calls.add('end');
    if (failure != null) throw failure!;
    source = null;
    activeUntil = null;
    return _status;
  }
}
