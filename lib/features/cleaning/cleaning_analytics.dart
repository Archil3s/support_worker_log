import 'cleaning_models.dart';

class CleaningDaySummary {
  const CleaningDaySummary({
    required this.date,
    required this.completed,
    required this.due,
  });

  final DateTime date;
  final int completed;
  final int due;

  double get rate => due == 0 ? 0 : completed / due;
}

class CleaningAreaSummary {
  const CleaningAreaSummary({
    required this.area,
    required this.completed,
    required this.due,
  });

  final String area;
  final int completed;
  final int due;

  double get rate => due == 0 ? 0 : completed / due;
}

class CleaningMissSummary {
  const CleaningMissSummary({required this.task, required this.missed});

  final CleaningTask task;
  final int missed;
}

class CleaningInsights {
  const CleaningInsights({
    required this.days,
    required this.areas,
    required this.mostMissed,
    required this.completed,
    required this.scheduled,
    required this.missed,
    required this.skipped,
    required this.completedLate,
    required this.currentStreak,
    required this.averageCompletionHour,
  });

  final List<CleaningDaySummary> days;
  final List<CleaningAreaSummary> areas;
  final List<CleaningMissSummary> mostMissed;
  final int completed;
  final int scheduled;
  final int missed;
  final int skipped;
  final int completedLate;
  final int currentStreak;
  final double? averageCompletionHour;

  double get completionRate => scheduled == 0 ? 0 : completed / scheduled;
}

CleaningInsights buildCleaningInsights(
  CleaningData data, {
  required DateTime today,
  required int dayCount,
}) {
  final end = cleaningDateOnly(today);
  final start = end.subtract(Duration(days: dayCount - 1));
  final eventsByKey = {for (final event in data.events) event.key: event};
  final taskById = {for (final task in data.tasks) task.id: task};
  final trackingStartedAt = data.trackingStartedAt;
  final days = <CleaningDaySummary>[];
  final areaCounts = <String, List<int>>{};
  final missedCounts = <String, int>{};
  var completed = 0;
  var scheduled = 0;
  var missed = 0;
  var skipped = 0;
  var completedLate = 0;
  var completionHourTotal = 0.0;

  for (var offset = 0; offset < dayCount; offset++) {
    final date = start.add(Duration(days: offset));
    if (trackingStartedAt != null && date.isBefore(trackingStartedAt)) {
      days.add(CleaningDaySummary(date: date, completed: 0, due: 0));
      continue;
    }
    final dueTasks = data.tasks.where((task) => task.isDue(date));
    var dayCompleted = 0;
    var dayDue = 0;
    for (final task in dueTasks) {
      scheduled++;
      dayDue++;
      final event = eventsByKey['${task.id}:${cleaningDateKey(date)}'];
      final counts = areaCounts.putIfAbsent(task.area, () => [0, 0]);
      counts[1]++;
      if (event?.status == CleaningEventStatus.completed) {
        completed++;
        dayCompleted++;
        counts[0]++;
        completionHourTotal += event!.recordedAt.hour;
        completionHourTotal += event.recordedAt.minute / 60;
        if (event.completedLate) completedLate++;
      } else if (event?.status == CleaningEventStatus.skipped) {
        skipped++;
      } else if (date.isBefore(end)) {
        missed++;
        missedCounts.update(task.id, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    days.add(
      CleaningDaySummary(date: date, completed: dayCompleted, due: dayDue),
    );
  }

  final areas =
      areaCounts.entries
          .map(
            (entry) => CleaningAreaSummary(
              area: entry.key,
              completed: entry.value[0],
              due: entry.value[1],
            ),
          )
          .toList()
        ..sort((a, b) => b.rate.compareTo(a.rate));
  final mostMissed =
      missedCounts.entries
          .where((entry) => taskById.containsKey(entry.key))
          .map(
            (entry) => CleaningMissSummary(
              task: taskById[entry.key]!,
              missed: entry.value,
            ),
          )
          .toList()
        ..sort((a, b) => b.missed.compareTo(a.missed));

  return CleaningInsights(
    days: days,
    areas: areas,
    mostMissed: mostMissed,
    completed: completed,
    scheduled: scheduled,
    missed: missed,
    skipped: skipped,
    completedLate: completedLate,
    currentStreak: _cleaningStreak(
      data.tasks,
      eventsByKey,
      end,
      trackingStartedAt,
    ),
    averageCompletionHour: completed == 0
        ? null
        : completionHourTotal / completed,
  );
}

int _cleaningStreak(
  List<CleaningTask> tasks,
  Map<String, CleaningEvent> eventsByKey,
  DateTime today,
  DateTime? trackingStartedAt,
) {
  var streak = 0;
  for (var offset = 1; offset <= 365; offset++) {
    final date = today.subtract(Duration(days: offset));
    if (trackingStartedAt != null && date.isBefore(trackingStartedAt)) break;
    final dueTasks = tasks.where((task) => task.isDue(date)).toList();
    if (dueTasks.isEmpty) continue;
    final completed = dueTasks.where((task) {
      return eventsByKey['${task.id}:${cleaningDateKey(date)}']?.status ==
          CleaningEventStatus.completed;
    }).length;
    if (completed / dueTasks.length < 0.7) break;
    streak++;
  }
  return streak;
}
