import 'package:flutter/foundation.dart';

/// An exam the user can attach study material to.
@immutable
class ExamOption {
  const ExamOption({required this.code, required this.shortName});

  /// Matches the backend `exams.code` reference data.
  final String code;

  /// Proper noun; not translated.
  final String shortName;
}

/// Supported exams. Mirrors the backend's seeded `exams` table; once sync is
/// introduced this list is fetched from `GET /api/v1/exams` and cached locally,
/// so adding an exam will not require an app release.
const supportedExams = <ExamOption>[
  ExamOption(code: 'SSC_CGL', shortName: 'SSC CGL'),
  ExamOption(code: 'SSC_CHSL', shortName: 'SSC CHSL'),
];

String examShortName(String code) =>
    supportedExams.where((e) => e.code == code).firstOrNull?.shortName ?? code;
