import 'dart:async';

import 'package:flutter/material.dart';

import 'cleaning_analytics.dart';
import 'cleaning_models.dart';
import 'cleaning_repository.dart';

const _cleaningGreen = Color(0xFF31E981);
const _cleaningBlue = Color(0xFF4F8DF7);
const _cleaningAmber = Color(0xFFFFB84D);
const _cleaningCoral = Color(0xFFFF7A7A);
const _cleaningPanel = Color(0xFF151B29);
const _cleaningPanel2 = Color(0xFF20283B);
const _cleaningBorder = Color(0xFF34405F);
const _cleaningMuted = Color(0xFF8396C7);

enum _CleaningView { today, plan, insights }

enum _TaskAction { complete, skip, reset }

class CleaningScreen extends StatefulWidget {
  const CleaningScreen({super.key});

  @override
  State<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends State<CleaningScreen> {
  final _repository = const CleaningRepository();

  CleaningData _data = const CleaningData(tasks: [], events: []);
  _CleaningView _view = _CleaningView.today;
  CleaningFrequency _planFrequency = CleaningFrequency.daily;
  DateTime _selectedDate = cleaningDateOnly(DateTime.now());
  int _insightDays = 7;
  bool _loading = true;
  String? _error;

  DateTime get _today => cleaningDateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final data = await _repository.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Cleaning history could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _save(CleaningData data) async {
    setState(() {
      _data = data;
      _error = null;
    });
    try {
      await _repository.save(data);
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'Changes are visible but could not be saved.');
    }
  }

  CleaningEvent? _eventFor(CleaningTask task, DateTime date) {
    final key = '${task.id}:${cleaningDateKey(date)}';
    for (final event in _data.events.reversed) {
      if (event.key == key) return event;
    }
    return null;
  }

  List<CleaningTask> _tasksFor(DateTime date) {
    final tasks = _data.tasks.where((task) => task.isDue(date)).toList();
    tasks.sort((a, b) {
      final byTime = a.time.index.compareTo(b.time.index);
      return byTime != 0 ? byTime : a.label.compareTo(b.label);
    });
    return tasks;
  }

  Future<void> _setTaskStatus(
    CleaningTask task,
    DateTime date,
    CleaningEventStatus? status,
  ) async {
    final key = '${task.id}:${cleaningDateKey(date)}';
    final events = _data.events.where((event) => event.key != key).toList();
    if (status != null) {
      events.add(
        CleaningEvent(
          taskId: task.id,
          scheduledDate: cleaningDateOnly(date),
          recordedAt: DateTime.now(),
          status: status,
        ),
      );
    }
    await _save(_data.copyWith(events: events));
  }

  Future<void> _toggleTaskActive(CleaningTask task) async {
    final tasks = _data.tasks.map((current) {
      return current.id == task.id
          ? current.copyWith(isActive: !current.isActive)
          : current;
    }).toList();
    await _save(_data.copyWith(tasks: tasks));
  }

  Future<void> _addTask() async {
    final task = await showDialog<CleaningTask>(
      context: context,
      builder: (context) => const _CleaningTaskDialog(),
    );
    if (task == null) return;
    await _save(_data.copyWith(tasks: [..._data.tasks, task]));
  }

  Future<void> _deleteTask(CleaningTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete cleaning task?'),
          content: Text(
            '"${task.label}" and its recorded history will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: _cleaningCoral),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _save(
      CleaningData(
        tasks: _data.tasks.where((item) => item.id != task.id).toList(),
        events: _data.events.where((event) => event.taskId != task.id).toList(),
        trackingStartedAt: _data.trackingStartedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            color: _cleaningCoral.withValues(alpha: 0.16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<_CleaningView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _CleaningView.today,
                icon: Icon(Icons.today_outlined),
                label: Text('Today'),
              ),
              ButtonSegment(
                value: _CleaningView.plan,
                icon: Icon(Icons.calendar_view_week_outlined),
                label: Text('Plan'),
              ),
              ButtonSegment(
                value: _CleaningView.insights,
                icon: Icon(Icons.insights_outlined),
                label: Text('Insights'),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (selection) {
              setState(() => _view = selection.first);
            },
          ),
        ),
        Expanded(
          child: switch (_view) {
            _CleaningView.today => _buildToday(),
            _CleaningView.plan => _buildPlan(),
            _CleaningView.insights => _buildInsights(),
          },
        ),
      ],
    );
  }

  Widget _buildToday() {
    final tasks = _tasksFor(_selectedDate);
    final completed = tasks.where((task) {
      return _eventFor(task, _selectedDate)?.status ==
          CleaningEventStatus.completed;
    }).length;
    final minutesLeft = tasks
        .where((task) {
          return _eventFor(task, _selectedDate) == null;
        })
        .fold(0, (total, task) => total + task.minutes);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _DateNavigator(
          date: _selectedDate,
          today: _today,
          onPrevious: () {
            final earliest = _today.subtract(const Duration(days: 30));
            if (_selectedDate.isAfter(earliest)) {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            }
          },
          onNext: _selectedDate.isBefore(_today)
              ? () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                }
              : null,
          onToday: () => setState(() => _selectedDate = _today),
        ),
        const SizedBox(height: 12),
        _CleaningHero(
          completed: completed,
          total: tasks.length,
          minutesLeft: minutesLeft,
          isToday: _selectedDate == _today,
        ),
        const SizedBox(height: 18),
        if (tasks.isEmpty)
          const _EmptyCleaningState(
            icon: Icons.event_available_outlined,
            title: 'Nothing scheduled',
            message: 'This day has no active cleaning tasks.',
          )
        else
          for (final time in CleaningTime.values)
            if (tasks.any((task) => task.time == time))
              _CleaningTimeSection(
                time: time,
                tasks: tasks.where((task) => task.time == time).toList(),
                date: _selectedDate,
                today: _today,
                eventFor: _eventFor,
                onStatusChanged: _setTaskStatus,
              ),
      ],
    );
  }

  Widget _buildPlan() {
    final tasks =
        _data.tasks.where((task) => task.frequency == _planFrequency).toList()
          ..sort((a, b) {
            final byActive = a.isActive == b.isActive
                ? 0
                : (a.isActive ? -1 : 1);
            return byActive != 0 ? byActive : a.label.compareTo(b.label);
          });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _SectionHeading(
          eyebrow:
              '${_data.tasks.where((task) => task.isActive).length} active',
          title: 'Your house plan',
          subtitle:
              'Short daily resets, rotated weekly work, and deep-clean jobs.',
          trailing: IconButton.filled(
            onPressed: _addTask,
            tooltip: 'Add task',
            icon: const Icon(Icons.add_rounded),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<CleaningFrequency>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: CleaningFrequency.daily, label: Text('Daily')),
            ButtonSegment(
              value: CleaningFrequency.weekly,
              label: Text('Weekly'),
            ),
            ButtonSegment(
              value: CleaningFrequency.monthly,
              label: Text('Monthly'),
            ),
          ],
          selected: {_planFrequency},
          onSelectionChanged: (selection) {
            setState(() => _planFrequency = selection.first);
          },
        ),
        const SizedBox(height: 14),
        for (final task in tasks)
          _PlanTaskCard(
            task: task,
            onToggle: () => _toggleTaskActive(task),
            onDelete: task.custom ? () => _deleteTask(task) : null,
          ),
      ],
    );
  }

  Widget _buildInsights() {
    final insights = buildCleaningInsights(
      _data,
      today: _today,
      dayCount: _insightDays,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _SectionHeading(
          eyebrow: 'Your patterns',
          title: 'Cleaning insights',
          subtitle: 'See what gets done, what slips, and when you do it.',
          trailing: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7d')),
              ButtonSegment(value: 30, label: Text('30d')),
            ],
            selected: {_insightDays},
            onSelectionChanged: (selection) {
              setState(() => _insightDays = selection.first);
            },
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.check_circle_outline,
                    color: _cleaningGreen,
                    label: 'Completion',
                    value: '${(insights.completionRate * 100).round()}%',
                    detail: '${insights.completed} finished',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.event_busy_outlined,
                    color: _cleaningCoral,
                    label: 'Missed',
                    value: '${insights.missed}',
                    detail: '${insights.skipped} skipped',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.local_fire_department_outlined,
                    color: _cleaningAmber,
                    label: 'Streak',
                    value: '${insights.currentStreak}d',
                    detail: '70%+ each day',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.schedule_outlined,
                    color: _cleaningBlue,
                    label: 'Usual finish',
                    value: _completionTime(insights.averageCompletionHour),
                    detail: '${insights.completedLate} logged late',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _DailyChart(days: insights.days),
        const SizedBox(height: 12),
        _AreaPerformance(areas: insights.areas),
        const SizedBox(height: 12),
        _MostMissedTasks(items: insights.mostMissed),
        const SizedBox(height: 12),
        _CleaningRecommendation(insights: insights),
      ],
    );
  }
}

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({
    required this.date,
    required this.today,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime date;
  final DateTime today;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous day',
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                isToday ? 'TODAY' : _weekdayName(date.weekday).toUpperCase(),
                style: const TextStyle(
                  color: _cleaningGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day} ${_monthName(date.month)} ${date.year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (!isToday)
          TextButton(onPressed: onToday, child: const Text('Today'))
        else
          IconButton.filledTonal(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next day',
          ),
      ],
    );
  }
}

class _CleaningHero extends StatelessWidget {
  const _CleaningHero({
    required this.completed,
    required this.total,
    required this.minutesLeft,
    required this.isToday,
  });

  final int completed;
  final int total;
  final int minutesLeft;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF13241E), Color(0xFF14253A)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cleaningGreen.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0xFF34405F),
                  color: _cleaningGreen,
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total > 0 && completed == total
                      ? 'House reset complete'
                      : '$completed of $total done',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  minutesLeft == 0
                      ? 'Everything scheduled is handled.'
                      : isToday
                      ? 'About $minutesLeft minutes left today'
                      : '$minutesLeft minutes were left incomplete',
                  style: const TextStyle(
                    color: Color(0xFFD8E2FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CleaningTimeSection extends StatelessWidget {
  const _CleaningTimeSection({
    required this.time,
    required this.tasks,
    required this.date,
    required this.today,
    required this.eventFor,
    required this.onStatusChanged,
  });

  final CleaningTime time;
  final List<CleaningTask> tasks;
  final DateTime date;
  final DateTime today;
  final CleaningEvent? Function(CleaningTask task, DateTime date) eventFor;
  final Future<void> Function(
    CleaningTask task,
    DateTime date,
    CleaningEventStatus? status,
  )
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_timeIcon(time), size: 19, color: _cleaningBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _timeLabel(time),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${tasks.fold(0, (total, task) => total + task.minutes)} min',
                style: const TextStyle(
                  color: _cleaningMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final task in tasks)
            _TodayTaskCard(
              task: task,
              event: eventFor(task, date),
              missed: date.isBefore(today) && eventFor(task, date) == null,
              onTap: () {
                final event = eventFor(task, date);
                onStatusChanged(
                  task,
                  date,
                  event?.status == CleaningEventStatus.completed
                      ? null
                      : CleaningEventStatus.completed,
                );
              },
              onAction: (action) {
                final status = switch (action) {
                  _TaskAction.complete => CleaningEventStatus.completed,
                  _TaskAction.skip => CleaningEventStatus.skipped,
                  _TaskAction.reset => null,
                };
                onStatusChanged(task, date, status);
              },
            ),
        ],
      ),
    );
  }
}

class _TodayTaskCard extends StatelessWidget {
  const _TodayTaskCard({
    required this.task,
    required this.event,
    required this.missed,
    required this.onTap,
    required this.onAction,
  });

  final CleaningTask task;
  final CleaningEvent? event;
  final bool missed;
  final VoidCallback onTap;
  final ValueChanged<_TaskAction> onAction;

  @override
  Widget build(BuildContext context) {
    final completed = event?.status == CleaningEventStatus.completed;
    final skipped = event?.status == CleaningEventStatus.skipped;
    final color = completed
        ? _cleaningGreen
        : skipped
        ? _cleaningAmber
        : missed
        ? _cleaningCoral
        : _cleaningBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
      decoration: BoxDecoration(
        color: completed
            ? _cleaningGreen.withValues(alpha: 0.09)
            : _cleaningPanel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? _cleaningGreen : _cleaningPanel2,
              ),
              child: Icon(
                completed ? Icons.check_rounded : _areaIcon(task.area),
                color: completed ? const Color(0xFF07140D) : color,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.label,
                  style: TextStyle(
                    color: skipped ? _cleaningMuted : Colors.white,
                    fontWeight: FontWeight.w800,
                    decoration: skipped ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _taskDetail(task, event, missed),
                  style: TextStyle(
                    color: missed ? _cleaningCoral : _cleaningMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<_TaskAction>(
            tooltip: 'Task options',
            onSelected: onAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _TaskAction.complete,
                child: Text('Mark complete'),
              ),
              PopupMenuItem(
                value: _TaskAction.skip,
                child: Text('Skip this time'),
              ),
              PopupMenuItem(
                value: _TaskAction.reset,
                child: Text('Clear status'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: _cleaningGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _cleaningMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class _PlanTaskCard extends StatelessWidget {
  const _PlanTaskCard({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final CleaningTask task;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _areaColor(task.area).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _areaIcon(task.area),
                color: _areaColor(task.area),
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.label,
                    style: TextStyle(
                      color: task.isActive ? Colors.white : _cleaningMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${task.area} · ${task.minutes} min · '
                    '${_taskSchedule(task)}',
                    style: const TextStyle(
                      color: _cleaningMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete custom task',
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            Switch(value: task.isActive, onChanged: (_) => onToggle()),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cleaningPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cleaningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _cleaningMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _cleaningMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.days});

  final List<CleaningDaySummary> days;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Day-by-day',
      subtitle: 'Completed compared with everything scheduled.',
      child: SizedBox(
        height: 150,
        child: SingleChildScrollView(
          reverse: true,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                SizedBox(
                  width: 42,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${(day.rate * 100).round()}%',
                        style: const TextStyle(
                          color: _cleaningMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 22,
                        height: 105,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: _cleaningPanel2,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Container(
                          width: 22,
                          height: day.due == 0 ? 3 : 105 * day.rate,
                          decoration: BoxDecoration(
                            color: day.rate >= 0.7
                                ? _cleaningGreen
                                : _cleaningCoral,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${day.date.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaPerformance extends StatelessWidget {
  const _AreaPerformance({required this.areas});

  final List<CleaningAreaSummary> areas;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Areas of the house',
      subtitle: 'Which spaces are staying under control.',
      child: Column(
        children: [
          for (final area in areas) ...[
            Row(
              children: [
                Icon(
                  _areaIcon(area.area),
                  size: 18,
                  color: _areaColor(area.area),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    area.area,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${(area.rate * 100).round()}%',
                  style: const TextStyle(
                    color: _cleaningMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: area.rate,
                color: area.rate >= 0.7 ? _cleaningGreen : _cleaningAmber,
                backgroundColor: _cleaningPanel2,
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _MostMissedTasks extends StatelessWidget {
  const _MostMissedTasks({required this.items});

  final List<CleaningMissSummary> items;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Most often missed',
      subtitle: 'Use this to simplify or reschedule difficult tasks.',
      child: items.isEmpty
          ? const Text(
              'No missed tasks in this period.',
              style: TextStyle(color: _cleaningMuted),
            )
          : Column(
              children: [
                for (final item in items.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _cleaningCoral.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _areaIcon(item.task.area),
                            color: _cleaningCoral,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.task.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${item.missed}×',
                          style: const TextStyle(
                            color: _cleaningCoral,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CleaningRecommendation extends StatelessWidget {
  const _CleaningRecommendation({required this.insights});

  final CleaningInsights insights;

  @override
  Widget build(BuildContext context) {
    final text = switch (insights.completionRate) {
      >= 0.8 =>
        'Your routine is holding well. Keep the dish rounds short so the sink '
            'never becomes one large job.',
      >= 0.5 =>
        'The plan is partly working. Switch off one low-priority daily task '
            'or move a difficult job to a better day.',
      _ =>
        'Focus first on dishes, kitchen surfaces, laundry containment, and '
            'one floor reset. The rest can rotate weekly.',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cleaningGreen.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cleaningGreen.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: _cleaningGreen),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: _cleaningMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyCleaningState extends StatelessWidget {
  const _EmptyCleaningState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cleaningPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cleaningBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: _cleaningGreen),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _cleaningMuted),
          ),
        ],
      ),
    );
  }
}

class _CleaningTaskDialog extends StatefulWidget {
  const _CleaningTaskDialog();

  @override
  State<_CleaningTaskDialog> createState() => _CleaningTaskDialogState();
}

class _CleaningTaskDialogState extends State<_CleaningTaskDialog> {
  final _labelController = TextEditingController();
  var _area = 'Kitchen';
  var _minutes = 10.0;
  var _frequency = CleaningFrequency.daily;
  var _time = CleaningTime.anytime;
  var _weekday = DateTime.now().weekday;
  var _monthDay = DateTime.now().day;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add cleaning task'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Task'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _area,
                decoration: const InputDecoration(labelText: 'Area'),
                items:
                    const [
                      'Kitchen',
                      'Bathroom',
                      'Bedroom',
                      'Living room',
                      'Laundry',
                      'Floors',
                      'Whole house',
                    ].map((area) {
                      return DropdownMenuItem(value: area, child: Text(area));
                    }).toList(),
                onChanged: (value) => setState(() => _area = value ?? _area),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CleaningFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: CleaningFrequency.values.map((frequency) {
                  return DropdownMenuItem(
                    value: frequency,
                    child: Text(_frequencyLabel(frequency)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _frequency = value ?? _frequency);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CleaningTime>(
                initialValue: _time,
                decoration: const InputDecoration(labelText: 'Best time'),
                items: CleaningTime.values.map((time) {
                  return DropdownMenuItem(
                    value: time,
                    child: Text(_timeLabel(time)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _time = value ?? _time),
              ),
              if (_frequency == CleaningFrequency.weekly) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _weekday,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: [
                    for (var day = 1; day <= 7; day++)
                      DropdownMenuItem(
                        value: day,
                        child: Text(_weekdayName(day)),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _weekday = value ?? _weekday);
                  },
                ),
              ],
              if (_frequency == CleaningFrequency.monthly) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _monthDay,
                  decoration: const InputDecoration(labelText: 'Day of month'),
                  items: [
                    for (var day = 1; day <= 28; day++)
                      DropdownMenuItem(value: day, child: Text('$day')),
                  ],
                  onChanged: (value) {
                    setState(() => _monthDay = value ?? _monthDay);
                  },
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${_minutes.round()} minutes'),
              ),
              Slider(
                min: 5,
                max: 60,
                divisions: 11,
                value: _minutes,
                onChanged: (value) => setState(() => _minutes = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add task')),
      ],
    );
  }

  void _submit() {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;
    final now = DateTime.now();
    Navigator.pop(
      context,
      CleaningTask(
        id: 'custom-${now.microsecondsSinceEpoch}',
        label: label,
        area: _area,
        minutes: _minutes.round(),
        frequency: _frequency,
        time: _time,
        weekdays: _frequency == CleaningFrequency.weekly
            ? [_weekday]
            : const [],
        monthDay: _frequency == CleaningFrequency.monthly ? _monthDay : null,
        custom: true,
      ),
    );
  }
}

String _taskDetail(CleaningTask task, CleaningEvent? event, bool missed) {
  final base =
      '${task.area} · ${task.minutes} min${task.essential ? ' · essential' : ''}';
  if (event?.status == CleaningEventStatus.skipped) return '$base · skipped';
  if (event?.status == CleaningEventStatus.completed) {
    final time =
        '${event!.recordedAt.hour.toString().padLeft(2, '0')}:'
        '${event.recordedAt.minute.toString().padLeft(2, '0')}';
    return '$base · done $time${event.completedLate ? ' late' : ''}';
  }
  return missed ? '$base · missed' : base;
}

String _taskSchedule(CleaningTask task) {
  return switch (task.frequency) {
    CleaningFrequency.daily => _timeLabel(task.time),
    CleaningFrequency.weekly => task.weekdays.map(_weekdayName).join(', '),
    CleaningFrequency.monthly => 'day ${task.monthDay ?? 1}',
  };
}

String _completionTime(double? hour) {
  if (hour == null) return '--';
  final wholeHour = hour.floor();
  final minute = ((hour - wholeHour) * 60).round();
  final suffix = wholeHour >= 12 ? 'pm' : 'am';
  final displayHour = wholeHour % 12 == 0 ? 12 : wholeHour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')}$suffix';
}

String _frequencyLabel(CleaningFrequency frequency) {
  return switch (frequency) {
    CleaningFrequency.daily => 'Daily',
    CleaningFrequency.weekly => 'Weekly',
    CleaningFrequency.monthly => 'Monthly',
  };
}

String _timeLabel(CleaningTime time) {
  return switch (time) {
    CleaningTime.morning => 'Morning reset',
    CleaningTime.daytime => 'Daytime upkeep',
    CleaningTime.evening => 'Evening close-down',
    CleaningTime.anytime => 'Anytime',
  };
}

IconData _timeIcon(CleaningTime time) {
  return switch (time) {
    CleaningTime.morning => Icons.wb_sunny_outlined,
    CleaningTime.daytime => Icons.light_mode_outlined,
    CleaningTime.evening => Icons.nights_stay_outlined,
    CleaningTime.anytime => Icons.schedule_outlined,
  };
}

IconData _areaIcon(String area) {
  return switch (area) {
    'Kitchen' => Icons.soup_kitchen_outlined,
    'Bathroom' => Icons.bathroom_outlined,
    'Bedroom' => Icons.bed_outlined,
    'Living room' => Icons.weekend_outlined,
    'Laundry' => Icons.local_laundry_service_outlined,
    'Floors' => Icons.cleaning_services_outlined,
    _ => Icons.home_outlined,
  };
}

Color _areaColor(String area) {
  return switch (area) {
    'Kitchen' => _cleaningCoral,
    'Bathroom' => _cleaningBlue,
    'Bedroom' => _cleaningGreen,
    'Living room' => _cleaningAmber,
    'Laundry' => const Color(0xFFB184F5),
    'Floors' => const Color(0xFF55C7D9),
    _ => _cleaningMuted,
  };
}

String _weekdayName(int weekday) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[weekday - 1];
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
