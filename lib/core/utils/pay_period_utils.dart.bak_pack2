import '../models/work_entry.dart';

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

PayPeriodRange currentFortnight() {
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);

  // Fixed anchor Monday. Fortnights repeat every 14 days from here.
  final anchor = DateTime(2024, 1, 1);
  final daysSinceAnchor = normalizedToday.difference(anchor).inDays;
  final periodOffset = daysSinceAnchor ~/ 14;
  final start = anchor.add(Duration(days: periodOffset * 14));

  return PayPeriodRange(start: start, end: start.add(const Duration(days: 13)));
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
