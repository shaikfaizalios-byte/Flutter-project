import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressTitle)),
      body: EmptyState(
        icon: Icons.show_chart,
        title: l10n.progressEmptyTitle,
        message: l10n.progressEmptyMessage,
      ),
    );
  }
}
