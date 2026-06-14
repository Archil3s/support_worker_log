import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/features/cleaning/cleaning_models.dart';

void main() {
  const alex = CleaningMember(id: 'alex', name: 'Alex', colorValue: 0xFF31E981);
  const sam = CleaningMember(id: 'sam', name: 'Sam', colorValue: 0xFF4F8DF7);

  test('returns the fixed assignee when rotation is off', () {
    const task = CleaningTask(
      id: 'dishes',
      label: 'Wash dishes',
      area: 'Kitchen',
      minutes: 10,
      frequency: CleaningFrequency.daily,
      time: CleaningTime.evening,
      assigneeIds: ['sam', 'alex'],
    );

    final assigned = assignedCleaningMember(task, DateTime(2026, 6, 15), const [
      alex,
      sam,
    ]);

    expect(assigned?.id, 'sam');
  });

  test('rotates daily tasks across assigned household members', () {
    const task = CleaningTask(
      id: 'dishes',
      label: 'Wash dishes',
      area: 'Kitchen',
      minutes: 10,
      frequency: CleaningFrequency.daily,
      time: CleaningTime.evening,
      assigneeIds: ['alex', 'sam'],
      rotateAssignees: true,
    );

    final first = assignedCleaningMember(task, DateTime(2026, 6, 15), const [
      alex,
      sam,
    ]);
    final second = assignedCleaningMember(task, DateTime(2026, 6, 16), const [
      alex,
      sam,
    ]);

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first?.id, isNot(second?.id));
  });

  test('ignores inactive or removed assignees', () {
    const task = CleaningTask(
      id: 'floors',
      label: 'Sweep',
      area: 'Floors',
      minutes: 10,
      frequency: CleaningFrequency.daily,
      time: CleaningTime.evening,
      assigneeIds: ['missing'],
    );

    expect(
      assignedCleaningMember(task, DateTime(2026, 6, 15), const [alex]),
      isNull,
    );
  });

  test('task assignments and completion attribution round trip', () {
    const task = CleaningTask(
      id: 'dishes',
      label: 'Wash dishes',
      area: 'Kitchen',
      minutes: 10,
      frequency: CleaningFrequency.daily,
      time: CleaningTime.evening,
      assigneeIds: ['alex', 'sam'],
      rotateAssignees: true,
    );
    final event = CleaningEvent(
      taskId: task.id,
      scheduledDate: DateTime(2026, 6, 15),
      recordedAt: DateTime(2026, 6, 15, 19),
      status: CleaningEventStatus.completed,
      completedByMemberId: 'alex',
    );

    final restoredTask = CleaningTask.fromJson(task.toJson());
    final restoredEvent = CleaningEvent.fromJson(event.toJson());

    expect(restoredTask.assigneeIds, ['alex', 'sam']);
    expect(restoredTask.rotateAssignees, isTrue);
    expect(restoredEvent.completedByMemberId, 'alex');
  });
}
