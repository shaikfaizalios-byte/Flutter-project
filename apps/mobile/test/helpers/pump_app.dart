import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/app.dart';
import 'package:preploop/core/config/app_config.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/settings/data/server_status_repository.dart';
import 'package:preploop/features/settings/domain/server_health.dart';

const testConfig = AppConfig(
  appName: 'PrepLoop',
  apiBaseUrl: 'http://test.invalid',
  flavor: AppFlavor.development,
);

/// Fake repository so widget tests never touch the network.
class FakeServerStatusRepository implements ServerStatusRepository {
  FakeServerStatusRepository({this.online = true});

  bool online;
  int calls = 0;

  @override
  Future<ServerHealth> fetchHealth() async {
    calls++;
    if (!online) throw const NetworkFailure();
    return const ServerHealth(version: '0.1.0', environment: 'test');
  }
}

Future<void> pumpPrepLoopApp(
  WidgetTester tester, {
  FakeServerStatusRepository? serverStatus,
  Locale? deviceLocale,
}) async {
  if (deviceLocale != null) {
    tester.platformDispatcher.localesTestValue = [deviceLocale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
  final overrides = <Override>[
    appConfigProvider.overrideWithValue(testConfig),
    serverStatusRepositoryProvider.overrideWithValue(serverStatus ?? FakeServerStatusRepository()),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: const PrepLoopApp()));
  await tester.pumpAndSettle();
}
