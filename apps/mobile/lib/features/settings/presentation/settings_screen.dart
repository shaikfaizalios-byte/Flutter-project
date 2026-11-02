import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_features.dart';

import 'package:go_router/go_router.dart';

import '../../auth/presentation/account_section.dart';
import '../../insights/presentation/radar_sharing_card.dart';
import '../../plus/presentation/plus_card.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';
import '../../study_plan/presentation/study_plan_section.dart';
import '../application/app_preferences.dart';
import '../data/server_status_repository.dart';
import '../../../app/routes.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(appPreferencesProvider);
    final controller = ref.read(appPreferencesProvider.notifier);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const AccountSection(),
              const SizedBox(height: AppSpacing.md),
              const PlusCard(),
              const SizedBox(height: AppSpacing.md),
              const StudyPlanSection(),
              const SizedBox(height: AppSpacing.md),
              if (ref.watch(appFeaturesProvider).repeatRadar) ...[
                const RadarSharingCard(),
                const SizedBox(height: AppSpacing.md),
              ],
              SectionCard(
                icon: Icons.translate,
                title: l10n.settingsLanguage,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.settingsAppLanguage, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    SegmentedButton<AppLanguage>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: AppLanguage.system, label: Text(l10n.languageSystem)),
                        ButtonSegment(
                          value: AppLanguage.english,
                          label: Text(l10n.languageEnglish),
                        ),
                        ButtonSegment(value: AppLanguage.hindi, label: Text(l10n.languageHindi)),
                      ],
                      selected: {prefs.language},
                      onSelectionChanged: (selection) => controller.setLanguage(selection.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ContentLanguageChoice(
                      label: l10n.settingsContentLanguage,
                      hint: l10n.settingsContentLanguageHint,
                      value: prefs.contentLanguage,
                      onChanged: controller.setContentLanguage,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ContentLanguageChoice(
                      label: l10n.settingsAiLanguage,
                      hint: l10n.settingsAiLanguageHint,
                      value: prefs.aiLanguage,
                      onChanged: controller.setAiLanguage,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                icon: Icons.contrast,
                title: l10n.settingsTheme,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: ThemeMode.system, label: Text(l10n.themeSystem)),
                    ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight)),
                    ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
                  ],
                  selected: {prefs.themeMode},
                  onSelectionChanged: (selection) => controller.setThemeMode(selection.first),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                icon: Icons.lightbulb_outline,
                title: l10n.suggestionsTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.suggestionsCardMessage),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.suggestionsOpen),
                      onPressed: () => context.push(AppRoutes.suggestions),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                icon: Icons.cloud_outlined,
                title: l10n.settingsServer,
                child: const _ServerStatus(),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                icon: Icons.info_outline,
                title: l10n.settingsAbout,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.aboutBuild(config.appName, config.flavor.name)),
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () =>
                          showLicensePage(context: context, applicationName: config.appName),
                      child: Text(l10n.settingsLicences),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerStatus extends ConsumerWidget {
  const _ServerStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final health = ref.watch(serverHealthProvider);

    return switch (health) {
      AsyncData(:final value) => Row(
        children: [
          Icon(Icons.check_circle, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(l10n.serverOnline(value.version))),
        ],
      ),
      AsyncError() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off, color: colors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l10n.serverOffline)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.serverOfflineHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(serverHealthProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
      _ => Row(
        children: [
          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppSpacing.sm),
          Text(l10n.serverChecking),
        ],
      ),
    };
  }
}

/// "Same as the app" or one of the content languages (global Phase 10).
class _ContentLanguageChoice extends StatelessWidget {
  const _ContentLanguageChoice({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  static const _sameAsApp = '';

  final String label;
  final String hint;
  final ContentLanguage? value;
  final ValueChanged<ContentLanguage?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: _sameAsApp, label: Text(l10n.languageSameAsApp)),
            for (final language in ContentLanguage.known)
              ButtonSegment(value: language.code, label: Text(contentLanguageName(l10n, language))),
          ],
          selected: {value?.code ?? _sameAsApp},
          onSelectionChanged: (s) =>
              onChanged(s.first == _sameAsApp ? null : ContentLanguage.fromCode(s.first)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
