import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/section_card.dart';
import '../../reminders/presentation/reminder_tile.dart';
import '../application/study_profile_controller.dart';
import 'study_profile_widgets.dart';

/// Profile section for editing everything collected in onboarding.
class StudyPlanSection extends ConsumerWidget {
  const StudyPlanSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(studyProfileProvider);
    final controller = ref.read(studyProfileProvider.notifier);

    Widget clearButton(VoidCallback onPressed) =>
        IconButton(tooltip: l10n.clear, icon: const Icon(Icons.clear), onPressed: onPressed);

    return SectionCard(
      icon: Icons.flag_outlined,
      title: l10n.settingsStudyPlan,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.fieldExams),
            subtitle: Text(formatExamNames(l10n, profile.examCodes)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSheet(
              context,
              title: l10n.fieldExams,
              child: Consumer(
                builder: (context, ref, _) => ExamSelector(
                  selected: ref.watch(studyProfileProvider.select((p) => p.examCodes)),
                  onChanged: controller.setExamCodes,
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.fieldExamDate),
            subtitle: Text(
              profile.targetExamDate == null
                  ? l10n.notSet
                  : formatCalendarDate(context, profile.targetExamDate!),
            ),
            trailing: profile.targetExamDate == null
                ? const Icon(Icons.event)
                : clearButton(() => controller.setTargetExamDate(null)),
            onTap: () async {
              final today = CalendarDate.fromDateTime(ref.read(clockProvider)());
              final picked = await pickExamDate(
                context,
                today: today,
                initial: profile.targetExamDate,
              );
              if (picked != null) await controller.setTargetExamDate(picked);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.fieldDailyStudy),
            subtitle: Text(
              profile.dailyStudyMinutes == null
                  ? l10n.notSet
                  : formatStudyDuration(l10n, profile.dailyStudyMinutes!),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSheet(
              context,
              title: l10n.fieldDailyStudy,
              child: Consumer(
                builder: (context, ref, _) => DailyMinutesSelector(
                  selected: ref.watch(studyProfileProvider.select((p) => p.dailyStudyMinutes)),
                  onChanged: controller.setDailyStudyMinutes,
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.fieldReminder),
            subtitle: Text(
              profile.reminderMinutes == null
                  ? l10n.notSet
                  : formatReminderTime(context, profile.reminderMinutes!),
            ),
            trailing: profile.reminderMinutes == null
                ? const Icon(Icons.schedule)
                : clearButton(() => controller.setReminderMinutes(null)),
            onTap: () async {
              final picked = await pickReminderTime(
                context,
                initialMinutes: profile.reminderMinutes,
              );
              if (picked != null) await controller.setReminderMinutes(picked);
            },
          ),
          const ReminderTile(),
        ],
      ),
    );
  }

  static Future<void> _showSheet(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              child,
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.done),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
