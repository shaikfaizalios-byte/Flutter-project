import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/section_card.dart';
import '../../documents/presentation/documents_screen.dart' show uploadErrorMessage;
import '../data/insights_repository.dart';

/// The opt-in switch for sharing confirmed counts with the Repeat Radar, with exactly what is
/// shared. Used in Profile and on the Radar view.
class RadarSharingCard extends ConsumerStatefulWidget {
  const RadarSharingCard({super.key, this.examCode});

  /// Refreshes this exam's Radar after a change.
  final String? examCode;

  @override
  ConsumerState<RadarSharingCard> createState() => _RadarSharingCardState();
}

class _RadarSharingCardState extends ConsumerState<RadarSharingCard> {
  bool _busy = false;

  Future<void> _set(bool share) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(insightsRepositoryProvider).setRadarShare(share: share);
      ref
        ..invalidate(radarSettingsProvider)
        ..invalidate(radarProvider(widget.examCode));
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(uploadErrorMessage(l10n, failure))));
    } on Object catch (error, stack) {
      logError('Changing Radar sharing failed', error, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final settings = ref.watch(radarSettingsProvider);
    return SectionCard(
      icon: Icons.radar,
      title: l10n.radarShareTitle,
      child: switch (settings) {
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.radarShareSwitch),
              value: value.share,
              onChanged: _busy ? null : _set,
            ),
            Text(l10n.radarShareWhat, style: small),
            const SizedBox(height: 4),
            Text(l10n.radarShareEligible(value.eligiblePapers), style: small),
          ],
        ),
        AsyncError() => Text(l10n.bankLoadError),
        _ => const LinearProgressIndicator(),
      },
    );
  }
}
