import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../application/auth_controller.dart';
import 'sign_in_screen.dart';

/// Two steps: email → (emailed 6-digit code + new password).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Password reset failed', error, stack);
      if (mounted) setState(() => _error = authErrorMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    await ref.read(authControllerProvider.notifier).requestPasswordReset(_email.text);
    if (mounted) setState(() => _codeSent = true);
  });

  Future<void> _reset() => _run(() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await ref
        .read(authControllerProvider.notifier)
        .resetPassword(_email.text, _code.text, _password.text);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.resetDone)));
    context.go(AppRoutes.signIn);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_codeSent ? l10n.resetCodeSent : l10n.resetIntro),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _email,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: l10n.authEmail),
                    validator: (v) => (v ?? '').contains('@') ? null : l10n.authEmailInvalid,
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: 6,
                      decoration: InputDecoration(labelText: l10n.resetCode),
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : l10n.resetCodeInvalid,
                    ),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: l10n.resetNewPassword,
                        helperText: l10n.authPasswordHint(passwordMinLength),
                      ),
                      validator: (v) => (v ?? '').length < passwordMinLength
                          ? l10n.authPasswordHint(passwordMinLength)
                          : null,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
                    child: Text(_codeSent ? l10n.resetSave : l10n.resetSend),
                  ),
                  if (_codeSent)
                    TextButton(onPressed: _busy ? null : _sendCode, child: Text(l10n.resetResend)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
