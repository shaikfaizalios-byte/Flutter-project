import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/utils/calendar_date.dart';

void main() {
  test('parses and formats ISO dates', () {
    final date = CalendarDate.tryParse('2027-03-09')!;

    expect((date.year, date.month, date.day), (2027, 3, 9));
    expect(date.toIsoString(), '2027-03-09');
  });

  test('rejects malformed and impossible dates', () {
    for (final value in [null, '', '2027-3-9', '2027-02-30', '2027-13-01', 'tomorrow']) {
      expect(CalendarDate.tryParse(value), isNull, reason: '$value');
    }
    expect(() => CalendarDate(2026, 2, 29), throwsArgumentError);
  });

  test('daysUntil counts whole calendar days in both directions', () {
    final a = CalendarDate(2026, 10, 12);

    expect(a.daysUntil(CalendarDate(2026, 10, 12)), 0);
    expect(a.daysUntil(CalendarDate(2026, 10, 22)), 10);
    expect(a.daysUntil(CalendarDate(2026, 10, 2)), -10);
    expect(a.daysUntil(CalendarDate(2027, 10, 12)), 365);
  });

  test('daysUntil is unaffected by daylight-saving transitions', () {
    // Spans the EU (late March) and US (early November) DST changes.
    expect(CalendarDate(2027, 3, 20).daysUntil(CalendarDate(2027, 4, 3)), 14);
    expect(CalendarDate(2026, 10, 30).daysUntil(CalendarDate(2026, 11, 13)), 14);
  });

  test('equality and ordering', () {
    expect(CalendarDate(2026, 1, 1), CalendarDate(2026, 1, 1));
    final sorted = [CalendarDate(2026, 5, 1), CalendarDate(2025, 12, 31), CalendarDate(2026, 1, 1)]
      ..sort();
    expect(sorted.map((d) => d.toIsoString()), ['2025-12-31', '2026-01-01', '2026-05-01']);
  });
}
