import 'package:preploop/features/practice/domain/cbt.dart';
import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/practice/data/practice_repository.dart';
import 'package:preploop/features/practice/domain/practice_models.dart';
import 'package:preploop/features/question_bank/domain/question.dart';

import 'fake_questions.dart';

import 'package:preploop/features/practice/domain/mistake_reason.dart';

class _FakeSession {
  _FakeSession({
    required this.id,
    required this.mode,
    required this.questions,
    required this.startedAt,
    this.deadline,
    this.formatName,
  });

  final String id;
  final SessionMode mode;
  final List<BankQuestion> questions;
  final DateTime startedAt;
  final DateTime? deadline;
  final String? formatName;
  int? perQuestionSeconds;

  /// Sectionally timed mock: the plan, the open section and when it opened.
  List<TimedSectionView> sections = const [];
  int currentSection = 0;
  DateTime? sectionStartedAt;
  final Map<int, int?> answers = {};
  final Map<int, String> typed = {};
  final Set<String> bookmarked = {};
  bool submitted = false;
  String? submitReason;
}

/// In-memory stand-in for the practice API that follows the server's rules: practice
/// answers are final with immediate feedback; mock answers can change, have no feedback
/// until submission, and the deadline is fixed by the "server" clock.
class FakePracticeRepository implements PracticeRepository {
  @override
  final bool newFormats = false;

  FakePracticeRepository({required this.serverNow, List<BankQuestion>? pool})
    : pool =
          pool ?? [bankQuestion(), bankQuestion(id: 'q2', number: 2, stem: 'Second?', answer: 3)];

  DateTime Function() serverNow;
  final List<BankQuestion> pool;
  final sessions = <String, _FakeSession>{};
  List<MockTestView> mocks = const [];

  /// When set, mocks are sectionally timed with this plan (like SSC CGL).
  List<TimedSectionView> mockSections = const [];
  final finishedSections = <int>[];
  bool offline = false;
  String? startFailureCode;
  final submits = <String>[];

  /// Reasons the learner gave for wrong answers: (position, reason code or null).
  final mistakeReasons = <(int, String?)>[];

  @override
  Future<void> setMistakeReason(String sessionId, int position, MistakeReason? reason) async {
    mistakeReasons.add((position, reason?.code));
  }

  /// Time spent sent with each answer (position → milliseconds).
  final timesSpent = <int, int?>{};
  final List<PracticeRequest> practiceRequests = [];

  /// Offline practice is covered by the real repository's tests (practice_offline_test.dart).
  int offlineQuestions = 0;
  int offlineToUpload = 0;

  @override
  Future<int> refreshOfflinePack() async => offlineQuestions;

  @override
  Future<int> offlineQuestionCount() async => offlineQuestions;

  @override
  Future<int> offlineSessionsToUpload() async => offlineToUpload;

  @override
  Future<int> uploadOfflineSessions() async => 0;

  _FakeSession _get(String id) => sessions[id]!;

  @override
  Future<PracticeSessionView> startPractice(PracticeRequest request) async {
    practiceRequests.add(request);
    if (startFailureCode != null) {
      throw ServerFailure(statusCode: 422, code: startFailureCode, message: 'x');
    }
    final id = 'p${sessions.length + 1}';
    sessions[id] = _FakeSession(
      id: id,
      mode: SessionMode.practice,
      questions: pool,
      startedAt: serverNow(),
    )..perQuestionSeconds = request.perQuestionSeconds;
    return _view(sessions[id]!);
  }

  @override
  Future<List<MockTestView>> mockTests() async => mocks;

  /// Questions the starter check would ask (0: none available).
  int starterCheckQuestions = 0;

  @override
  Future<int> starterCheckSize(String examCode) async => starterCheckQuestions;

  @override
  Future<PracticeSessionView> startStarterCheck(String examCode) async {
    if (starterCheckQuestions == 0) {
      throw const ServerFailure(statusCode: 422, code: 'no_questions_available');
    }
    final id = 'd${sessions.length + 1}';
    sessions[id] = _FakeSession(
      id: id,
      mode: SessionMode.diagnostic,
      questions: pool,
      startedAt: serverNow(),
    );
    return _view(sessions[id]!);
  }

  @override
  Future<PracticeSessionView> startMock(String formatCode, {String? section}) async {
    final id = 'm${sessions.length + 1}';
    sessions[id] =
        _FakeSession(
            id: id,
            mode: SessionMode.mock,
            questions: pool,
            startedAt: serverNow(),
            deadline: serverNow().add(const Duration(minutes: 60)),
            formatName: 'SSC CHSL 2026 Tier-I',
          )
          ..sections = mockSections
          ..sectionStartedAt = serverNow();
    return _view(sessions[id]!);
  }

  @override
  Future<PracticeSessionView> session(String id) async {
    if (offline) throw const NetworkFailure();
    _expire(_get(id));
    return _view(_get(id));
  }

  @override
  Future<List<SessionSummaryView>> history() async => [
    for (final s in sessions.values)
      SessionSummaryView(
        id: s.id,
        mode: s.mode,
        submitted: s.submitted,
        startedAt: s.startedAt,
        itemCount: s.questions.length,
        formatName: s.formatName,
        score: s.submitted ? _correct(s).toDouble() : null,
        maxScore: s.submitted ? s.questions.length.toDouble() : null,
      ),
  ];

  @override
  Future<PracticeSessionView> finishSection(String id, int fromSection) async {
    if (offline) throw const NetworkFailure();
    final s = _get(id);
    _expire(s);
    finishedSections.add(fromSection);
    if (!s.submitted && s.currentSection == fromSection) {
      s
        ..currentSection += 1
        ..sectionStartedAt = serverNow();
      if (s.currentSection >= s.sections.length) {
        s
          ..submitted = true
          ..submitReason = 'user';
      }
    }
    return _view(s);
  }

  @override
  Future<PracticeSessionView> submit(String id) async {
    if (offline) throw const NetworkFailure();
    final s = _get(id);
    submits.add(id);
    if (!s.submitted) {
      s
        ..submitted = true
        ..submitReason = 'user';
    }
    return _view(s);
  }

  @override
  Future<AnswerOutcome> answer(
    String sessionId,
    int position,
    int? selectedPosition, {
    String? typedAnswer,
    Map<String, dynamic>? response,
    int? timeSpentMs,
    bool? marked,
    bool visit = false,
  }) async {
    final s = _get(sessionId);
    timesSpent[position] = timeSpentMs;
    if (marked != null) marks[position] = marked;
    if (visit) {
      visits.add(position);
      return const AnswerOutcome.confirmed(null, applied: true);
    }
    if (offline) return const AnswerOutcome.queued();
    _expire(s);
    if (s.submitted) throw const ServerFailure(statusCode: 409, code: 'session_closed');
    if (s.sections.isNotEmpty &&
        !(s.currentSection < s.sections.length &&
            s.sections[s.currentSection].contains(position))) {
      throw const ServerFailure(statusCode: 409, code: 'section_closed');
    }
    final answered = s.answers[position] != null || s.typed.containsKey(position);
    final locked = s.mode == SessionMode.practice && answered;
    if (!locked) {
      if (typedAnswer != null) {
        s.typed[position] = typedAnswer;
      } else {
        s.answers[position] = selectedPosition;
      }
    }
    final question = s.questions[position - 1];
    return AnswerOutcome.confirmed(
      s.mode == SessionMode.practice ? _feedback(s, position, question) : null,
      applied: !locked,
      selectedPosition: s.answers[position],
      typedAnswer: s.typed[position],
    );
  }

  /// Review marks and visits, as a computer-based mock sends them.
  final marks = <int, bool>{};
  final visits = <int>[];
  final cbtSessions = <String>{};

  void useCbt(String id) => cbtSessions.add(id);

  @override
  Future<MockAnalysis> analysis(String sessionId) async => const MockAnalysis();

  @override
  Future<int> flush({String? sessionId}) async => 0;

  @override
  Future<int> pendingCount(String sessionId) async => 0;

  @override
  Future<void> setBookmark(String questionId, {required bool bookmarked}) async {
    for (final s in sessions.values) {
      bookmarked ? s.bookmarked.add(questionId) : s.bookmarked.remove(questionId);
    }
  }

  @override
  Future<List<BankQuestion>> bookmarks() async => [
    for (final q in pool)
      if (sessions.values.any((s) => s.bookmarked.contains(q.id))) q,
  ];

  @override
  Future<List<BankQuestion>> incorrect() async => [
    for (final s in sessions.values)
      for (final (i, q) in s.questions.indexed)
        if (s.answers[i + 1] != null && s.answers[i + 1] != q.correctPosition) q,
  ];

  void _expire(_FakeSession s) {
    // Sections close in order as their time runs out (same rule as the server).
    while (!s.submitted && s.sections.isNotEmpty && s.currentSection < s.sections.length) {
      final ends = s.sectionStartedAt!.add(Duration(minutes: s.sections[s.currentSection].minutes));
      if (serverNow().isBefore(ends)) break;
      s
        ..currentSection += 1
        ..sectionStartedAt = ends;
      if (s.currentSection >= s.sections.length) {
        s
          ..submitted = true
          ..submitReason = 'time_up';
      }
    }
    if (!s.submitted && s.deadline != null && !serverNow().isBefore(s.deadline!)) {
      s
        ..submitted = true
        ..submitReason = 'time_up';
    }
  }

  /// Same rule as the server: numbers by value, otherwise ignoring spaces and case.
  static bool typedMatches(String expected, String given) {
    final a = double.tryParse(expected.trim());
    final b = double.tryParse(given.trim());
    if (a != null && b != null) return a == b;
    String norm(String v) => v.replaceAll(' ', '').toLowerCase();
    return norm(expected) == norm(given);
  }

  bool? _outcome(_FakeSession s, int position, BankQuestion q) {
    if (q.isTyped) {
      final given = s.typed[position];
      return given == null ? null : typedMatches(q.typedAnswer!, given);
    }
    final selected = s.answers[position];
    return selected == null ? null : selected == q.correctPosition;
  }

  int _correct(_FakeSession s) => [
    for (final (i, q) in s.questions.indexed)
      if (_outcome(s, i + 1, q) == true) 1,
  ].length;

  AnswerFeedback? _feedback(_FakeSession s, int position, BankQuestion q) {
    final outcome = _outcome(s, position, q);
    final answered = s.answers[position] != null || s.typed.containsKey(position);
    final reveal = s.submitted || (s.mode == SessionMode.practice && answered);
    if (!reveal) return null;
    return AnswerFeedback(
      correctPosition: q.isTyped ? null : q.correctPosition,
      correctTypedAnswer: q.isTyped ? q.typedAnswer : null,
      isCorrect: outcome,
      explanation: q.explanation ?? 'Explanation ${q.sourceNumber}.',
      explanationByAi: q.origin == QuestionOrigin.ai,
    );
  }

  PracticeSessionView _view(_FakeSession s) {
    final correct = _correct(s);
    final attempted = s.answers.values.where((a) => a != null).length + s.typed.length;
    final wrong = attempted - correct;
    final unattempted = s.questions.length - attempted;
    return PracticeSessionView(
      id: s.id,
      mode: s.mode,
      submitted: s.submitted,
      formatName: s.formatName,
      startedAt: s.startedAt,
      deadlineAt: s.deadline,
      serverNow: serverNow(),
      submitReason: s.submitReason,
      perQuestionSeconds: s.perQuestionSeconds,
      cbt: cbtSessions.contains(s.id) ? const CbtRules(reference: 'Bulletin, p.1') : null,
      items: [
        for (final (i, q) in s.questions.indexed)
          SessionItemView(
            position: i + 1,
            questionId: q.id,
            section: q.section,
            marked: marks[i + 1] ?? false,
            visited: visits.contains(i + 1),
            stem: q.stem,
            options: q.isTyped ? const [] : q.options,
            figures: q.figures,
            answerType: q.answerType,
            typedAnswer: s.typed[i + 1],
            typedAnswerNumeric: q.isTyped && double.tryParse(q.typedAnswer ?? '') != null,
            passage: q.passage,
            origin: q.origin,
            verified: q.status == VerificationStatus.verified,
            sourceFilename: q.documentFilename,
            sourcePage: q.sourcePages.firstOrNull,
            sourceNumber: q.sourceNumber,
            bookmarked: s.bookmarked.contains(q.id),
            shared: q.readOnly,
            sharedSource: q.sharedSource,
            selectedPosition: s.answers[i + 1],
            feedback: _feedback(s, i + 1, q),
          ),
      ],
      sections: s.sections,
      currentSection: s.sections.isEmpty ? null : s.currentSection,
      sectionDeadlineAt: s.sections.isEmpty || s.submitted
          ? null
          : s.sectionStartedAt!.add(Duration(minutes: s.sections[s.currentSection].minutes)),
      result: s.submitted
          ? SessionResultView(
              total: TallyView(
                name: '',
                correct: correct,
                wrong: wrong,
                unattempted: unattempted,
                score: correct.toDouble(),
                maxScore: s.questions.length.toDouble(),
                accuracy: attempted == 0 ? null : correct / attempted,
                explanation:
                    'Correct $correct × 1.00 = $correct.00; Total $correct.00 of ${s.questions.length}.00',
              ),
              timeTakenSeconds: serverNow().difference(s.startedAt).inSeconds,
              markingNote: switch (s.mode) {
                SessionMode.practice =>
                  'Practice: 1 point per correct answer, no negative marking.',
                SessionMode.diagnostic => 'Starter check: 1 point per correct answer.',
                SessionMode.mock => 'SSC CHSL 2026 Tier-I. Wrong answer: -0.50.',
              },
              sections: const [],
              topics: const [],
            )
          : null,
    );
  }
}
