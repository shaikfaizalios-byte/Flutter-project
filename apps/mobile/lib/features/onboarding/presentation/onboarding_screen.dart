import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/clock.dart';
import '../../settings/application/app_preferences.dart';
import '../../study_plan/application/study_profile_controller.dart';
import '../../exams/presentation/exam_selector.dart';
import '../../study_plan/presentation/study_profile_widgets.dart';

/// First-run setup. Every step is optional; answers are saved as they are made,
/// so leaving halfway keeps what was chosen. Finishing (or skipping) marks
/// onboarding complete and the router moves on to Home.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 5;
  int _step = 0;

  Future<void> _finish() => ref.read(studyProfileProvider.notifier).completeOnboarding();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLast = _step == _stepCount - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingStep(_step + 1, _stepCount)),
        actions: [TextButton(onPressed: _finish, child: Text(l10n.onboardingSkipSetup))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / _stepCount),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                switch (_step) {
                  0 => const _WelcomeStep(),
                  1 => const _ExamStep(),
                  2 => const _DateStep(),
                  3 => const _DailyStep(),
                  _ => const _ReminderStep(),
                },
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (_step > 0)
                TextButton(onPressed: () => setState(() => _step--), child: Text(l10n.back)),
              const Spacer(),
              FilledButton(
                onPressed: isLast ? _finish : () => setState(() => _step++),
                child: Text(isLast ? l10n.onboardingFinish : l10n.next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall)),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              hint!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WelcomeStep extends ConsumerWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(appPreferencesProvider.select((p) => p.language));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(title: l10n.onboardingWelcomeTitle, hint: l10n.onboardingWelcomeBody),
        Text(l10n.settingsLanguage, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<AppLanguage>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: AppLanguage.system, label: Text(l10n.languageSystem)),
            ButtonSegment(value: AppLanguage.english, label: Text(l10n.languageEnglish)),
            ButtonSegment(value: AppLanguage.hindi, label: Text(l10n.languageHindi)),
          ],
          selected: {language},
          onSelectionChanged: (s) => ref.read(appPreferencesProvider.notifier).setLanguage(s.first),
        ),
      ],
    );
  }
}

class _ExamStep extends ConsumerWidget {
  const _ExamStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final codes = ref.watch(studyProfileProvider.select((p) => p.examCodes));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(title: l10n.onboardingExamTitle, hint: l10n.onboardingExamHint),
        ExamSelector(
          selected: codes,
          onChanged: ref.read(studyProfileProvider.notifier).setExamCodes,
        ),
      ],
    );
  }
}

class _DateStep extends ConsumerWidget {
  const _DateStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final date = ref.watch(studyProfileProvider.select((p) => p.targetExamDate));
    final controller = ref.read(studyProfileProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(title: l10n.onboardingDateTitle, hint: l10n.onboardingDateHint),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(date == null ? l10n.chooseDate : formatCalendarDate(context, date)),
              onPressed: () async {
                final today = CalendarDate.fromDateTime(ref.read(clockProvider)());
                final picked = await pickExamDate(context, today: today, initial: date);
                if (picked != null) await controller.setTargetExamDate(picked);
              },
            ),
            if (date != null)
              TextButton(
                onPressed: () => controller.setTargetExamDate(null),
                child: Text(l10n.clear),
              ),
          ],
        ),
      ],
    );
  }
}

class _DailyStep extends ConsumerWidget {
  const _DailyStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final minutes = ref.watch(studyProfileProvider.select((p) => p.dailyStudyMinutes));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(title: l10n.onboardingDailyTitle, hint: l10n.onboardingDailyHint),
        DailyMinutesSelector(
          selected: minutes,
          onChanged: ref.read(studyProfileProvider.notifier).setDailyStudyMinutes,
        ),
      ],
    );
  }
}

class _ReminderStep extends ConsumerWidget {
  const _ReminderStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final minutes = ref.watch(studyProfileProvider.select((p) => p.reminderMinutes));
    final controller = ref.read(studyProfileProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(title: l10n.onboardingReminderTitle, hint: l10n.onboardingReminderHint),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(minutes == null ? l10n.chooseTime : formatReminderTime(context, minutes)),
              onPressed: () async {
                final picked = await pickReminderTime(context, initialMinutes: minutes);
                if (picked != null) await controller.setReminderMinutes(picked);
              },
            ),
            if (minutes != null)
              TextButton(
                onPressed: () => controller.setReminderMinutes(null),
                child: Text(l10n.clear),
              ),
          ],
        ),
      ],
    );
  }
}
