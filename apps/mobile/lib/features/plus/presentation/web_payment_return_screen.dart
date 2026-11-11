import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../ai/application/ai_providers.dart';
import '../data/plus_repository.dart';

/// How often and how long the screen asks the server about a payment that isn't settled yet.
const webPayCheckEvery = Duration(seconds: 3);
const webPayCheckFor = Duration(minutes: 2);

/// Where the browser comes back after paying on the website. The server asks the payment
/// provider about the order;
/// this screen only shows what the server says.
class WebPaymentReturnScreen extends ConsumerStatefulWidget {
  const WebPaymentReturnScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<WebPaymentReturnScreen> createState() => _WebPaymentReturnScreenState();
}

class _WebPaymentReturnScreenState extends ConsumerState<WebPaymentReturnScreen> {
  WebOrderStatus? _order;
  bool _failedToAsk = false;
  bool _gaveUp = false;
  Timer? _timer;
  int _checks = 0;

  @override
  void initState() {
    super.initState();
    if (widget.orderId.isNotEmpty) unawaited(_check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    _checks++;
    try {
      final order = await ref.read(plusRepositoryProvider).webOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _failedToAsk = false;
      });
      if (order.settled) {
        ref
          ..invalidate(plusStatusProvider)
          ..invalidate(aiStatusProvider);
        return;
      }
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Checking a website payment failed', error, stack);
      if (!mounted) return;
      setState(() => _failedToAsk = true);
    }
    if (_checks * webPayCheckEvery.inSeconds >= webPayCheckFor.inSeconds) {
      setState(() => _gaveUp = true);
      return;
    }
    _timer = Timer(webPayCheckEvery, () => unawaited(_check()));
  }

  void _askAgain() {
    setState(() {
      _gaveUp = false;
      _checks = 0;
    });
    unawaited(_check());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final order = _order;
    final waiting = !_gaveUp && (order == null || !order.settled) && widget.orderId.isNotEmpty;
    final (IconData icon, String message) = switch (order?.status) {
      _ when widget.orderId.isEmpty => (Icons.help_outline, l10n.webPayNoOrder),
      WebOrderState.success => (
        Icons.check_circle_outline,
        l10n.webPayPaid(DateFormat.yMMMd(locale).format(order!.grantedUntil!.toLocal())),
      ),
      WebOrderState.failed => (Icons.error_outline, l10n.webPayFailed),
      WebOrderState.refunded => (Icons.undo, l10n.webPayRefunded),
      WebOrderState.pending => (Icons.hourglass_top, l10n.webPayPending),
      _ when _gaveUp => (Icons.hourglass_empty, l10n.webPayNotFoundYet),
      _ => (Icons.hourglass_top, l10n.webPayChecking),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.plusTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(message, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                if (order?.testPayment ?? false) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.webPayTestPayment, style: theme.textTheme.bodySmall),
                ],
                if (_failedToAsk) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.webPayCheckFailed, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: AppSpacing.md),
                if (waiting)
                  const LinearProgressIndicator()
                else if (_gaveUp)
                  OutlinedButton(onPressed: _askAgain, child: Text(l10n.webPayCheckAgain)),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.go(AppRoutes.plus),
                  child: Text(l10n.webPayBackToPlus),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
