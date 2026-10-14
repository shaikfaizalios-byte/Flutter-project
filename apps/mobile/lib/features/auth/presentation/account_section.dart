import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/section_card.dart';
import '../../sync/application/sync_controller.dart';
import '../application/auth_controller.dart';
import 'sign_in_screen.dart';

/// Profile: the account, sync status and privacy actions.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider.select((a) => a.session?.user));
    final sync = ref.watch(syncControllerProvider);
    if (user == null) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context).toLanguageTag();
    final status = switch (sync) {
      SyncStatus(syncing: true) => l10n.syncInProgress,
      SyncStatus(error: NetworkFailure() || TimeoutFailure()) => l10n.syncOffline(sync.pending),
      SyncStatus(error: _?) => l10n.syncFailed,
      SyncStatus(pending: > 0) => l10n.syncPending(sync.pending),
      SyncStatus(lastSyncedAt: final at?) => l10n.syncDone(
        DateFormat.yMMMd(locale).add_jm().format(at.toLocal()),
      ),
      _ => l10n.syncNever,
    };

    return SectionCard(
      icon: Icons.account_circle_outlined,
      title: l10n.accountTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.displayName != null) Text(user.displayName!, style: theme.textTheme.titleMedium),
          Text(user.email),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                sync.error == null ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(status)),
              TextButton(
                onPressed: sync.syncing
                    ? null
                    : () => ref.read(syncControllerProvider.notifier).syncNow(),
                child: Text(l10n.syncNow),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.accountExport),
                onPressed: () => _export(context, ref),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(l10n.accountSignOut),
                onPressed: () => _signOut(context, ref),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.accountDelete),
                onPressed: () => _delete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await ref.read(authControllerProvider.notifier).exportData();
      await Clipboard.setData(ClipboardData(text: json));
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountExported)));
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Export failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(authErrorMessage(l10n, error))));
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    await ref.read(syncControllerProvider.notifier).syncNow();
    final pending = await ref.read(syncEngineProvider).pendingCount();
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountSignOutTitle),
        content: Text(
          pending > 0 ? l10n.accountSignOutUnsynced(pending) : l10n.accountSignOutMessage,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.accountSignOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (password == null || password.isEmpty) return;
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(password);
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Account deletion failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(authErrorMessage(l10n, error))));
    }
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.accountDeleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.accountDeleteMessage),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.authPassword),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.of(context).pop(_password.text),
          child: Text(l10n.accountDeleteConfirm),
        ),
      ],
    );
  }
}
