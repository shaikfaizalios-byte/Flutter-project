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
  static const documents = '/study/documents';
  static const revision = '/study/revision';
  static const revisionReview = '/study/revision/review';
  static const practice = '/practice';
  static const questionBank = '/practice/bank';
  static const bookmarks = '/practice/bookmarks';
  static const incorrect = '/practice/incorrect';
  static const repeats = '/practice/repeats';
  static const progress = '/progress';
  static const profile = '/profile';
  static const myExams = '/profile/exams';

  static String concept(String id) => '/study/concepts/$id';
  static String editConcept(String id) => '/study/concepts/$id/edit';
  static String documentReview(String id) => '/study/documents/$id';
  static String question(String id) => '/questions/$id';
  static String practiceSession(String id) => '/practice/sessions/$id';
  static String examTopics(String code) => '/profile/exams/$code';
}
