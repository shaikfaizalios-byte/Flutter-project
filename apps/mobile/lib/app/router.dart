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
import '../features/practice/presentation/practice_hub_screen.dart';
import '../features/practice/presentation/question_list_screen.dart';
import '../features/practice/presentation/session_screen.dart';
import '../features/question_bank/presentation/document_review_screen.dart';
import '../features/question_bank/presentation/question_bank_screen.dart';
import '../features/question_bank/presentation/question_review_screen.dart';
import '../features/revision/presentation/review_screen.dart';
import '../features/revision/presentation/revision_screen.dart';
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
      GoRoute(
        path: '/questions/:id',
        builder: (context, state) => QuestionReviewScreen(questionId: state.pathParameters['id']!),
      ),
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
                    routes: [
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) =>
                            DocumentReviewScreen(documentId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'revision',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const RevisionScreen(),
                    routes: [
                      GoRoute(
                        path: 'review',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => const ReviewScreen(),
                      ),
                    ],
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.practice,
                builder: (context, state) => const PracticeHubScreen(),
                routes: [
                  GoRoute(
                    path: 'bank',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const QuestionBankScreen(),
                  ),
                  GoRoute(
                    path: 'bookmarks',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        const PracticeQuestionListScreen(kind: PracticeQuestionList.bookmarks),
                  ),
                  GoRoute(
                    path: 'incorrect',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        const PracticeQuestionListScreen(kind: PracticeQuestionList.incorrect),
                  ),
                  GoRoute(
                    path: 'sessions/:id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        SessionScreen(sessionId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
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
