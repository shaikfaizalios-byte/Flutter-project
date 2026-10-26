import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';

/// Shown in place of an AI action when the account needs PrepLoop Plus: what it would do and a
/// way to see Plus. Calm, no pressure; studying without AI stays free.
class PlusPrompt extends StatelessWidget {
  const PlusPrompt({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.workspace_premium_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        const SizedBox(width: AppSpacing.sm),
        TextButton(onPressed: () => context.push(AppRoutes.plus), child: Text(l10n.plusSee)),
      ],
    );
  }
}
