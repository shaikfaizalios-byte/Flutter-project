import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';

/// An official page where papers for an exam can be found. Opened in the browser only;
/// PrepLoop lists it after a person opened it and saw what it offers ([checkedOn]).
@immutable
class PaperSource {
  const PaperSource({
    required this.title,
    required this.url,
    required this.publisher,
    required this.offers,
    required this.checkedOn,
  });

  factory PaperSource.fromJson(Map<String, dynamic> json) => PaperSource(
    title: json['title'] as String,
    url: Uri.parse(json['url'] as String),
    publisher: json['publisher'] as String,
    offers: json['offers'] as String,
    checkedOn: CalendarDate.tryParse(json['checked_on'] as String)!,
  );

  final String title;
  final Uri url;
  final String publisher;
  final String offers;
  final CalendarDate checkedOn;
}
