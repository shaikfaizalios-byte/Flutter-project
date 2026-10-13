import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../../question_bank/domain/question.dart';
import '../../question_bank/presentation/question_widgets.dart';
import '../application/practice_providers.dart';

enum PracticeQuestionList { bookmarks, incorrect }

/// Bookmarked questions, or questions whose latest answer was wrong.
class PracticeQuestionListScreen extends ConsumerWidget {
  const PracticeQuestionListScreen({super.key, required this.kind});

  final PracticeQuestionList kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = kind == PracticeQuestionList.bookmarks
        ? bookmarkedQuestionsProvider
        : incorrectQuestionsProvider;
    final AsyncValue<List<BankQuestion>> questions = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          kind == PracticeQuestionList.bookmarks ? l10n.bookmarksTitle : l10n.incorrectTitle,
        ),
      ),
      body: switch (questions) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: kind == PracticeQuestionList.bookmarks ? Icons.bookmark_outline : Icons.task_alt,
          title: kind == PracticeQuestionList.bookmarks ? l10n.bookmarksEmpty : l10n.incorrectEmpty,
        ),
        AsyncData(:final value) => ListView.separated(
          itemCount: value.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) => QuestionTile(question: value[index]),
        ),
        AsyncError(:final error) => EmptyState(
          icon: Icons.cloud_off,
          title: error is AppFailure ? uploadErrorMessage(l10n, error) : l10n.bankLoadError,
          action: OutlinedButton(
            onPressed: () => ref.invalidate(provider),
            child: Text(l10n.retry),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
