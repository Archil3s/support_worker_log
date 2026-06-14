import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/features/cleaning/cleaning_analytics.dart';
import 'package:support_worker_log/features/cleaning/cleaning_models.dart';

void main() {
  const dailyTask = CleaningTask(
    id: 'dishes',
    label: 'Wash dishes',
    area: 'Kitchen',
    minutes: 10,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.evening,
  );

  test('tracks completed, skipped, missed, and current incomplete tasks', () {
    final today = DateTime(2026, 6, 14);
    final data = CleaningData(
      tasks: const [dailyTask],
      events: [
        CleaningEvent(
          taskId: dailyTask.id,
          scheduledDate: DateTime(2026, 6, 12),
          recordedAt: DateTime(2026, 6, 12, 19, 30),
          status: CleaningEventStatus.completed,
        ),
        CleaningEvent(
          taskId: dailyTask.id,
          scheduledDate: DateTime(2026, 6, 13),
          recordedAt: DateTime(2026, 6, 13, 20),
          status: CleaningEventStatus.skipped,
        ),
      ],
    );

    final insights = buildCleaningInsights(data, today: today, dayCount: 3);

    expect(insights.scheduled, 3);
    expect(insights.completed, 1);
    expect(insights.skipped, 1);
    expect(insights.missed, 0);
    expect(insights.completionRate, closeTo(1 / 3, 0.001));
    expect(insights.averageCompletionHour, 19.5);
  });

  test('counts unrecorded past tasks as missed', () {
    final insights = buildCleaningInsights(
      const CleaningData(tasks: [dailyTask], events: []),
      today: DateTime(2026, 6, 14),
      dayCount: 2,
    );

    expect(insights.missed, 1);
    expect(insights.mostMissed.single.task.id, dailyTask.id);
  });

  test('tracks a completion recorded after its scheduled day as late', () {
    final data = CleaningData(
      tasks: const [dailyTask],
      events: [
        CleaningEvent(
          taskId: dailyTask.id,
          scheduledDate: DateTime(2026, 6, 13),
          recordedAt: DateTime(2026, 6, 14, 9),
          status: CleaningEventStatus.completed,
        ),
      ],
    );

    final insights = buildCleaningInsights(
      data,
      today: DateTime(2026, 6, 14),
      dayCount: 2,
    );

    expect(insights.completedLate, 1);
  });
}
