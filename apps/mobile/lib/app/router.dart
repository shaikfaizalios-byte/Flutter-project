import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/widgets/empty_state.dart';
import '../features/analytics/presentation/progress_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/practice/presentation/practice_screen.dart';
import '../features/concepts/presentation/concept_form_screen.dart';
import '../features/concepts/presentation/concept_list_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

export 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    redirect: (context, state) => state.uri.path == '/' ? AppRoutes.home : null,
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          _branch(AppRoutes.home, const HomeScreen()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.study,
                builder: (context, state) => const ConceptListScreen(),
                routes: [
                  GoRoute(
                    path: 'concepts/new',
                    // Full screen above the navigation bar while editing.
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ConceptFormScreen(),
                  ),
                ],
              ),
            ],
          ),
          _branch(AppRoutes.practice, const PracticeScreen()),
          _branch(AppRoutes.progress, const ProgressScreen()),
          _branch(AppRoutes.profile, const SettingsScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: l10n.notFoundTitle,
        action: FilledButton(onPressed: () => context.go(AppRoutes.home), child: Text(l10n.goHome)),
      ),
    );
  }
}
