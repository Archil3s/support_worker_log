import '../models/work_entry.dart';

final defaultPayPeriodAnchorDate = DateTime(2025, 12, 14);

const int invoicePeriodDays = 14;

class PayPeriodRange {
  const PayPeriodRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }

  PayPeriodRange shiftFortnights(int count) {
    return PayPeriodRange(
      start: addCalendarDays(start, invoicePeriodDays * count),
      end: addCalendarDays(end, invoicePeriodDays * count),
    );
  }

  PayPeriodRange get previous => shiftFortnights(-1);
  PayPeriodRange get next => shiftFortnights(1);

  DateTime get weekOneStart => start;
  DateTime get weekOneEnd => addCalendarDays(start, 6);
  DateTime get weekTwoStart => addCalendarDays(start, 7);
  DateTime get weekTwoEnd => end;

  int get daysInclusive {
    return calendarDaysBetween(start, end) + 1;
  }
}

PayPeriodRange currentFortnight({DateTime? anchorDate}) {
  return fortnightForDate(DateTime.now(), anchorDate: anchorDate);
}

PayPeriodRange fortnightForDate(DateTime date, {DateTime? anchorDate}) {
  final normalizedDate = DateTime(date.year, date.month, date.day);

  final rawAnchor = anchorDate ?? defaultPayPeriodAnchorDate;
  final anchor = DateTime(rawAnchor.year, rawAnchor.month, rawAnchor.day);

  final daysSinceAnchor = calendarDaysBetween(anchor, normalizedDate);
  final periodOffset = _floorDivide(daysSinceAnchor, invoicePeriodDays);
  final start = addCalendarDays(anchor, periodOffset * invoicePeriodDays);

  return PayPeriodRange(
    start: start,
    end: addCalendarDays(start, invoicePeriodDays - 1),
  );
}

int calendarDaysBetween(DateTime start, DateTime end) {
  final startDate = DateTime.utc(start.year, start.month, start.day);
  final endDate = DateTime.utc(end.year, end.month, end.day);

  return endDate.difference(startDate).inDays;
}

DateTime addCalendarDays(DateTime date, int days) {
  return DateTime(date.year, date.month, date.day + days);
}

int _floorDivide(int value, int divisor) {
  if (value >= 0) return value ~/ divisor;
  return -(((-value) + divisor - 1) ~/ divisor);
}

List<WorkEntry> entriesInRange(
  Iterable<WorkEntry> entries,
  PayPeriodRange range,
) {
  final filtered = entries.where((entry) => range.contains(entry.date)).toList()
    ..sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;

      final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
      final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
      return aMinutes.compareTo(bMinutes);
    });

  return filtered;
}

List<WorkEntry> entriesBetween(
  Iterable<WorkEntry> entries,
  DateTime start,
  DateTime end,
) {
  final range = PayPeriodRange(start: start, end: end);
  return entriesInRange(entries, range);
}

Map<DateTime, List<WorkEntry>> groupEntriesByDay(Iterable<WorkEntry> entries) {
  final grouped = <DateTime, List<WorkEntry>>{};

  for (final entry in entries) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    grouped.putIfAbsent(day, () => []).add(entry);
  }

  final sortedKeys = grouped.keys.toList()..sort();

  return {for (final key in sortedKeys) key: grouped[key]!};
}
