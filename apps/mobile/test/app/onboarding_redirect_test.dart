import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/app/router.dart';

void main() {
  group('onboardingRedirect', () {
    test('sends first-run users to onboarding from anywhere', () {
      for (final path in ['/', AppRoutes.home, AppRoutes.study, '/study/concepts/x']) {
        expect(
          onboardingRedirect(onboardingCompleted: false, path: path),
          AppRoutes.onboarding,
          reason: path,
        );
      }
    });

    test('lets first-run users stay on onboarding', () {
      expect(onboardingRedirect(onboardingCompleted: false, path: AppRoutes.onboarding), isNull);
    });

    test('never shows onboarding again once completed', () {
      expect(
        onboardingRedirect(onboardingCompleted: true, path: AppRoutes.onboarding),
        AppRoutes.home,
      );
      expect(onboardingRedirect(onboardingCompleted: true, path: '/'), AppRoutes.home);
      expect(onboardingRedirect(onboardingCompleted: true, path: AppRoutes.study), isNull);
    });
  });
}
