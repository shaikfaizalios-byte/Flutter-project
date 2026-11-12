import '../../../core/localization/generated/app_localizations.dart';

/// Why a wrong answer went wrong, in the learner's own words (one tap, optional).
enum MistakeReason {
  didntKnow('didnt_know'),
  calculation('calculation'),
  misread('misread'),
  time('time'),
  guessed('guessed');

  const MistakeReason(this.code);

  final String code;

  static MistakeReason? fromCode(String? code) => values.where((r) => r.code == code).firstOrNull;

  String label(AppLocalizations l10n) => switch (this) {
    didntKnow => l10n.mistakeDidntKnow,
    calculation => l10n.mistakeCalculation,
    misread => l10n.mistakeMisread,
    time => l10n.mistakeTime,
    guessed => l10n.mistakeGuessed,
  };

  /// A fixed tip for this reason (product text, the same for everyone).
  String tip(AppLocalizations l10n) => switch (this) {
    didntKnow => l10n.mistakeTipDidntKnow,
    calculation => l10n.mistakeTipCalculation,
    misread => l10n.mistakeTipMisread,
    time => l10n.mistakeTipTime,
    guessed => l10n.mistakeTipGuessed,
  };
}

/// Reason counts from the server, keyed by reason; unknown codes are left out.
Map<MistakeReason, int> mistakeCounts(Object? json) => {
  for (final MapEntry(:key, :value) in ((json as Map<String, dynamic>?) ?? const {}).entries)
    ?MistakeReason.fromCode(key): value as int,
};

/// The most common reason (the first in the list order on a tie); null without any.
MapEntry<MistakeReason, int>? topMistakeReason(Map<MistakeReason, int> counts) {
  MapEntry<MistakeReason, int>? top;
  for (final reason in MistakeReason.values) {
    final count = counts[reason] ?? 0;
    if (count > 0 && (top == null || count > top.value)) top = MapEntry(reason, count);
  }
  return top;
}
