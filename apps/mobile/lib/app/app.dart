import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/generated/app_localizations.dart';
import '../features/reminders/application/reminder_controller.dart';
import '../features/settings/application/app_preferences.dart';
import '../features/sync/application/sync_controller.dart';
import 'app_shell.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class PrepLoopApp extends ConsumerWidget {
  const PrepLoopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    // Keeps the daily reminder in sync for the app's lifetime (start, resume, changes).
    ref.listen(reminderControllerProvider, (_, _) {});
    // Keeps device data in sync with the account while the app runs.
    ref.listen(syncControllerProvider, (_, _) {});
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: prefs.themeMode,
      locale: prefs.language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) => DesktopFrame(router: router, child: child!),
    );
  }
}
