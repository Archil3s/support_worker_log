import '../models/work_entry.dart';

final defaultPayPeriodAnchorDate = DateTime(2025, 12, 14);

class PayPeriodRange {
  const PayPeriodRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }

  PayPeriodRange shiftFortnights(int count) {
    final offset = Duration(days: 14 * count);

    return PayPeriodRange(start: start.add(offset), end: end.add(offset));
  }

  PayPeriodRange get previous => shiftFortnights(-1);
  PayPeriodRange get next => shiftFortnights(1);

  DateTime get weekOneStart => start;
  DateTime get weekOneEnd => start.add(const Duration(days: 6));
  DateTime get weekTwoStart => start.add(const Duration(days: 7));
  DateTime get weekTwoEnd => end;
}

PayPeriodRange currentFortnight({DateTime? anchorDate}) {
  return fortnightForDate(DateTime.now(), anchorDate: anchorDate);
}

PayPeriodRange fortnightForDate(DateTime date, {DateTime? anchorDate}) {
  final normalizedDate = DateTime(date.year, date.month, date.day);

  final rawAnchor = anchorDate ?? defaultPayPeriodAnchorDate;
  final anchor = DateTime(rawAnchor.year, rawAnchor.month, rawAnchor.day);

  final daysSinceAnchor = normalizedDate.difference(anchor).inDays;
  final periodOffset = _floorDivide(daysSinceAnchor, 14);
  final start = anchor.add(Duration(days: periodOffset * 14));

  return PayPeriodRange(start: start, end: start.add(const Duration(days: 13)));
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
