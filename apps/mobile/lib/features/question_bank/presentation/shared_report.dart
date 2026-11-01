import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../data/questions_repository.dart';
import '../domain/shared_report_kind.dart';

/// Reports a question of a shared paper (another account's) to the PrepLoop team.
Future<void> reportSharedContent(BuildContext context, WidgetRef ref, String questionId) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final report = await showDialog<(SharedReportKind, String)>(
    context: context,
    builder: (context) => const _SharedReportDialog(),
  );
  if (report == null) return;
  try {
    await ref.read(questionsRepositoryProvider).reportShared(questionId, report.$1, report.$2);
    messenger.showSnackBar(SnackBar(content: Text(l10n.sharedReportSent)));
  } on Object catch (error, stack) {
    if (error is! AppFailure) logError('Reporting shared content failed', error, stack);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (error) {
          ServerFailure(statusCode: 429) => l10n.sharedReportTooMany,
          _ => l10n.sharedReportFailed,
        }),
      ),
    );
  }
}

class _SharedReportDialog extends StatefulWidget {
  const _SharedReportDialog();

  @override
  State<_SharedReportDialog> createState() => _SharedReportDialogState();
}

class _SharedReportDialogState extends State<_SharedReportDialog> {
  final _text = TextEditingController();
  var _kind = SharedReportKind.error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = _text.text.trim().length >= 10;
    return AlertDialog(
      title: Text(l10n.sharedReportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sharedReportIntro),
            RadioGroup<SharedReportKind>(
              groupValue: _kind,
              onChanged: (v) => setState(() => _kind = v ?? _kind),
              child: Column(
                children: [
                  for (final kind in SharedReportKind.values)
                    RadioListTile<SharedReportKind>(
                      contentPadding: EdgeInsets.zero,
                      value: kind,
                      title: Text(switch (kind) {
                        SharedReportKind.rights => l10n.sharedReportRights,
                        SharedReportKind.error => l10n.sharedReportError,
                        SharedReportKind.other => l10n.sharedReportOther,
                      }),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _text,
              minLines: 2,
              maxLines: 6,
              maxLength: 2000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.sharedReportText,
                helperText: l10n.sharedReportTextHelp,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: ready ? () => Navigator.of(context).pop((_kind, _text.text.trim())) : null,
          child: Text(l10n.reportSend),
        ),
      ],
    );
  }
}
