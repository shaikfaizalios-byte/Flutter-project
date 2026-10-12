/// Route paths. Kept separate from the router so features can link to routes
/// without importing every screen.
abstract final class AppRoutes {
  static const home = '/home';
  static const study = '/study';
  static const newConcept = '/study/concepts/new';
  static const practice = '/practice';
  static const progress = '/progress';
  static const profile = '/profile';
}
