import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.practiceTitle)),
      body: EmptyState(
        icon: Icons.quiz_outlined,
        title: l10n.practiceEmptyTitle,
        message: l10n.practiceEmptyMessage,
      ),
    );
  }
}
