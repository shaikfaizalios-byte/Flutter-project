import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/database/app_database.dart';
import 'core/utils/app_log.dart';
import 'features/settings/application/app_preferences.dart';
import 'features/settings/data/preferences_repository.dart';

const _storageStartupTimeout = Duration(seconds: 3);

/// Builds configuration, opens local storage and starts the app. Keep platform
/// initialisation (notifications, crash reporting) here as it is introduced.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final database = AppDatabase.open();

  // Load preferences before the first frame so the UI starts in the right
  // language and theme. If local storage fails, start with defaults: screens
  // that need the database show their own error state. The timeout guarantees
  // a first frame even if opening storage hangs (seen in restricted web views).
  var preferences = const AppPreferences();
  try {
    preferences = await PreferencesRepository(database).load().timeout(_storageStartupTimeout);
  } on Object catch (error, stack) {
    logError('Loading preferences failed', error, stack);
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appDatabaseProvider.overrideWithValue(database),
        initialPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const PrepLoopApp(),
    ),
  );
}
