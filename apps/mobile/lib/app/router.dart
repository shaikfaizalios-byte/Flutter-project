import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/widgets/empty_state.dart';
import '../features/analytics/presentation/progress_screen.dart';
import '../features/concepts/presentation/concept_detail_screen.dart';
import '../features/concepts/presentation/concept_form_screen.dart';
import '../features/concepts/presentation/concept_list_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/practice/presentation/practice_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/study_plan/application/study_profile_controller.dart';
import 'app_shell.dart';
import 'routes.dart';

export 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pure redirect rule, separated for testing: first-run users go to onboarding,
/// and onboarding is not reachable again once completed.
String? onboardingRedirect({required bool onboardingCompleted, required String path}) {
  if (!onboardingCompleted && path != AppRoutes.onboarding) return AppRoutes.onboarding;
  if (onboardingCompleted && (path == AppRoutes.onboarding || path == '/')) return AppRoutes.home;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Bridges Riverpod state to GoRouter so redirects re-run when onboarding completes,
  // without rebuilding the router (which would reset navigation).
  final onboardingDone = ValueNotifier<bool>(
    ref.read(studyProfileProvider.select((p) => p.onboardingCompleted)),
  );
  ref.listen(
    studyProfileProvider.select((p) => p.onboardingCompleted),
    (_, done) => onboardingDone.value = done,
  );

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: onboardingDone,
    redirect: (context, state) =>
        onboardingRedirect(onboardingCompleted: onboardingDone.value, path: state.uri.path),
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      GoRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
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
                  // Concept and document screens are full screen above the navigation bar.
                  GoRoute(
                    path: 'documents',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const DocumentsScreen(),
                  ),
                  GoRoute(
                    path: 'concepts/new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ConceptFormScreen(),
                  ),
                  GoRoute(
                    path: 'concepts/:id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        ConceptDetailScreen(conceptId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) =>
                            ConceptFormScreen(conceptId: state.pathParameters['id']),
                      ),
                    ],
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
  ref.onDispose(() {
    router.dispose();
    onboardingDone.dispose();
  });
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
