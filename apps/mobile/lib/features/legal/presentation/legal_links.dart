import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/localization/generated/app_localizations.dart';

/// "Privacy policy · Terms of use" links (sign-in screen and Profile).
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => context.push(AppRoutes.privacy),
          child: Text(l10n.legalPrivacy),
        ),
        TextButton(onPressed: () => context.push(AppRoutes.terms), child: Text(l10n.legalTerms)),
      ],
    );
  }
}
