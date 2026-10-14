import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/database/app_database.dart';
import 'core/utils/app_log.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/auth_api.dart';
import 'features/settings/application/app_preferences.dart';
import 'features/settings/data/preferences_repository.dart';
import 'features/study_plan/application/study_profile_controller.dart';
import 'features/study_plan/data/study_profile_repository.dart';
import 'features/study_plan/domain/study_profile.dart';

const _storageStartupTimeout = Duration(seconds: 3);

/// Builds configuration, opens local storage and starts the app. Keep platform
/// initialisation (notifications, crash reporting) here as it is introduced.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicences();

  final config = AppConfig.fromEnvironment();
  final database = AppDatabase.open();

  // Load startup state before the first frame so the UI starts in the right
  // language, theme and route (onboarding or Home). If local storage fails, start
  // with defaults: screens that need the database show their own error state.
  // The timeout guarantees a first frame even if opening storage hangs (seen in
  // restricted web views).
  final preferences = await _loadOrDefault(
    'preferences',
    PreferencesRepository(database).load,
    const AppPreferences(),
  );
  final tokenStore = SecureTokenStore();
  final session = await _loadOrDefault<AuthSession?>('session', tokenStore.read, null);
  final studyProfile = await _loadOrDefault(
    'study profile',
    StudyProfileRepository(database).load,
    const StudyProfile(),
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appDatabaseProvider.overrideWithValue(database),
        initialPreferencesProvider.overrideWithValue(preferences),
        initialStudyProfileProvider.overrideWithValue(studyProfile),
        tokenStoreProvider.overrideWithValue(tokenStore),
        initialAuthSessionProvider.overrideWithValue(session),
      ],
      child: const PrepLoopApp(),
    ),
  );
}

Future<T> _loadOrDefault<T>(String what, Future<T> Function() load, T fallback) async {
  try {
    return await load().timeout(_storageStartupTimeout);
  } on Object catch (error, stack) {
    logError('Loading $what failed', error, stack);
    return fallback;
  }
}

/// Bundled fonts must ship their licence (SIL OFL 1.1); shown on the licences page.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/noto_sans_devanagari/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Noto Sans Devanagari'], text);
  });
}
