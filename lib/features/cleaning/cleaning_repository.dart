import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cleaning_models.dart';

class CleaningRepository {
  const CleaningRepository();

  static const _dataKey = 'cleaning_data_v2';
  static const _legacyCustomTasksKey = 'cleaning_custom_tasks_v1';

  Future<CleaningData> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_dataKey);
    if (stored != null && stored.trim().isNotEmpty) {
      try {
        return _decode(stored);
      } on Object {
        // Fall through to a clean plan if the local payload is damaged.
      }
    }

    final migrated = await _migrateLegacyData(preferences);
    await save(migrated);
    return migrated;
  }

  Future<void> save(CleaningData data) async {
    final preferences = await SharedPreferences.getInstance();
    final oldestKeptDate = cleaningDateOnly(
      DateTime.now(),
    ).subtract(const Duration(days: 730));
    final events = data.events
        .where((event) => !event.scheduledDate.isBefore(oldestKeptDate))
        .toList();
    await preferences.setString(
      _dataKey,
      jsonEncode({
        'trackingStartedAt':
            (data.trackingStartedAt ?? cleaningDateOnly(DateTime.now()))
                .toIso8601String(),
        'tasks': data.tasks.map((task) => task.toJson()).toList(),
        'events': events.map((event) => event.toJson()).toList(),
      }),
    );
  }

  CleaningData _decode(String stored) {
    final decoded = jsonDecode(stored) as Map<String, dynamic>;
    final storedTasks = (decoded['tasks'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CleaningTask.fromJson)
        .where((task) => task.id.isNotEmpty && task.label.isNotEmpty)
        .toList();
    final events = (decoded['events'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CleaningEvent.fromJson)
        .where((event) => event.taskId.isNotEmpty)
        .toList();
    final storedById = {for (final task in storedTasks) task.id: task};
    final mergedTasks = [
      for (final task in defaultCleaningTasks)
        storedById.remove(task.id) ?? task,
      ...storedById.values,
    ];
    final rawTrackingStartedAt = decoded['trackingStartedAt'] as String?;
    return CleaningData(
      tasks: mergedTasks,
      events: events,
      trackingStartedAt: rawTrackingStartedAt == null
          ? cleaningDateOnly(DateTime.now())
          : cleaningDateOnly(DateTime.parse(rawTrackingStartedAt)),
    );
  }

  Future<CleaningData> _migrateLegacyData(SharedPreferences preferences) async {
    final tasks = [...defaultCleaningTasks];
    final rawCustomTasks = preferences.getString(_legacyCustomTasksKey);
    if (rawCustomTasks != null && rawCustomTasks.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCustomTasks) as Map<String, dynamic>;
        for (final frequency in CleaningFrequency.values) {
          final legacyTasks =
              decoded[frequency.name] as List<dynamic>? ?? const [];
          for (final item in legacyTasks.whereType<Map<String, dynamic>>()) {
            final label = item['label'] as String? ?? '';
            if (label.trim().isEmpty) continue;
            tasks.add(
              CleaningTask(
                id:
                    item['id'] as String? ??
                    'custom-${DateTime.now().microsecondsSinceEpoch}',
                label: label.trim(),
                area: item['area'] as String? ?? 'Custom',
                minutes: 10,
                frequency: frequency,
                time: CleaningTime.anytime,
                weekdays: frequency == CleaningFrequency.weekly
                    ? [DateTime.now().weekday]
                    : const [],
                monthDay: frequency == CleaningFrequency.monthly
                    ? DateTime.now().day
                    : null,
                custom: true,
              ),
            );
          }
        }
      } on Object {
        // Keep the default plan if legacy custom data cannot be decoded.
      }
    }

    final today = cleaningDateOnly(DateTime.now());
    final checkedIds =
        preferences.getStringList(
          'cleaning_checked_daily_${cleaningDateKey(today)}',
        ) ??
        const [];
    final events = checkedIds.map((taskId) {
      return CleaningEvent(
        taskId: taskId,
        scheduledDate: today,
        recordedAt: DateTime.now(),
        status: CleaningEventStatus.completed,
      );
    }).toList();
    return CleaningData(tasks: tasks, events: events, trackingStartedAt: today);
  }
}

const defaultCleaningTasks = [
  CleaningTask(
    id: 'daily-dishes-breakfast',
    label: 'Wash breakfast dishes',
    area: 'Kitchen',
    minutes: 8,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.morning,
    essential: true,
  ),
  CleaningTask(
    id: 'daily-benches',
    label: 'Wipe kitchen benches and sink',
    area: 'Kitchen',
    minutes: 6,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.morning,
    essential: true,
  ),
  CleaningTask(
    id: 'daily-make-bed',
    label: 'Make the bed',
    area: 'Bedroom',
    minutes: 3,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.morning,
  ),
  CleaningTask(
    id: 'daily-laundry-check',
    label: 'Check laundry basket',
    area: 'Laundry',
    minutes: 4,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.morning,
  ),
  CleaningTask(
    id: 'daily-clutter',
    label: '5-minute clutter pickup',
    area: 'Whole house',
    minutes: 5,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.daytime,
  ),
  CleaningTask(
    id: 'daily-dishes-day',
    label: 'Wash daytime dishes',
    area: 'Kitchen',
    minutes: 7,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.daytime,
    essential: true,
  ),
  CleaningTask(
    id: 'daily-bathroom',
    label: 'Reset bathroom surfaces',
    area: 'Bathroom',
    minutes: 5,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.daytime,
  ),
  CleaningTask(
    id: 'daily-dishes-dinner',
    label: 'Wash dinner dishes',
    area: 'Kitchen',
    minutes: 12,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.evening,
    essential: true,
  ),
  CleaningTask(
    id: 'daily-dishes-away',
    label: 'Dry and put dishes away',
    area: 'Kitchen',
    minutes: 6,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.evening,
  ),
  CleaningTask(
    id: 'daily-lounge',
    label: 'Reset lounge and cushions',
    area: 'Living room',
    minutes: 7,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.evening,
  ),
  CleaningTask(
    id: 'daily-floor',
    label: 'Sweep high-traffic floors',
    area: 'Floors',
    minutes: 8,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.evening,
  ),
  CleaningTask(
    id: 'daily-bins',
    label: 'Check rubbish and recycling',
    area: 'Whole house',
    minutes: 4,
    frequency: CleaningFrequency.daily,
    time: CleaningTime.evening,
  ),
  CleaningTask(
    id: 'weekly-vacuum',
    label: 'Vacuum all rooms',
    area: 'Floors',
    minutes: 25,
    frequency: CleaningFrequency.weekly,
    time: CleaningTime.daytime,
    weekdays: [2, 6],
  ),
  CleaningTask(
    id: 'weekly-bathroom',
    label: 'Deep-clean bathroom and toilet',
    area: 'Bathroom',
    minutes: 20,
    frequency: CleaningFrequency.weekly,
    time: CleaningTime.daytime,
    weekdays: [3],
  ),
  CleaningTask(
    id: 'weekly-sheets',
    label: 'Change bed sheets',
    area: 'Bedroom',
    minutes: 15,
    frequency: CleaningFrequency.weekly,
    time: CleaningTime.daytime,
    weekdays: [6],
  ),
  CleaningTask(
    id: 'weekly-mop',
    label: 'Mop hard floors',
    area: 'Floors',
    minutes: 20,
    frequency: CleaningFrequency.weekly,
    time: CleaningTime.daytime,
    weekdays: [5],
  ),
  CleaningTask(
    id: 'weekly-fridge',
    label: 'Clear old food and wipe fridge',
    area: 'Kitchen',
    minutes: 15,
    frequency: CleaningFrequency.weekly,
    time: CleaningTime.daytime,
    weekdays: [7],
  ),
  CleaningTask(
    id: 'weekly-dust',
    label: 'Dust shelves and surfaces',
    area: 'Whole house',
    minutes: 18,
    frequency: CleaningFrequency.weekly,
    time: CleaningTime.daytime,
    weekdays: [4],
  ),
  CleaningTask(
    id: 'weekly-towels',
    label: 'Wash towels and bathroom mats',
    area: 'Laundry',
    minutes: 10,
    frequency: CleaningFrequency.weekly,
    time: CleaningTime.daytime,
    weekdays: [1],
  ),
  CleaningTask(
    id: 'monthly-oven',
    label: 'Deep-clean oven or air fryer',
    area: 'Kitchen',
    minutes: 35,
    frequency: CleaningFrequency.monthly,
    time: CleaningTime.daytime,
    monthDay: 15,
  ),
  CleaningTask(
    id: 'monthly-windows',
    label: 'Clean windows and mirrors',
    area: 'Whole house',
    minutes: 25,
    frequency: CleaningFrequency.monthly,
    time: CleaningTime.daytime,
    monthDay: 1,
  ),
  CleaningTask(
    id: 'monthly-under-furniture',
    label: 'Clean under bed and furniture',
    area: 'Floors',
    minutes: 25,
    frequency: CleaningFrequency.monthly,
    time: CleaningTime.daytime,
    monthDay: 8,
  ),
  CleaningTask(
    id: 'monthly-washing-machine',
    label: 'Clean washing machine filter',
    area: 'Laundry',
    minutes: 15,
    frequency: CleaningFrequency.monthly,
    time: CleaningTime.daytime,
    monthDay: 22,
  ),
];
