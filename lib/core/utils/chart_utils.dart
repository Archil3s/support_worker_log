import '../models/app_settings.dart';
import '../models/entry_type.dart';
import '../models/work_entry.dart';
import 'pay_period_utils.dart';
import 'totals.dart';

class DailyChartPoint {
  const DailyChartPoint({
    required this.date,
    required this.entries,
    required this.hours,
    required this.earnings,
    required this.kilometres,
  });

  final DateTime date;
  final int entries;
  final double hours;
  final double earnings;
  final double kilometres;
}

class EntryTypeBreakdown {
  const EntryTypeBreakdown({required this.type, required this.count});

  final EntryType type;
  final int count;
}

List<DailyChartPoint> buildDailyChartPoints({
  required Iterable<WorkEntry> entries,
  required AppSettings settings,
  required PayPeriodRange range,
}) {
  final points = <DailyChartPoint>[];

  for (var index = 0; index < 14; index++) {
    final day = range.start.add(Duration(days: index));

    final dayEntries = entries.where((entry) {
      final entryDay = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      return entryDay == day;
    }).toList();

    points.add(
      DailyChartPoint(
        date: day,
        entries: dayEntries.length,
        hours: totalHours(dayEntries),
        earnings: totalEarnings(dayEntries, settings),
        kilometres: totalKilometres(dayEntries),
      ),
    );
  }

  return points;
}

List<EntryTypeBreakdown> buildEntryTypeBreakdown(Iterable<WorkEntry> entries) {
  return [
    for (final type in EntryType.values)
      EntryTypeBreakdown(
        type: type,
        count: entries.where((entry) => entry.type == type).length,
      ),
  ];
}

DailyChartPoint? bestDayByHours(List<DailyChartPoint> points) {
  final activePoints = points.where((point) => point.hours > 0).toList();

  if (activePoints.isEmpty) {
    return null;
  }

  activePoints.sort((a, b) => b.hours.compareTo(a.hours));
  return activePoints.first;
}

double averageEarningsPerEntry({
  required Iterable<WorkEntry> entries,
  required AppSettings settings,
}) {
  final entryList = entries.toList();

  if (entryList.isEmpty) {
    return 0;
  }

  return totalEarnings(entryList, settings) / entryList.length;
}
