import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../../study_plan/presentation/study_profile_widgets.dart';
import '../application/reminder_controller.dart';

/// Profile: the daily study reminder switch with its honest current state.
class ReminderTile extends ConsumerWidget {
  const ReminderTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reminder = ref.watch(reminderControllerProvider);
    final minutes = ref.watch(studyProfileProvider.select((p) => p.reminderMinutes));
    final controller = ref.read(reminderControllerProvider.notifier);
    final state = reminder.value;
    final status = state?.status;

    final subtitle = switch (status) {
      null => null,
      ReminderStatus.unsupported => l10n.reminderUnsupported,
      ReminderStatus.off => l10n.reminderOff,
      ReminderStatus.needsTime => l10n.reminderNeedsTime,
      ReminderStatus.blocked => l10n.reminderBlocked,
      ReminderStatus.failed => l10n.reminderFailed,
      ReminderStatus.on => l10n.reminderOn(formatReminderTime(context, minutes!)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.reminderSwitch),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: status == ReminderStatus.blocked || status == ReminderStatus.failed
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
          value: state?.enabled ?? false,
          onChanged: state == null || status == ReminderStatus.unsupported
              ? null
              : (on) async {
                  if (!on) return controller.disable();
                  if (minutes == null) {
                    final picked = await pickReminderTime(context);
                    if (picked != null) {
                      await ref.read(studyProfileProvider.notifier).setReminderMinutes(picked);
                    }
                  }
                  await controller.enable();
                },
        ),
        if (status == ReminderStatus.blocked)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: Text(l10n.reminderOpenSettings),
              onPressed: controller.openSystemSettings,
            ),
          ),
        if (status == ReminderStatus.failed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(onPressed: controller.resync, child: Text(l10n.retry)),
          ),
      ],
    );
  }
}
