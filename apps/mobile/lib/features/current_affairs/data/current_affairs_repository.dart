import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/content_language.dart';
import '../../../core/network/api_client.dart';

/// One card the AI drafted from the learner's own material. Not saved until approved.
@immutable
class CurrentAffairsCard {
  const CurrentAffairsCard({
    required this.front,
    required this.back,
    required this.sourceLabel,
    required this.quote,
  });

  factory CurrentAffairsCard.fromJson(Map<String, dynamic> json) => CurrentAffairsCard(
    front: json['front'] as String,
    back: json['back'] as String,
    sourceLabel: json['source_label'] as String,
    quote: json['quote'] as String,
  );

  final String front;
  final String back;

  /// "Pasted text", "news.pdf, page 3".
  final String sourceLabel;

  /// The material's own words the card comes from (the server checked they are there).
  final String quote;
}

@immutable
class CurrentAffairsDraft {
  const CurrentAffairsDraft({
    required this.cards,
    this.dropped = 0,
    this.leftOut = false,
    this.noText = false,
    this.model,
  });

  factory CurrentAffairsDraft.fromJson(Map<String, dynamic> json) => CurrentAffairsDraft(
    cards: [
      for (final c in json['cards'] as List<dynamic>)
        CurrentAffairsCard.fromJson(c as Map<String, dynamic>),
    ],
    dropped: json['dropped'] as int? ?? 0,
    leftOut: json['left_out'] as bool? ?? false,
    noText: json['no_text'] as bool? ?? false,
    model: json['model'] as String?,
  );

  final List<CurrentAffairsCard> cards;

  /// Drafts left out because their quote wasn't in the material.
  final int dropped;

  /// The material was too long: only its start was read.
  final bool leftOut;

  /// Nothing could be read from the file.
  final bool noText;
  final String? model;
}

/// Drafts current affairs cards on the server (AI). Throws `AppFailure`s. Nothing is stored there.
abstract interface class CurrentAffairsRepository {
  Future<CurrentAffairsDraft> fromText({
    required String examCode,
    required String text,
    required ContentLanguage language,
  });

  Future<CurrentAffairsDraft> fromPdf({
    required String examCode,
    required String name,
    required List<int> bytes,
    required ContentLanguage language,
  });
}

class RemoteCurrentAffairsRepository implements CurrentAffairsRepository {
  const RemoteCurrentAffairsRepository(this._dio);

  final Dio _dio;
  static const _base = '/api/v1/ai/current-affairs';

  /// Reading a PDF and drafting cards can take a while.
  static final _options = Options(receiveTimeout: const Duration(minutes: 3));

  @override
  Future<CurrentAffairsDraft> fromText({
    required String examCode,
    required String text,
    required ContentLanguage language,
  }) => _guard(() async {
    final reply = await _dio.post<Map<String, dynamic>>(
      '$_base/text',
      data: {'exam_code': examCode, 'text': text, 'language': language.code},
      options: _options,
    );
    return CurrentAffairsDraft.fromJson(reply.data!);
  });

  @override
  Future<CurrentAffairsDraft> fromPdf({
    required String examCode,
    required String name,
    required List<int> bytes,
    required ContentLanguage language,
  }) => _guard(() async {
    final reply = await _dio.post<Map<String, dynamic>>(
      '$_base/pdf',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: name),
        'exam_code': examCode,
        'language': language.code,
      }),
      options: _options,
    );
    return CurrentAffairsDraft.fromJson(reply.data!);
  });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final currentAffairsRepositoryProvider = Provider<CurrentAffairsRepository>(
  (ref) => RemoteCurrentAffairsRepository(ref.watch(dioProvider)),
);

/// A PDF chosen from the device.
typedef PickedPdf = ({String name, List<int> bytes});

/// Opens the file picker for one PDF; null if the learner cancels. Overridden in tests.
final currentAffairsPdfPickerProvider = Provider<Future<PickedPdf?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  },
);
