import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../app/routes.dart';
import '../../legal/presentation/legal_links.dart';
import '../application/auth_controller.dart';

/// Minimum password length (same rule as the server).
const passwordMinLength = 10;

/// Minimum age to create an account (same rule as the server's `MINIMUM_AGE`).
const minimumAge = 18;

String authErrorMessage(AppLocalizations l10n, Object error) => switch (error) {
  NetworkFailure() || TimeoutFailure() => l10n.authErrorOffline,
  ServerFailure(code: 'invalid_credentials') => l10n.authErrorCredentials,
  ServerFailure(code: 'email_taken') => l10n.authErrorEmailTaken,
  ServerFailure(code: 'rate_limited') => l10n.authErrorRateLimited,
  ServerFailure(code: 'validation_error') => l10n.authErrorInvalid,
  ServerFailure(code: 'invalid_code') => l10n.authErrorCode,
  _ => l10n.authErrorGeneric,
};

/// Sign in or create an account. Study data then syncs to the account.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_creating) {
        await auth.signUp(_email.text, _password.text, displayName: _name.text);
      } else {
        await auth.signIn(_email.text, _password.text);
      }
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Sign-in failed', error, stack);
      if (mounted) setState(() => _error = authErrorMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final expired = ref.watch(authControllerProvider.select((a) => a.expired));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_creating ? l10n.authCreateTitle : l10n.authSignInTitle),
                      if (expired && !_creating) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.authSessionExpired,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (_creating) ...[
                        TextFormField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          maxLength: 100,
                          decoration: InputDecoration(labelText: l10n.authName),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(labelText: l10n.authEmail),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          final at = value.indexOf('@');
                          return at < 1 || !value.substring(at + 1).contains('.')
                              ? l10n.authEmailInvalid
                              : null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        autofillHints: [
                          _creating ? AutofillHints.newPassword : AutofillHints.password,
                        ],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: l10n.authPassword,
                          helperText: _creating ? l10n.authPasswordHint(passwordMinLength) : null,
                          suffixIcon: IconButton(
                            tooltip: _hidePassword ? l10n.authShowPassword : l10n.authHidePassword,
                            icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        validator: (v) {
                          final value = v ?? '';
                          if (value.isEmpty) return l10n.authPasswordRequired;
                          if (_creating && value.length < passwordMinLength) {
                            return l10n.authPasswordHint(passwordMinLength);
                          }
                          return null;
                        },
                      ),
                      if (_creating)
                        FormField<bool>(
                          initialValue: false,
                          validator: (v) => v == true ? null : l10n.authAgeRequired(minimumAge),
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                value: field.value ?? false,
                                onChanged: _busy ? null : field.didChange,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(l10n.authAgeConfirm(minimumAge)),
                              ),
                              if (field.errorText != null)
                                Text(
                                  field.errorText!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_creating ? l10n.authCreate : l10n.authSignIn),
                      ),
                      if (!_creating)
                        TextButton(
                          onPressed: _busy ? null : () => context.push(AppRoutes.forgotPassword),
                          child: Text(l10n.authForgotPassword),
                        ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _creating = !_creating;
                                _error = null;
                              }),
                        child: Text(_creating ? l10n.authHaveAccount : l10n.authNoAccount),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.authSyncNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const LegalLinks(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
