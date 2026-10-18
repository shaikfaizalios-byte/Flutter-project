import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/exams/exam_catalog.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../../study_plan/application/study_profile_controller.dart';
import '../application/exam_catalog_controller.dart';
import 'exam_selector.dart';

/// The learner's exams (chosen in the study plan, plus their own) and a way into each exam's
/// subjects and topics.
class MyExamsScreen extends ConsumerStatefulWidget {
  const MyExamsScreen({super.key});

  @override
  ConsumerState<MyExamsScreen> createState() => _MyExamsScreenState();
}

class _MyExamsScreenState extends ConsumerState<MyExamsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(examCatalogProvider.notifier).refresh());
  }

  Future<void> _guard(Future<void> Function() action, {String? done}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ServerFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failure.code == 'exam_in_use' ? l10n.examsInUse : uploadErrorMessage(l10n, failure),
          ),
        ),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Exam action failed', error, stack);
    }
  }

  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const ExamNameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    await _guard(() async {
      final exam = await ref.read(examCatalogProvider.notifier).create(name.trim());
      final profile = ref.read(studyProfileProvider);
      await ref.read(studyProfileProvider.notifier).setExamCodes([...profile.examCodes, exam.code]);
    });
  }

  Future<void> _rename(ExamOption exam) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => ExamNameDialog(initial: exam.name),
    );
    if (name == null || name.trim().isEmpty || name.trim() == exam.name) return;
    await _guard(() => ref.read(examCatalogProvider.notifier).rename(exam.code, name.trim()));
  }

  Future<void> _delete(ExamOption exam) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.examsDeleteTitle(exam.shortName)),
        content: Text(l10n.examsDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(() async {
      await ref.read(examCatalogProvider.notifier).delete(exam.code);
      final profile = ref.read(studyProfileProvider);
      await ref.read(studyProfileProvider.notifier).setExamCodes([
        for (final c in profile.examCodes)
          if (c != exam.code) c,
      ]);
    }, done: l10n.examsDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(examCatalogProvider);
    final chosen = ref.watch(studyProfileProvider.select((p) => p.examCodes));
    final exams = [
      for (final e in catalog)
        if (chosen.contains(e.code) || e.custom) e,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.examsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.examsCreateOwn),
        onPressed: _create,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: exams.isEmpty
              ? EmptyState(
                  icon: Icons.school_outlined,
                  title: l10n.examsEmptyTitle,
                  message: l10n.examsEmptyMessage,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(l10n.examsIntro),
                    ),
                    for (final exam in exams)
                      ListTile(
                        leading: Icon(exam.custom ? Icons.edit_note : Icons.school_outlined),
                        title: Text(exam.shortName),
                        subtitle: Text(
                          exam.custom ? l10n.examsOwnLabel : (exam.category ?? exam.name),
                        ),
                        onTap: () => context.push(AppRoutes.examTopics(exam.code)),
                        trailing: exam.custom
                            ? PopupMenuButton<String>(
                                tooltip: l10n.examsActions,
                                onSelected: (v) => v == 'rename' ? _rename(exam) : _delete(exam),
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'rename', child: Text(l10n.examsRename)),
                                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                                ],
                              )
                            : const Icon(Icons.chevron_right),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
