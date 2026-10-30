import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_transitions.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../application/active_exam.dart';
import '../application/exam_catalog_controller.dart';

/// Shows the current exam and switches it. Every paper, question and practice screen shows
/// only the current exam's content. [expanded] = full width (desktop sidebar).
class ExamSwitcher extends ConsumerWidget {
  const ExamSwitcher({super.key, this.expanded = false, this.sheetContext});

  final bool expanded;

  /// Where to open the exam list from when this switcher sits outside the app's pages (the
  /// desktop sidebar): a context under the router's navigator.
  final BuildContext? Function()? sheetContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(activeExamProvider);
    final label = active == null ? l10n.examSwitcherChoose : ref.watch(examNameProvider(active));
    final button = expanded
        ? OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            icon: const Icon(Icons.flag_outlined),
            label: Row(
              children: [
                Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.unfold_more, size: 18),
              ],
            ),
            onPressed: () => showExamSwitcher(sheetContext?.call() ?? context),
          )
        : TextButton.icon(
            icon: const Icon(Icons.flag_outlined),
            label: Text(label, overflow: TextOverflow.ellipsis),
            onPressed: () => showExamSwitcher(context),
          );
    return Semantics(
      label: active == null ? null : l10n.examSwitcherCurrent(label),
      // The labelled sidebar button needs no tooltip (and has no overlay to show one in).
      child: expanded ? button : Tooltip(message: l10n.examSwitcherTooltip, child: button),
    );
  }
}

/// The learner's exams to switch between, plus a way to add or change exams.
Future<void> showExamSwitcher(BuildContext context) =>
    showModalBottomSheet<void>(context: context, builder: (context) => const _ExamSwitcherSheet());

class _ExamSwitcherSheet extends ConsumerWidget {
  const _ExamSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final exams = ref.watch(studyProfileProvider.select((p) => p.examCodes));
    final active = ref.watch(activeExamProvider);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Text(l10n.examSwitcherTitle, style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Text(l10n.examSwitcherHint, style: Theme.of(context).textTheme.bodySmall),
          ),
          for (final code in exams)
            ListTile(
              leading: Icon(code == active ? Icons.radio_button_checked : Icons.radio_button_off),
              title: Text(ref.watch(examNameProvider(code))),
              selected: code == active,
              onTap: () async {
                final choice = ref.read(activeExamChoiceProvider.notifier);
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                if (code == active) return;
                // Another exam starts over on Home: screens opened for the old exam (a paper, a
                // question, a session) must not stay on screen under the new one. The exam
                // changes once Home is fully back in view: screens paused while covered must
                // not wake up to a changed exam in the middle of a build (Riverpod refuses).
                router.go(AppRoutes.home);
                await untilAnimationsSettle();
                await choice.choose(code);
              },
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(l10n.examSwitcherManage),
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.myExams);
            },
          ),
        ],
      ),
    );
  }
}
