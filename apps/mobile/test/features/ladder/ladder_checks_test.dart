import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/localization/generated/app_localizations_en.dart';
import 'package:preploop/features/ladder/domain/ladder_models.dart';
import 'package:preploop/features/ladder/presentation/ladder_screen.dart';

Map<String, dynamic> stepJson(Map<String, dynamic> changes) => {
  'round_number': 1,
  'step': 4,
  'difficulty': 'hard',
  'ready': true,
  'basis_papers': 0,
  'basis_web': false,
  'format': 'single_correct',
  ...changes,
};

void main() {
  final l10n = AppLocalizationsEn();

  test('a library question says where it came from', () {
    final step = LadderStep.fromJson(stepJson({'source': 'library'}));
    expect(step.fromLibrary, isTrue);
    expect(ladderBasis(l10n, step), "From PrepLoop's question library");
    expect(ladderChecks(l10n, step), isNull);
  });

  test('a checked question says how', () {
    final step = LadderStep.fromJson(
      stepJson({
        'source': 'ai',
        'checks': {'solves': 3, 'recalculated': true},
      }),
    );
    expect(ladderChecks(l10n, step), contains('3 independent solves'));
    expect(ladderChecks(l10n, step), contains('recalculated'));
  });
}
