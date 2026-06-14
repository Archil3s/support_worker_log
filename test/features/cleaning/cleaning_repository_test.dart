import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/features/cleaning/cleaning_models.dart';
import 'package:support_worker_log/features/cleaning/cleaning_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads the no-dishwasher default plan', () async {
    final data = await const CleaningRepository().load();

    expect(data.tasks, isNotEmpty);
    expect(
      data.tasks.any((task) => task.label == 'Wash dinner dishes'),
      isTrue,
    );
    expect(
      data.tasks.any((task) => task.label.toLowerCase().contains('dishwasher')),
      isFalse,
    );
  });

  test('saves and restores task history', () async {
    const task = CleaningTask(
      id: 'custom-test',
      label: 'Clean desk',
      area: 'Whole house',
      minutes: 5,
      frequency: CleaningFrequency.daily,
      time: CleaningTime.anytime,
      custom: true,
    );
    final event = CleaningEvent(
      taskId: task.id,
      scheduledDate: DateTime(2026, 6, 14),
      recordedAt: DateTime(2026, 6, 14, 10),
      status: CleaningEventStatus.completed,
    );
    const repository = CleaningRepository();

    await repository.save(CleaningData(tasks: const [task], events: [event]));
    final restored = await repository.load();

    expect(restored.tasks.any((item) => item.id == task.id), isTrue);
    expect(restored.events.single.taskId, task.id);
  });

  test('migrates legacy custom tasks', () async {
    SharedPreferences.setMockInitialValues({
      'cleaning_custom_tasks_v1': jsonEncode({
        'daily': [
          {'id': 'legacy-task', 'label': 'Clean keyboard', 'area': 'Custom'},
        ],
      }),
    });

    final data = await const CleaningRepository().load();

    expect(data.tasks.any((task) => task.id == 'legacy-task'), isTrue);
  });
}
