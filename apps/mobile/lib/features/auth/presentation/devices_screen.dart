import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/auth_controller.dart';
import '../data/auth_api.dart';
import 'sign_in_screen.dart';

/// The account's signed-in devices (server sessions), this one first.
final signedInDevicesProvider = FutureProvider.autoDispose<List<SignedInDevice>>(
  (ref) => ref.read(authControllerProvider.notifier).devices(),
);

/// Signed-in devices: see where the account is signed in and sign any device out.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final devices = ref.watch(signedInDevicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => EmptyState(
          icon: Icons.devices_other_outlined,
          title: l10n.devicesLoadFailed,
          message: authErrorMessage(l10n, error),
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(signedInDevicesProvider),
            child: Text(l10n.retry),
          ),
        ),
        data: (devices) => _DeviceList(devices: devices),
      ),
    );
  }
}

class _DeviceList extends ConsumerWidget {
  const _DeviceList({required this.devices});

  final List<SignedInDevice> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final others = devices.where((d) => !d.current).length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              l10n.devicesIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final device in devices) _DeviceTile(device: device),
            if (others > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.devicesSignOutOthers),
                  onPressed: () => _signOutOthers(context, ref, others),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _signOutOthers(BuildContext context, WidgetRef ref, int count) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.devicesSignOutOthersTitle),
        content: Text(l10n.devicesSignOutOthersMessage(count)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.devicesSignOutOthers),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final signedOut = await ref.read(authControllerProvider.notifier).signOutOtherDevices();
      messenger.showSnackBar(SnackBar(content: Text(l10n.devicesSignedOut(signedOut))));
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Signing out other devices failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(authErrorMessage(l10n, error))));
    }
    ref.invalidate(signedInDevicesProvider);
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});

  final SignedInDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(DateTime at) => DateFormat.yMMMd(locale).add_jm().format(at.toLocal());
    final (icon, name) = switch (device.platform) {
      'android' => (Icons.phone_android, l10n.devicePlatformAndroid),
      'ios' => (Icons.phone_iphone, l10n.devicePlatformIos),
      'web' => (Icons.language, l10n.devicePlatformWeb),
      'windows' => (Icons.desktop_windows_outlined, l10n.devicePlatformWindows),
      'macos' => (Icons.laptop_mac, l10n.devicePlatformMacos),
      'linux' => (Icons.computer, l10n.devicePlatformLinux),
      _ => (Icons.devices_other_outlined, l10n.devicePlatformUnknown),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(name),
      subtitle: Text(
        [
          if (device.current)
            l10n.devicesThisDevice
          else
            l10n.devicesLastActive(date(device.lastActiveAt)),
          l10n.devicesSignedInAt(date(device.signedInAt)),
        ].join('\n'),
      ),
      isThreeLine: true,
      trailing: device.current
          ? null
          : TextButton(
              onPressed: () => _signOut(context, ref, name),
              child: Text(l10n.devicesSignOut),
            ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref, String name) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.devicesSignOutTitle(name)),
        content: Text(l10n.devicesSignOutMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.devicesSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authControllerProvider.notifier).signOutDevice(device.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.devicesSignedOut(1))));
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Signing a device out failed', error, stack);
      messenger.showSnackBar(SnackBar(content: Text(authErrorMessage(l10n, error))));
    }
    ref.invalidate(signedInDevicesProvider);
  }
}
