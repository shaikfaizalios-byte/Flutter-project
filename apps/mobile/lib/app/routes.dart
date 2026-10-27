/// Route paths. Kept separate from the router so features can link to routes
/// without importing every screen.
abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const forgotPassword = '/forgot-password';
  static const privacy = '/legal/privacy';
  static const terms = '/legal/terms';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const study = '/study';
  static const newConcept = '/study/concepts/new';

  /// A new concept with its subject and topic filled in.
  static String newConceptIn(String subject, String topic) =>
      Uri(path: newConcept, queryParameters: {'subject': subject, 'topic': topic}).toString();
  static const documents = '/study/documents';
  static const revision = '/study/revision';
  static const revisionReview = '/study/revision/review';
  static const practice = '/practice';
  static const questionBank = '/practice/bank';
  static const bookmarks = '/practice/bookmarks';
  static const incorrect = '/practice/incorrect';
  static const repeats = '/practice/repeats';

  /// Repeated models of the shared bank (the starter papers).
  static const repeatsShared = '/practice/repeats?view=shared';
  static const progress = '/progress';
  static const weeklyReview = '/progress/week';
  static const profile = '/profile';
  static const myExams = '/profile/exams';
  static const suggestions = '/profile/suggestions';
  static const plus = '/profile/plus';

  static String concept(String id) => '/study/concepts/$id';
  static String editConcept(String id) => '/study/concepts/$id/edit';
  static String documentReview(String id) => '/study/documents/$id';
  static String question(String id) => '/questions/$id';
  static String practiceSession(String id) => '/practice/sessions/$id';
  static String examTopics(String code, {bool importSyllabus = false}) =>
      '/profile/exams/$code${importSyllabus ? '?syllabus=1' : ''}';
}
