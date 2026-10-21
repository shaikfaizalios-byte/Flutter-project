import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/features/feedback/data/feedback_repository.dart';

/// Records suggestions in memory; [failure] makes sending fail.
class FakeFeedbackRepository implements FeedbackRepository {
  final sent = <Suggestion>[];
  AppFailure? failure;

  @override
  Future<Suggestion> suggest(SuggestionKind kind, String text) async {
    if (failure != null) throw failure!;
    final suggestion = Suggestion(
      id: 's${sent.length + 1}',
      kind: kind,
      text: text.trim(),
      status: 'new',
      createdAt: DateTime.utc(2026, 10, 21),
    );
    sent.insert(0, suggestion);
    return suggestion;
  }

  @override
  Future<List<Suggestion>> mine() async => List.of(sent);
}
