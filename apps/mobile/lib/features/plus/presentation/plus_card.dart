import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/section_card.dart';
import '../data/plus_repository.dart';

/// Profile: the account's Plus status in one line and the way to the Plus screen.
class PlusCard extends ConsumerWidget {
  const PlusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final status = ref.watch(plusStatusProvider).value;
    final line = switch (status) {
      PlusStatus(active: true, :final activeUntil?) => l10n.plusActiveUntil(
        DateFormat.yMMMd(locale).format(activeUntil.toLocal()),
      ),
      PlusStatus() => l10n.plusCardMessage,
      null => l10n.plusCardMessage,
    };
    return SectionCard(
      icon: Icons.workspace_premium_outlined,
      title: l10n.plusTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.plusOpen),
            onPressed: () => context.push(AppRoutes.plus),
          ),
        ],
      ),
    );
  }
}
