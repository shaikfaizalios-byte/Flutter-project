import '../../../core/utils/calendar_date.dart';
import '../../concepts/domain/concept.dart';
import '../data/current_affairs_repository.dart';

/// Every approved current affairs card carries this tag, and the month's one.
const currentAffairsTag = 'current-affairs';

/// The subject approved cards are filed under (data, like any concept's subject).
const currentAffairsSubject = 'Current affairs';

/// "2026-11": the month the card was approved, as its topic and in its month tag.
String currentAffairsMonth(CalendarDate day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}';

/// The concept an approved card becomes: AI-labelled ([aiGeneratedTag]), tagged current affairs
/// and its month, with the source part and quote it came from kept in its notes and source.
ConceptDraft currentAffairsConcept(
  CurrentAffairsCard card, {
  required String examCode,
  required ContentLanguage language,
  required CalendarDate today,
  required String sourceLine,
}) {
  final month = currentAffairsMonth(today);
  final reference = '${card.sourceLabel}: "${card.quote}"';
  return ConceptDraft(
    examCode: examCode,
    title: _cap(card.front, ConceptRules.titleMax),
    subject: currentAffairsSubject,
    topic: month,
    language: language,
    notes: '${card.back}\n\n$sourceLine',
    tags: [currentAffairsTag, '$currentAffairsTag-$month', aiGeneratedTag],
    sourceReference: _cap(reference, ConceptRules.sourceReferenceMax),
  );
}

String _cap(String text, int max) => text.length <= max ? text : '${text.substring(0, max - 1)}…';
