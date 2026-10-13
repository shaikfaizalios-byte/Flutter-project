/// Route paths. Kept separate from the router so features can link to routes
/// without importing every screen.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const study = '/study';
  static const newConcept = '/study/concepts/new';
  static const documents = '/study/documents';
  static const practice = '/practice';
  static const progress = '/progress';
  static const profile = '/profile';

  static String concept(String id) => '/study/concepts/$id';
  static String editConcept(String id) => '/study/concepts/$id/edit';
}
