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
    expect(data.members.single.name, 'Me');
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

    const member = CleaningMember(
      id: 'member-sam',
      name: 'Sam',
      colorValue: 0xFF4F8DF7,
    );
    await repository.save(
      CleaningData(
        tasks: const [task],
        events: [event],
        members: const [member],
      ),
    );
    final restored = await repository.load();

    expect(restored.tasks.any((item) => item.id == task.id), isTrue);
    expect(restored.events.single.taskId, task.id);
    expect(restored.members.single.name, 'Sam');
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

  test('old saved data gains a default household member', () async {
    SharedPreferences.setMockInitialValues({
      'cleaning_data_v2': jsonEncode({
        'tasks': <Object?>[],
        'events': <Object?>[],
      }),
    });

    final data = await const CleaningRepository().load();

    expect(data.members.single.id, 'member-me');
  });
}
