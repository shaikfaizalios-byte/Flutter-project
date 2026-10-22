import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';

/// Where an active subscription comes from.
enum PlusSource {
  /// Started from the app on a development server (no payment).
  test,

  /// Given by the PrepLoop team.
  operator,
  play,
  web;

  static PlusSource? fromCode(String? code) => code == null ? null : PlusSource.values.byName(code);
}

/// The account's PrepLoop Plus state. The server decides it; the app only shows it.
@immutable
class PlusStatus {
  const PlusStatus({
    required this.active,
    required this.aiUsedThisMonth,
    required this.aiMonthlyAllowance,
    required this.periodResetsAt,
    this.source,
    this.activeUntil,
    this.testMode = false,
    this.purchasesAvailable = false,
  });

  factory PlusStatus.fromJson(Map<String, dynamic> json) => PlusStatus(
    active: json['active'] as bool,
    source: PlusSource.fromCode(json['source'] as String?),
    activeUntil: switch (json['active_until']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    aiUsedThisMonth: json['ai_used_this_month'] as int,
    aiMonthlyAllowance: json['ai_monthly_allowance'] as int,
    periodResetsAt: DateTime.parse(json['period_resets_at'] as String),
    testMode: json['test_mode'] as bool,
    purchasesAvailable: json['purchases_available'] as bool,
  );

  final bool active;
  final PlusSource? source;
  final DateTime? activeUntil;

  /// Successful AI requests this calendar month (UTC), and the monthly allowance with Plus.
  final int aiUsedThisMonth;
  final int aiMonthlyAllowance;
  final DateTime periodResetsAt;

  /// The server lets learners start a free test subscription (development only).
  final bool testMode;

  /// Store purchases (Google Play, web payments) can be made.
  final bool purchasesAvailable;
}

/// Days of a test subscription started from the app.
const plusTestDays = 7;

abstract interface class PlusRepository {
  Future<PlusStatus> status();

  Future<PlusStatus> startTest({int days = plusTestDays});

  Future<PlusStatus> endTest();
}

class RemotePlusRepository implements PlusRepository {
  RemotePlusRepository(this._dio);

  final Dio _dio;

  static const _path = '/api/v1/me/plus';

  @override
  Future<PlusStatus> status() =>
      _guard(() async => PlusStatus.fromJson((await _dio.get<Map<String, dynamic>>(_path)).data!));

  @override
  Future<PlusStatus> startTest({int days = plusTestDays}) => _guard(
    () async => PlusStatus.fromJson(
      (await _dio.post<Map<String, dynamic>>('$_path/test', data: {'days': days})).data!,
    ),
  );

  @override
  Future<PlusStatus> endTest() => _guard(
    () async => PlusStatus.fromJson((await _dio.delete<Map<String, dynamic>>('$_path/test')).data!),
  );

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final plusRepositoryProvider = Provider<PlusRepository>(
  (ref) => RemotePlusRepository(ref.watch(dioProvider)),
);

/// The account's Plus status (errors are shown, not retried silently).
final plusStatusProvider = FutureProvider.autoDispose<PlusStatus>(
  (ref) => ref.watch(plusRepositoryProvider).status(),
  retry: (_, _) => null,
);
