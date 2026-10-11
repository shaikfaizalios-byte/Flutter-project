import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.studyTitle)),
      body: EmptyState(
        icon: Icons.menu_book_outlined,
        title: l10n.studyEmptyTitle,
        message: l10n.studyEmptyMessage,
      ),
    );
  }
}
