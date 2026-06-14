import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CleaningScreen extends StatefulWidget {
  const CleaningScreen({super.key});

  @override
  State<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends State<CleaningScreen> {
  static const _customTasksKey = 'cleaning_custom_tasks_v1';

  _CleaningFrequency selectedFrequency = _CleaningFrequency.daily;
  final checkedTaskIdsByFrequency = <_CleaningFrequency, Set<String>>{
    for (final frequency in _CleaningFrequency.values) frequency: <String>{},
  };
  final customTasks = <_CleaningFrequency, List<_CleaningTask>>{
    for (final frequency in _CleaningFrequency.values) frequency: [],
  };
  bool loading = true;

  Set<String> get checkedTaskIds =>
      checkedTaskIdsByFrequency[selectedFrequency]!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCustomTasks = prefs.getString(_customTasksKey);

    if (rawCustomTasks != null && rawCustomTasks.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCustomTasks);
        if (decoded is Map<String, dynamic>) {
          for (final frequency in _CleaningFrequency.values) {
            final rawTasks = decoded[frequency.name];
            if (rawTasks is! List) continue;

            customTasks[frequency] = rawTasks
                .whereType<Map<String, dynamic>>()
                .map(_CleaningTask.fromJson)
                .where((task) => task.label.trim().isNotEmpty)
                .toList();
          }
        }
      } catch (_) {
        customTasks.updateAll((_, value) => []);
      }
    }

    final storedChecked = {
      for (final frequency in _CleaningFrequency.values)
        frequency: prefs.getStringList(_checkedKey(frequency)) ?? const [],
    };

    if (!mounted) return;

    setState(() {
      for (final entry in storedChecked.entries) {
        checkedTaskIdsByFrequency[entry.key]!
          ..clear()
          ..addAll(entry.value);
      }
      loading = false;
    });
  }

  Future<void> _loadChecked(_CleaningFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    final storedChecked = prefs.getStringList(_checkedKey(frequency));

    if (!mounted) return;

    setState(() {
      selectedFrequency = frequency;
      checkedTaskIdsByFrequency[frequency]!
        ..clear()
        ..addAll(storedChecked ?? const []);
    });
  }

  Future<void> _saveChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _checkedKey(selectedFrequency),
      checkedTaskIdsByFrequency[selectedFrequency]!.toList()..sort(),
    );
  }

  Future<void> _saveCustomTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = {
      for (final item in customTasks.entries)
        item.key.name: item.value.map((task) => task.toJson()).toList(),
    };
    await prefs.setString(_customTasksKey, jsonEncode(encoded));
  }

  Future<void> _toggleTask(String id, bool checked) async {
    setState(() {
      if (checked) {
        checkedTaskIds.add(id);
      } else {
        checkedTaskIds.remove(id);
      }
    });

    await _saveChecked();
  }

  Future<void> _resetCurrentPeriod() async {
    setState(checkedTaskIds.clear);
    await _saveChecked();
  }

  Future<void> _addCustomTask() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add ${selectedFrequency.label.toLowerCase()} task'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Task'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    final trimmed = label?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final task = _CleaningTask(
      id: 'custom-${selectedFrequency.name}-${DateTime.now().microsecondsSinceEpoch}',
      label: trimmed,
      area: 'Custom',
    );

    setState(() => customTasks[selectedFrequency]!.add(task));
    await _saveCustomTasks();
  }

  Future<void> _deleteCustomTask(_CleaningTask task) async {
    setState(() {
      checkedTaskIds.remove(task.id);
      customTasks[selectedFrequency]!.removeWhere((item) => item.id == task.id);
    });

    await _saveCustomTasks();
    await _saveChecked();
  }

  List<_CleaningTask> _tasksFor(_CleaningFrequency frequency) {
    return [..._defaultCleaningTasks[frequency]!, ...customTasks[frequency]!];
  }

  _CleaningProgress _progressFor(_CleaningFrequency frequency) {
    final tasks = _tasksFor(frequency);
    final checked = frequency == selectedFrequency ? checkedTaskIds : null;

    return _CleaningProgress(
      frequency: frequency,
      total: tasks.length,
      checkedIds: checked ?? checkedTaskIdsByFrequency[frequency],
    );
  }

  String _checkedKey(_CleaningFrequency frequency) {
    return 'cleaning_checked_${frequency.name}_${frequency.periodKey()}';
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasksFor(selectedFrequency);
    final completed = tasks
        .where((task) => checkedTaskIds.contains(task.id))
        .length;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _CleaningHero(
          completed: completed,
          total: tasks.length,
          progress: progress,
          periodLabel: selectedFrequency.periodLabel(),
        ),
        const SizedBox(height: 14),
        SegmentedButton<_CleaningFrequency>(
          segments: const [
            ButtonSegment(
              value: _CleaningFrequency.daily,
              icon: Icon(Icons.today_outlined),
              label: Text('Daily'),
            ),
            ButtonSegment(
              value: _CleaningFrequency.weekly,
              icon: Icon(Icons.date_range_outlined),
              label: Text('Weekly'),
            ),
            ButtonSegment(
              value: _CleaningFrequency.monthly,
              icon: Icon(Icons.calendar_view_month_outlined),
              label: Text('Monthly'),
            ),
          ],
          selected: {selectedFrequency},
          onSelectionChanged: (values) => _loadChecked(values.first),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final frequency in _CleaningFrequency.values)
              _CleaningProgressChip(progress: _progressFor(frequency)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _addCustomTask,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Task'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: _resetCurrentPeriod,
              tooltip: 'Reset current checklist',
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final area in _areasFor(tasks)) ...[
          _CleaningAreaCard(
            area: area,
            tasks: tasks.where((task) => task.area == area).toList(),
            checkedTaskIds: checkedTaskIds,
            onChanged: _toggleTask,
            onDeleteCustomTask: _deleteCustomTask,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CleaningHero extends StatelessWidget {
  const _CleaningHero({
    required this.completed,
    required this.total,
    required this.progress,
    required this.periodLabel,
  });

  final int completed;
  final int total;
  final double progress;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13241E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF31E981)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cleaning_services_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'House Cleaning',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$completed/$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: const Color(0xFF243247),
            color: const Color(0xFF31E981),
          ),
          const SizedBox(height: 10),
          Text(
            periodLabel,
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CleaningProgressChip extends StatelessWidget {
  const _CleaningProgressChip({required this.progress});

  final _CleaningProgress progress;

  @override
  Widget build(BuildContext context) {
    final completed = progress.completed;
    final total = progress.total;
    final done = total > 0 && completed == total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: done ? const Color(0xFF102A1C) : const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done ? const Color(0xFF31E981) : const Color(0xFF34405F),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : progress.frequency.icon,
            color: done ? const Color(0xFF31E981) : const Color(0xFF8396C7),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${progress.frequency.label} $completed/$total',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CleaningAreaCard extends StatelessWidget {
  const _CleaningAreaCard({
    required this.area,
    required this.tasks,
    required this.checkedTaskIds,
    required this.onChanged,
    required this.onDeleteCustomTask,
  });

  final String area;
  final List<_CleaningTask> tasks;
  final Set<String> checkedTaskIds;
  final Future<void> Function(String id, bool checked) onChanged;
  final Future<void> Function(_CleaningTask task) onDeleteCustomTask;

  @override
  Widget build(BuildContext context) {
    final completed = tasks
        .where((task) => checkedTaskIds.contains(task.id))
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      area,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '$completed/${tasks.length}',
                    style: const TextStyle(
                      color: Color(0xFF8396C7),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (final task in tasks)
              CheckboxListTile(
                value: checkedTaskIds.contains(task.id),
                onChanged: (value) => onChanged(task.id, value ?? false),
                dense: true,
                visualDensity: VisualDensity.compact,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  task.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    decoration: checkedTaskIds.contains(task.id)
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                secondary: task.custom
                    ? IconButton(
                        tooltip: 'Delete task',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => onDeleteCustomTask(task),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _CleaningProgress {
  const _CleaningProgress({
    required this.frequency,
    required this.total,
    required this.checkedIds,
  });

  final _CleaningFrequency frequency;
  final int total;
  final Set<String>? checkedIds;

  int get completed {
    if (checkedIds == null) return 0;
    return checkedIds!.length;
  }
}

class _CleaningTask {
  const _CleaningTask({
    required this.id,
    required this.label,
    required this.area,
    this.custom = false,
  });

  final String id;
  final String label;
  final String area;
  final bool custom;

  factory _CleaningTask.fromJson(Map<String, dynamic> json) {
    return _CleaningTask(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      area: json['area'] as String? ?? 'Custom',
      custom: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'area': area};
  }
}

enum _CleaningFrequency { daily, weekly, monthly }

extension _CleaningFrequencyDetails on _CleaningFrequency {
  String get label {
    return switch (this) {
      _CleaningFrequency.daily => 'Daily',
      _CleaningFrequency.weekly => 'Weekly',
      _CleaningFrequency.monthly => 'Monthly',
    };
  }

  IconData get icon {
    return switch (this) {
      _CleaningFrequency.daily => Icons.today_outlined,
      _CleaningFrequency.weekly => Icons.date_range_outlined,
      _CleaningFrequency.monthly => Icons.calendar_view_month_outlined,
    };
  }

  String periodKey() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    return switch (this) {
      _CleaningFrequency.daily =>
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}',
      _CleaningFrequency.weekly =>
        '${weekStart.year}-w${_twoDigits(_weekOfYear(weekStart))}',
      _CleaningFrequency.monthly => '${now.year}-${_twoDigits(now.month)}',
    };
  }

  String periodLabel() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return switch (this) {
      _CleaningFrequency.daily =>
        'Today: ${_twoDigits(now.day)}/${_twoDigits(now.month)}/${now.year}',
      _CleaningFrequency.weekly =>
        'Week: ${_shortDate(weekStart)} - ${_shortDate(weekEnd)}',
      _CleaningFrequency.monthly =>
        'Month: ${_monthName(now.month)} ${now.year}',
    };
  }
}

const _defaultCleaningTasks = {
  _CleaningFrequency.daily: [
    _CleaningTask(id: 'daily-make-bed', label: 'Make bed', area: 'Bedroom'),
    _CleaningTask(
      id: 'daily-dishes',
      label: 'Wash dishes or load dishwasher',
      area: 'Kitchen',
    ),
    _CleaningTask(
      id: 'daily-benches',
      label: 'Wipe kitchen benches and table',
      area: 'Kitchen',
    ),
    _CleaningTask(
      id: 'daily-floor',
      label: 'Quick sweep or vacuum high-traffic floor',
      area: 'Floors',
    ),
    _CleaningTask(
      id: 'daily-bathroom',
      label: 'Wipe bathroom sink and toilet seat',
      area: 'Bathroom',
    ),
    _CleaningTask(
      id: 'daily-laundry',
      label: 'Put clothes in basket or start one load',
      area: 'Laundry',
    ),
    _CleaningTask(
      id: 'daily-rubbish',
      label: 'Empty rubbish if full',
      area: 'Whole house',
    ),
    _CleaningTask(
      id: 'daily-reset',
      label: '10-minute tidy reset',
      area: 'Whole house',
    ),
  ],
  _CleaningFrequency.weekly: [
    _CleaningTask(
      id: 'weekly-sheets',
      label: 'Change bed sheets',
      area: 'Bedroom',
    ),
    _CleaningTask(
      id: 'weekly-vacuum',
      label: 'Vacuum all rooms',
      area: 'Floors',
    ),
    _CleaningTask(id: 'weekly-mop', label: 'Mop hard floors', area: 'Floors'),
    _CleaningTask(
      id: 'weekly-bathroom',
      label: 'Clean shower, bath, sink, and toilet',
      area: 'Bathroom',
    ),
    _CleaningTask(
      id: 'weekly-dust',
      label: 'Dust shelves, TV, desk, and surfaces',
      area: 'Whole house',
    ),
    _CleaningTask(
      id: 'weekly-fridge',
      label: 'Clear old food from fridge',
      area: 'Kitchen',
    ),
    _CleaningTask(
      id: 'weekly-appliances',
      label: 'Wipe microwave, stovetop, and appliances',
      area: 'Kitchen',
    ),
    _CleaningTask(
      id: 'weekly-towels',
      label: 'Wash towels and bathroom mats',
      area: 'Laundry',
    ),
    _CleaningTask(
      id: 'weekly-bins',
      label: 'Empty bins and wipe bin lids',
      area: 'Whole house',
    ),
  ],
  _CleaningFrequency.monthly: [
    _CleaningTask(
      id: 'monthly-oven',
      label: 'Deep clean oven or air fryer',
      area: 'Kitchen',
    ),
    _CleaningTask(
      id: 'monthly-fridge',
      label: 'Wipe fridge shelves and seals',
      area: 'Kitchen',
    ),
    _CleaningTask(
      id: 'monthly-windows',
      label: 'Clean windows and mirrors',
      area: 'Whole house',
    ),
    _CleaningTask(
      id: 'monthly-skirting',
      label: 'Wipe skirting boards, doors, and handles',
      area: 'Whole house',
    ),
    _CleaningTask(
      id: 'monthly-under-furniture',
      label: 'Vacuum under bed, couch, and furniture',
      area: 'Floors',
    ),
    _CleaningTask(
      id: 'monthly-cupboards',
      label: 'Declutter one cupboard or drawer',
      area: 'Whole house',
    ),
    _CleaningTask(
      id: 'monthly-bedding',
      label: 'Wash blankets, doona cover, or pillows',
      area: 'Bedroom',
    ),
    _CleaningTask(
      id: 'monthly-machines',
      label: 'Clean washing machine and dishwasher filters',
      area: 'Laundry',
    ),
    _CleaningTask(
      id: 'monthly-vents',
      label: 'Dust vents, fans, and light fittings',
      area: 'Whole house',
    ),
  ],
};

List<String> _areasFor(List<_CleaningTask> tasks) {
  final seen = <String>{};
  final areas = <String>[];

  for (final task in tasks) {
    if (seen.add(task.area)) areas.add(task.area);
  }

  return areas;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _shortDate(DateTime value) {
  return '${_twoDigits(value.day)}/${_twoDigits(value.month)}';
}

int _weekOfYear(DateTime date) {
  final firstDay = DateTime(date.year);
  final days = date.difference(firstDay).inDays;
  return ((days + firstDay.weekday) / 7).ceil();
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return names[month - 1];
}
