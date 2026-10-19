import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// An app bar action: an icon with a tooltip on phones, and the icon with its label written
/// out on tablets and desktop, where there is room and an unlabelled icon is easy to miss.
class AdaptiveAction extends StatelessWidget {
  const AdaptiveAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (FormFactor.ofWidth(MediaQuery.sizeOf(context).width) == FormFactor.phone) {
      return IconButton(tooltip: label, icon: Icon(icon), onPressed: onPressed);
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
      child: TextButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
    );
  }
}
