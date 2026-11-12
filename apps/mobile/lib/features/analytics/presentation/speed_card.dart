import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';
import '../../exams/application/active_exam.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/domain/practice_models.dart';
import '../../practice/presentation/practice_hub_screen.dart' show startAndOpen;
import '../application/analytics_providers.dart';
import '../domain/speed.dart';
import 'analytics_widgets.dart';

/// Accuracy and time per question type against the target (the verified format's, else the
/// learner's own), with a timed drill for each type. Shown only with data or to set a target.
class SpeedCard extends ConsumerWidget {
  const SpeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(speedReportProvider).value;
    if (report == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag());
    final target = report.target;
    String secs(double s) => number.format(s.round());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SectionCard(
        icon: Icons.speed,
        title: l10n.speedTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (target != null && target.fromFormat)
              Text(
                l10n.speedTargetFormat(
                  secs(target.seconds ?? target.bySection.values.first),
                  target.formatName ?? '',
                ),
              )
            else ...[
              Text(
                target == null
                    ? l10n.speedNoTarget
                    : l10n.speedTargetOwn(secs(target.seconds ?? 0)),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => _setOwnTarget(context, ref, target?.seconds),
                  child: Text(target == null ? l10n.speedSetOwn : l10n.speedChangeOwn),
                ),
              ),
            ],
            if (report.types.isEmpty) Text(l10n.speedEmpty, style: theme.textTheme.bodySmall),
            for (final type in report.types)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(type.name),
                subtitle: Text(
                  [
                    l10n.speedTypeLine(formatPercent(context, type.accuracy ?? 0), type.answered),
                    if (type.secondsPerAnswer case final s?) l10n.speedSeconds(secs(s)),
                    if (type.slowCorrect > 0) l10n.speedSlow(type.slowCorrect),
                  ].join(' · '),
                ),
                trailing: switch (report.drillSeconds(type)) {
                  final seconds? => TextButton.icon(
                    icon: const Icon(Icons.timer_outlined),
                    label: Text(l10n.speedDrill),
                    onPressed: () => startAndOpen(
                      context,
                      () => ref
                          .read(practiceRepositoryProvider)
                          .startPractice(
                            PracticeRequest(
                              examCode: ref.read(activeExamProvider),
                              patternId: type.patternId,
                              count: drillQuestions,
                              perQuestionSeconds: seconds,
                            ),
                          ),
                    ),
                  ),
                  null => null,
                },
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.speedRules(number.format(report.slowFactor)),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setOwnTarget(BuildContext context, WidgetRef ref, double? current) async {
    final exam = ref.read(activeExamProvider);
    if (exam == null) return;
    final db = ref.read(appDatabaseProvider);
    final seconds = await showDialog<int>(
      context: context,
      builder: (dialog) => _OwnTargetDialog(current: current?.round()),
    );
    if (seconds == null) return;
    await saveOwnSpeedTarget(db, exam, seconds);
    ref.invalidate(ownSpeedTargetProvider);
  }
}

class _OwnTargetDialog extends StatefulWidget {
  const _OwnTargetDialog({this.current});

  final int? current;

  @override
  State<_OwnTargetDialog> createState() => _OwnTargetDialogState();
}

class _OwnTargetDialogState extends State<_OwnTargetDialog> {
  late final _field = TextEditingController(text: widget.current?.toString() ?? '');
  bool _invalid = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_field.text.trim());
    if (value == null || value < 5 || value > 600) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.speedSetOwn),
      content: TextField(
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l10n.speedOwnField,
          errorText: _invalid ? l10n.speedOwnInvalid : null,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
