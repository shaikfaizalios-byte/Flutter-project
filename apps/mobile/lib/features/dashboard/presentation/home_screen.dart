import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';

/// Dashboard. Answers the three core questions; each section shows an honest
/// empty state until real study data exists (no sample statistics).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Semantics(
                header: true,
                child: Text(l10n.homeHeadline, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: AppSpacing.md),
              _DashboardSection(
                icon: Icons.today_outlined,
                title: l10n.homeTodayTitle,
                message: l10n.homeTodayEmpty,
              ),
              const SizedBox(height: AppSpacing.md),
              _DashboardSection(
                icon: Icons.insights_outlined,
                title: l10n.homeWeakTitle,
                message: l10n.homeWeakEmpty,
              ),
              const SizedBox(height: AppSpacing.md),
              _DashboardSection(
                icon: Icons.event_outlined,
                title: l10n.homeUpcomingTitle,
                message: l10n.homeUpcomingEmpty,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      icon: icon,
      title: title,
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
