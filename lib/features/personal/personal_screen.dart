import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/personal_log_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';

class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  bool syncingDrive = false;
  bool openingDrive = false;
  String? message;
  bool messageIsError = false;

  Future<void> _syncDrive() async {
    setState(() {
      syncingDrive = true;
      message = null;
      messageIsError = false;
    });

    try {
      await context.read<AppState>().syncPersonalLogsToDrive();

      if (!mounted) return;

      setState(() {
        message = 'Personal notes synced to Google Drive.';
        messageIsError = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not sync personal notes: $error';
        messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => syncingDrive = false);
      }
    }
  }

  Future<void> _openDriveFolder({
    required Future<String> Function(AppState appState) folderId,
    required String label,
  }) async {
    setState(() {
      openingDrive = true;
      message = null;
      messageIsError = false;
    });

    try {
      final id = await folderId(context.read<AppState>());
      final uri = Uri.parse(
        'https://drive.google.com/drive/folders/${Uri.encodeComponent(id)}',
      );
      await launchUrl(uri, webOnlyWindowName: '_blank');

      if (!mounted) return;

      setState(() {
        message = 'Opened $label.';
        messageIsError = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Could not open $label: $error';
        messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => openingDrive = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = appState.personalLogEntries;
    final gymEntries = entries
        .where((entry) => entry.category == PersonalLogCategory.gym)
        .toList();
    final bodyWeightEntries = entries
        .where((entry) => entry.category == PersonalLogCategory.bodyWeight)
        .toList();
    final goalEntries = entries
        .where((entry) => entry.category == PersonalLogCategory.goal)
        .toList();
    final latestBodyWeightKg = _latestBodyWeightKg(entries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          title: 'Personal Mode',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricPill(
                    label: 'Gym notes',
                    value: '${gymEntries.length}',
                  ),
                  _MetricPill(
                    label: 'Body weight',
                    value: '${_formatWeightKg(latestBodyWeightKg)} kg',
                  ),
                  _MetricPill(label: 'Goals', value: '${goalEntries.length}'),
                  _MetricPill(label: 'Total logs', value: '${entries.length}'),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _showPersonalLogSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Personal Log'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: entries.isEmpty || syncingDrive ? null : _syncDrive,
                icon: syncingDrive
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_to_drive_outlined),
                label: Text(
                  syncingDrive
                      ? 'Syncing Personal Notes'
                      : 'Sync Personal Notes to Drive',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: openingDrive
                          ? null
                          : () => _openDriveFolder(
                              label: 'Personal Notes',
                              folderId: (appState) =>
                                  appState.ensurePersonalNotesDriveFolderId(),
                            ),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Open Notes'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: openingDrive
                          ? null
                          : () => _openDriveFolder(
                              label: 'Gym Folder',
                              folderId: (appState) =>
                                  appState.ensurePersonalCategoryDriveFolderId(
                                    PersonalLogCategory.gym,
                                  ),
                            ),
                      icon: const Icon(Icons.fitness_center_rounded),
                      label: const Text('Open Gym'),
                    ),
                  ),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message!,
                  style: TextStyle(
                    color: messageIsError
                        ? const Color(0xFFFF5C5C)
                        : const Color(0xFF31E981),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Body Weight Tracker',
          child: _BodyWeightTracker(entries: bodyWeightEntries),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Workout Week',
          child: Column(
            children: [
              for (final split in _workoutSplits)
                _WorkoutSplitCard(split: split, gymEntries: gymEntries),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Gym Progress Analytics',
          child: _GymProgressAnalytics(
            entries: gymEntries,
            bodyWeightEntries: bodyWeightEntries,
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Recent Gym Progress',
          child: gymEntries.isEmpty
              ? const EmptyState(message: 'No gym progress logged yet.')
              : Column(
                  children: [
                    for (final entry in gymEntries.take(5))
                      _PersonalLogTile(entry: entry),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Personal Notes',
          child: entries.isEmpty
              ? const EmptyState(message: 'No personal notes yet.')
              : _PersonalLogFolders(
                  entries: entries,
                  onDelete: (entry) =>
                      context.read<AppState>().deletePersonalLogEntry(entry),
                ),
        ),
      ],
    );
  }
}

class _WorkoutSplitCard extends StatelessWidget {
  const _WorkoutSplitCard({required this.split, required this.gymEntries});

  final _WorkoutSplit split;
  final List<PersonalLogEntry> gymEntries;

  @override
  Widget build(BuildContext context) {
    final completed = split.exercises
        .where((exercise) => _latestLogFor(exercise.name) != null)
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF20283B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF34405F)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: Icon(split.icon, color: const Color(0xFF4F8DF7)),
            title: Text(
              split.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              '$completed/${split.exercises.length} logged this plan',
              style: const TextStyle(
                color: Color(0xFF8396C7),
                fontWeight: FontWeight.w700,
              ),
            ),
            children: [
              if (split.focus.isNotEmpty) ...[
                _FocusNote(text: split.focus),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      _showGuidedWorkoutSheet(context, split: split),
                  icon: const Icon(Icons.directions_run_rounded),
                  label: const Text('Start Flexible Workout'),
                ),
              ),
              const SizedBox(height: 10),
              for (final exercise in split.exercises)
                _WorkoutExerciseRow(
                  split: split,
                  exercise: exercise,
                  latestLog: _latestLogFor(exercise.name),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PersonalLogEntry? _latestLogFor(String exerciseName) {
    for (final entry in gymEntries) {
      if (entry.title.toLowerCase().contains(exerciseName.toLowerCase())) {
        return entry;
      }
    }

    return null;
  }
}

class _FocusNote extends StatelessWidget {
  const _FocusNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13294D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD8E2FF),
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class _WorkoutExerciseRow extends StatelessWidget {
  const _WorkoutExerciseRow({
    required this.split,
    required this.exercise,
    required this.latestLog,
  });

  final _WorkoutSplit split;
  final _WorkoutExercise exercise;
  final PersonalLogEntry? latestLog;

  @override
  Widget build(BuildContext context) {
    final lastMetric = latestLog == null ? '' : _displayMetric(latestLog!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF151B29),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF34405F)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (exercise.target.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      exercise.target,
                      style: const TextStyle(
                        color: Color(0xFF8396C7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (lastMetric.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Last: $lastMetric',
                      style: const TextStyle(
                        color: Color(0xFF31E981),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Log exercise',
              onPressed: () => _showExerciseLogSheet(
                context,
                split: split,
                exercise: exercise,
                latestLog: latestLog,
              ),
              icon: const Icon(Icons.add_task_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF31E981),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyWeightTracker extends StatefulWidget {
  const _BodyWeightTracker({required this.entries});

  final List<PersonalLogEntry> entries;

  @override
  State<_BodyWeightTracker> createState() => _BodyWeightTrackerState();
}

class _BodyWeightTrackerState extends State<_BodyWeightTracker> {
  late double weightKg;

  @override
  void initState() {
    super.initState();
    weightKg = _latestBodyWeightKg(widget.entries);
  }

  @override
  void didUpdateWidget(covariant _BodyWeightTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.entries != widget.entries) {
      weightKg = _latestBodyWeightKg(widget.entries);
    }
  }

  void _save() {
    context.read<AppState>().addPersonalLogEntry(
      PersonalLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: PersonalLogCategory.bodyWeight,
        date: DateTime.now(),
        title: 'Body weight',
        metric: '${_formatWeightKg(weightKg)} kg',
        notes: 'Height: 6 ft 3 in',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = _BodyWeightPoint.fromEntries(widget.entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeightStepper(
          label: 'Body weight',
          value: weightKg,
          smallStep: 0.1,
          largeStep: 1,
          onChanged: (value) {
            setState(() => weightKg = value);
          },
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.monitor_weight_rounded),
          label: const Text('Save Today'),
        ),
        const SizedBox(height: 12),
        _BodyWeightChart(points: points),
      ],
    );
  }
}

class _BodyWeightChart extends StatelessWidget {
  const _BodyWeightChart({required this.points});

  final List<_BodyWeightPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const EmptyState(message: 'No body weight check-ins yet.');
    }

    final spots = [
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), points[index].weightKg),
    ];
    final minWeight = points.fold<double>(
      points.first.weightKg,
      (min, point) => point.weightKg < min ? point.weightKg : min,
    );
    final maxWeight = points.fold<double>(
      points.first.weightKg,
      (max, point) => point.weightKg > max ? point.weightKg : max,
    );
    final minY = (minWeight - 2).clamp(0, 500).toDouble();
    final maxY = maxWeight + 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Weight trend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_formatWeightKg(points.last.weightKg)} kg',
                style: const TextStyle(
                  color: Color(0xFF31E981),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) {
                    return const FlLine(
                      color: Color(0xFF27324B),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: points.length > 6 ? 2 : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();

                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }

                        final date = points[index].date;

                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(
                              color: Color(0xFF8396C7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 4,
                    color: const Color(0xFF4F8DF7),
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0x224F8DF7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GymProgressAnalytics extends StatefulWidget {
  const _GymProgressAnalytics({
    required this.entries,
    required this.bodyWeightEntries,
  });

  final List<PersonalLogEntry> entries;
  final List<PersonalLogEntry> bodyWeightEntries;

  @override
  State<_GymProgressAnalytics> createState() => _GymProgressAnalyticsState();
}

class _GymProgressAnalyticsState extends State<_GymProgressAnalytics> {
  String selectedExercise = _allExercisesLabel;
  _GymChartMetric selectedMetric = _GymChartMetric.estimatedMax;

  @override
  Widget build(BuildContext context) {
    final bodyWeightKg = _latestBodyWeightKg(widget.bodyWeightEntries);
    final logs =
        widget.entries
            .map((entry) => _GymProgressLog.fromEntry(entry))
            .whereType<_GymProgressLog>()
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final exerciseNames = logs.map((log) => log.exerciseName).toSet().toList()
      ..sort();
    final options = [_allExercisesLabel, ...exerciseNames];

    if (!options.contains(selectedExercise)) {
      selectedExercise = _allExercisesLabel;
    }

    final filtered = selectedExercise == _allExercisesLabel
        ? logs
        : logs.where((log) => log.exerciseName == selectedExercise).toList();
    final points = _GymProgressPoint.fromLogs(filtered);
    final totals = _GymProgressTotals.fromLogs(filtered);

    if (logs.isEmpty) {
      return const EmptyState(
        message: 'Log a workout to start building your progress graph.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedExercise,
          dropdownColor: const Color(0xFF20283B),
          decoration: const InputDecoration(
            labelText: 'Exercise',
            prefixIcon: Icon(Icons.fitness_center_rounded),
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => selectedExercise = value);
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<_GymChartMetric>(
          segments: const [
            ButtonSegment(
              value: _GymChartMetric.estimatedMax,
              icon: Icon(Icons.stacked_line_chart_rounded),
              label: Text('Est max'),
            ),
            ButtonSegment(
              value: _GymChartMetric.bestWeight,
              icon: Icon(Icons.scale_rounded),
              label: Text('Weight'),
            ),
            ButtonSegment(
              value: _GymChartMetric.sets,
              icon: Icon(Icons.format_list_numbered_rounded),
              label: Text('Sets'),
            ),
            ButtonSegment(
              value: _GymChartMetric.reps,
              icon: Icon(Icons.repeat_rounded),
              label: Text('Reps'),
            ),
          ],
          selected: {selectedMetric},
          onSelectionChanged: (values) {
            setState(() => selectedMetric = values.first);
          },
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricPill(
              label: 'Est max',
              value: '${_formatCompactNumber(totals.bestEstimatedMaxKg)} kg',
            ),
            _MetricPill(
              label: 'Best kg',
              value: _formatCompactNumber(totals.bestWeightKg),
            ),
            _MetricPill(
              label: 'Avg reps/set',
              value: _formatCompactNumber(totals.averageRepsPerSet),
            ),
            _MetricPill(label: 'Sessions', value: '${totals.sessions}'),
          ],
        ),
        const SizedBox(height: 14),
        _PersonalRecordBoard(logs: filtered),
        const SizedBox(height: 14),
        _CaloriesBurnedPanel(logs: filtered, bodyWeightKg: bodyWeightKg),
        const SizedBox(height: 14),
        _GymVisualSummary(points: points, totals: totals),
        const SizedBox(height: 14),
        _TrainingHeatmap(logs: filtered),
        const SizedBox(height: 14),
        _SetRepProfile(totals: totals),
        const SizedBox(height: 14),
        _GymProgressChart(points: points, metric: selectedMetric),
        const SizedBox(height: 12),
        _WeeklySessionBars(logs: filtered),
        const SizedBox(height: 12),
        _ExerciseBestWeightBars(logs: filtered),
        const SizedBox(height: 12),
        _ExerciseHistoryTable(logs: filtered),
        const SizedBox(height: 12),
        _ProgressInsight(logs: filtered, totals: totals),
      ],
    );
  }
}

class _GymVisualSummary extends StatelessWidget {
  const _GymVisualSummary({required this.points, required this.totals});

  final List<_GymProgressPoint> points;
  final _GymProgressTotals totals;

  @override
  Widget build(BuildContext context) {
    final latest = points.isEmpty ? null : points.last;
    final latestEstimatedMax = latest?.bestEstimatedMaxKg ?? 0;
    final maxEstimatedMax = points.fold<double>(
      0,
      (max, point) =>
          point.bestEstimatedMaxKg > max ? point.bestEstimatedMaxKg : max,
    );
    final estimatedMaxProgress = maxEstimatedMax <= 0
        ? 0.0
        : latestEstimatedMax / maxEstimatedMax;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        _VisualMetricCard(
          icon: Icons.bolt_rounded,
          label: 'Latest est max',
          value: '${_formatCompactNumber(latestEstimatedMax)} kg',
          color: const Color(0xFF31E981),
          progress: estimatedMaxProgress,
        ),
        _VisualMetricCard(
          icon: Icons.scale_rounded,
          label: 'Best weight',
          value: '${_formatCompactNumber(totals.bestWeightKg)} kg',
          color: const Color(0xFF4F8DF7),
          progress: totals.bestWeightKg <= 0 ? 0 : 1,
        ),
        _VisualMetricCard(
          icon: Icons.format_list_numbered_rounded,
          label: 'Avg reps/set',
          value: _formatCompactNumber(totals.averageRepsPerSet),
          color: const Color(0xFFF59E0B),
          progress: (totals.averageRepsPerSet / 12).clamp(0.0, 1.0),
        ),
        _VisualMetricCard(
          icon: Icons.repeat_rounded,
          label: 'Sessions',
          value: '${totals.sessions}',
          color: const Color(0xFFE879F9),
          progress: totals.sessions <= 0 ? 0 : 1,
        ),
      ],
    );
  }
}

class _PersonalRecordBoard extends StatelessWidget {
  const _PersonalRecordBoard({required this.logs});

  final List<_GymProgressLog> logs;

  @override
  Widget build(BuildContext context) {
    final records = _ExerciseRecord.fromLogs(logs);

    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Personal records',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.22,
            children: [
              for (final record in records.take(4)) _RecordCard(record: record),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaloriesBurnedPanel extends StatelessWidget {
  const _CaloriesBurnedPanel({required this.logs, required this.bodyWeightKg});

  final List<_GymProgressLog> logs;
  final double bodyWeightKg;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    final points = _CaloriesByDate.fromLogs(logs);
    final totalCalories = points.fold<int>(
      0,
      (total, point) => total + point.calories,
    );
    final latestCalories = points.isEmpty ? 0 : points.last.calories;
    final maxCalories = points.fold<int>(
      0,
      (max, point) => point.calories > max ? point.calories : max,
    );
    final safeMaxY = maxCalories <= 0 ? 1.0 : maxCalories * 1.2;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF5C5C),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Calories burned estimate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$latestCalories kcal',
                style: const TextStyle(
                  color: Color(0xFFFF5C5C),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Uses ${_formatWeightKg(bodyWeightKg)} kg body weight. Total logged: $totalCalories kcal.',
            style: const TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: safeMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) {
                    return const FlLine(
                      color: Color(0xFF27324B),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();

                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }

                        final date = points[index].date;

                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(
                              color: Color(0xFF8396C7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var index = 0; index < points.length; index++)
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: points[index].calories.toDouble(),
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFFFF5C5C),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final _ExerciseRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3F4D70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x3331E981),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'PR',
                  style: TextStyle(
                    color: Color(0xFF31E981),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                formatDate(record.date),
                style: const TextStyle(
                  color: Color(0xFF8396C7),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            record.exerciseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const Spacer(),
          Text(
            '${_formatCompactNumber(record.estimatedMaxKg)} kg',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF31E981),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'best ${_formatCompactNumber(record.bestWeightKg)} kg',
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingHeatmap extends StatelessWidget {
  const _TrainingHeatmap({required this.logs});

  final List<_GymProgressLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    final counts = <DateTime, int>{};

    for (final log in logs) {
      final date = DateTime(log.date.year, log.date.month, log.date.day);
      counts.update(date, (value) => value + 1, ifAbsent: () => 1);
    }

    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 27));
    final days = [
      for (var index = 0; index < 28; index++) start.add(Duration(days: index)),
    ];
    final streak = _currentTrainingStreak(counts.keys);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF4F8DF7),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Training heatmap',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$streak day streak',
                style: const TextStyle(
                  color: Color(0xFF31E981),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            children: [
              for (final day in days)
                _HeatmapDay(count: counts[day] ?? 0, day: day),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatmapDay extends StatelessWidget {
  const _HeatmapDay({required this.count, required this.day});

  final int count;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final color = switch (count) {
      0 => const Color(0xFF20283B),
      1 => const Color(0xFF174B36),
      2 => const Color(0xFF217A45),
      _ => const Color(0xFF31E981),
    };

    return Tooltip(
      message:
          '${formatDate(day)}: $count logged exercise${count == 1 ? '' : 's'}',
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFF34405F)),
        ),
        alignment: Alignment.center,
        child: Text(
          day.day.toString(),
          style: TextStyle(
            color: count == 0 ? const Color(0xFF8396C7) : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SetRepProfile extends StatelessWidget {
  const _SetRepProfile({required this.totals});

  final _GymProgressTotals totals;

  @override
  Widget build(BuildContext context) {
    if (totals.sessions == 0) {
      return const SizedBox.shrink();
    }

    final avgSets = totals.averageSetsPerSession;
    final loadedRatio = totals.loadedSessionRatio;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Set and rep profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _ProfileBar(
            label: 'Sets per exercise',
            value: avgSets,
            maxValue: 6,
            color: const Color(0xFFF59E0B),
            suffix: '',
          ),
          const SizedBox(height: 10),
          _ProfileBar(
            label: 'Reps per set',
            value: totals.averageRepsPerSet,
            maxValue: 20,
            color: const Color(0xFFE879F9),
            suffix: '',
          ),
          const SizedBox(height: 10),
          _ProfileBar(
            label: 'Loaded exercises',
            value: loadedRatio * 100,
            maxValue: 100,
            color: const Color(0xFF31E981),
            suffix: '%',
          ),
        ],
      ),
    );
  }
}

class _ProfileBar extends StatelessWidget {
  const _ProfileBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.suffix,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD8E2FF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${_formatCompactNumber(value)}$suffix',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (value / maxValue).clamp(0.0, 1.0),
            minHeight: 11,
            backgroundColor: const Color(0xFF20283B),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _VisualMetricCard extends StatelessWidget {
  const _VisualMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8396C7),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFF20283B),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GymProgressChart extends StatelessWidget {
  const _GymProgressChart({required this.points, required this.metric});

  final List<_GymProgressPoint> points;
  final _GymChartMetric metric;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const EmptyState(message: 'No numeric workout data to graph yet.');
    }

    final spots = [
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), metric.valueFor(points[index])),
    ];
    final maxValue = spots.fold<double>(
      0,
      (max, spot) => spot.y > max ? spot.y : max,
    );
    final safeMaxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            metric.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: safeMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) {
                    return const FlLine(
                      color: Color(0xFF27324B),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0 || value == safeMaxY) {
                          return const SizedBox.shrink();
                        }

                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _formatCompactNumber(value),
                            style: const TextStyle(
                              color: Color(0xFF8396C7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: points.length > 6 ? 2 : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();

                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }

                        final date = points[index].date;

                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(
                              color: Color(0xFF8396C7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 4,
                    color: const Color(0xFF31E981),
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0x3331E981),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return [
                        for (final spot in touchedSpots)
                          LineTooltipItem(
                            '${formatDate(points[spot.x.toInt()].date)}\n'
                            '${metric.shortLabel}: '
                            '${_formatCompactNumber(spot.y)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ];
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressInsight extends StatelessWidget {
  const _ProgressInsight({required this.logs, required this.totals});

  final List<_GymProgressLog> logs;
  final _GymProgressTotals totals;

  @override
  Widget build(BuildContext context) {
    final first = logs.isEmpty ? null : logs.first;
    final latest = logs.isEmpty ? null : logs.last;
    final firstEstimatedMax = first?.bestEstimatedMaxKg ?? 0;
    final latestEstimatedMax = latest?.bestEstimatedMaxKg ?? 0;
    final change = latestEstimatedMax - firstEstimatedMax;
    final changeText = change == 0
        ? 'No estimated strength change yet'
        : '${change > 0 ? '+' : ''}${_formatCompactNumber(change)} kg estimated max';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13294D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress readout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            logs.length == 1
                ? 'One logged workout. Keep logging each session to build a trend.'
                : '$changeText from first to latest logged session.',
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          if (totals.bestWeightKg > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Best load: ${_formatCompactNumber(totals.bestWeightKg)} kg. Average reps per set: ${_formatCompactNumber(totals.averageRepsPerSet)}.',
              style: const TextStyle(
                color: Color(0xFFD8E2FF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklySessionBars extends StatelessWidget {
  const _WeeklySessionBars({required this.logs});

  final List<_GymProgressLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    final counts = <DateTime, int>{};

    for (final log in logs) {
      final week = _weekStart(log.date);
      counts.update(week, (value) => value + 1, ifAbsent: () => 1);
    }

    final weeks = counts.keys.toList()..sort();
    final visible = weeks.length > 8 ? weeks.sublist(weeks.length - 8) : weeks;
    final maxCount = visible.fold<int>(
      0,
      (max, week) => counts[week]! > max ? counts[week]! : max,
    );
    final safeMaxY = maxCount <= 0 ? 1.0 : maxCount + 1.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Weekly consistency',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: safeMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) {
                    return const FlLine(
                      color: Color(0xFF27324B),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();

                        if (index < 0 || index >= visible.length) {
                          return const SizedBox.shrink();
                        }

                        final date = visible[index];

                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(
                              color: Color(0xFF8396C7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var index = 0; index < visible.length; index++)
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: counts[visible[index]]!.toDouble(),
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF4F8DF7),
                        ),
                      ],
                    ),
                ],
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final week = visible[group.x.toInt()];

                      return BarTooltipItem(
                        'Week of ${formatDate(week)}\n'
                        '${counts[week]} sessions',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseBestWeightBars extends StatelessWidget {
  const _ExerciseBestWeightBars({required this.logs});

  final List<_GymProgressLog> logs;

  @override
  Widget build(BuildContext context) {
    final bests = <String, double>{};

    for (final log in logs) {
      bests.update(
        log.exerciseName,
        (value) => log.bestWeightKg > value ? log.bestWeightKg : value,
        ifAbsent: () => log.bestWeightKg,
      );
    }

    final rows = bests.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = rows.first.value <= 0 ? 1.0 : rows.first.value;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Exercise best weights',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in rows.take(6)) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD8E2FF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatCompactNumber(row.value)} kg',
                  style: const TextStyle(
                    color: Color(0xFF31E981),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (row.value / maxValue).clamp(0.0, 1.0),
                minHeight: 9,
                backgroundColor: const Color(0xFF20283B),
                color: const Color(0xFF31E981),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ExerciseHistoryTable extends StatelessWidget {
  const _ExerciseHistoryTable({required this.logs});

  final List<_GymProgressLog> logs;

  @override
  Widget build(BuildContext context) {
    final visible = logs.length > 6 ? logs.sublist(logs.length - 6) : logs;

    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recent exercise detail',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (final log in visible.reversed) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    log.exerciseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD8E2FF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatCompactNumber(log.bestWeightKg)} kg',
                  style: const TextStyle(
                    color: Color(0xFF31E981),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${formatDate(log.date)} | ${log.sets} sets | ${log.reps} reps | est max ${_formatCompactNumber(log.bestEstimatedMaxKg)} kg',
              style: const TextStyle(
                color: Color(0xFF8396C7),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PersonalLogTile extends StatelessWidget {
  const _PersonalLogTile({required this.entry, this.onDelete});

  final PersonalLogEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final metric = _displayMetric(entry);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF20283B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF34405F)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_categoryIcon(entry.category), color: const Color(0xFF4F8DF7)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.category.label} | ${formatDate(entry.date)}',
                    style: const TextStyle(
                      color: Color(0xFF8396C7),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (metric.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      metric,
                      style: const TextStyle(
                        color: Color(0xFF31E981),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  if (entry.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry.notes,
                      style: const TextStyle(
                        color: Color(0xFFD8E2FF),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonalLogFolders extends StatelessWidget {
  const _PersonalLogFolders({required this.entries, required this.onDelete});

  final List<PersonalLogEntry> entries;
  final ValueChanged<PersonalLogEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final categories = PersonalLogCategory.values.where((category) {
      return entries.any((entry) => entry.category == category);
    });

    return Column(
      children: [
        for (final category in categories)
          _PersonalLogFolder(
            category: category,
            entries:
                entries.where((entry) => entry.category == category).toList()
                  ..sort((a, b) => b.date.compareTo(a.date)),
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _PersonalLogFolder extends StatelessWidget {
  const _PersonalLogFolder({
    required this.category,
    required this.entries,
    required this.onDelete,
  });

  final PersonalLogCategory category;
  final List<PersonalLogEntry> entries;
  final ValueChanged<PersonalLogEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(_categoryIcon(category), color: const Color(0xFF4F8DF7)),
        title: Text(
          category.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${entries.length} saved',
          style: const TextStyle(
            color: Color(0xFF8396C7),
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          for (final entry in entries)
            _PersonalLogTile(entry: entry, onDelete: () => onDelete(entry)),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8396C7),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

Future<void> _showPersonalLogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _PersonalLogSheet(),
  );
}

Future<void> _showExerciseLogSheet(
  BuildContext context, {
  required _WorkoutSplit split,
  required _WorkoutExercise exercise,
  PersonalLogEntry? latestLog,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ExerciseLogSheet(
      split: split,
      exercise: exercise,
      latestLog: latestLog,
    ),
  );
}

Future<void> _showGuidedWorkoutSheet(
  BuildContext context, {
  required _WorkoutSplit split,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _GuidedWorkoutSheet(split: split),
  );
}

class _GuidedWorkoutSheet extends StatefulWidget {
  const _GuidedWorkoutSheet({required this.split});

  final _WorkoutSplit split;

  @override
  State<_GuidedWorkoutSheet> createState() => _GuidedWorkoutSheetState();
}

class _GuidedWorkoutSheetState extends State<_GuidedWorkoutSheet> {
  final notesController = TextEditingController();
  final loggedSets = <_LoggedWorkoutSet>[];
  late final List<_WorkoutExercise> exerciseQueue;
  double weightKg = 0;
  int exerciseIndex = 0;
  int reps = 12;
  double? lastWeightKg;
  int? lastReps;

  _WorkoutExercise get exercise => exerciseQueue[exerciseIndex];

  @override
  void initState() {
    super.initState();
    exerciseQueue = [...widget.split.exercises];
    _loadExercise();
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  void _loadExercise() {
    weightKg = 0;
    reps = int.tryParse(exercise.defaultReps) ?? 12;
  }

  void _jumpToExercise(int index) {
    if (index == exerciseIndex) return;

    setState(() {
      exerciseIndex = index;
      _loadExercise();
    });
  }

  void _moveBusyExerciseLater() {
    if (exerciseQueue.length <= 1) return;

    final busyExercise = exercise;

    setState(() {
      exerciseQueue
        ..removeAt(exerciseIndex)
        ..add(busyExercise);
      if (exerciseIndex >= exerciseQueue.length) {
        exerciseIndex = exerciseQueue.length - 1;
      }
      _loadExercise();
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('${busyExercise.name} moved to later.')),
      );
  }

  void _useSubstitute(String name) {
    setState(() {
      exerciseQueue[exerciseIndex] = _WorkoutExercise(
        name: name,
        target: 'Substitute for ${exercise.name}',
      );
      _loadExercise();
    });
  }

  void _useLastSet() {
    final weight = lastWeightKg;
    final previousReps = lastReps;

    if (weight == null && previousReps == null) return;

    setState(() {
      if (weight != null) weightKg = weight;
      if (previousReps != null) reps = previousReps;
    });
  }

  void _addSet() {
    setState(() {
      loggedSets.add(
        _LoggedWorkoutSet(
          exerciseName: exercise.name,
          weightKg: exercise.tracksLoad ? weightKg : 0,
          reps: reps,
        ),
      );
      lastWeightKg = weightKg;
      lastReps = reps;
    });
  }

  void _removeSet(int index) {
    setState(() => loggedSets.removeAt(index));
  }

  void _nextExercise() {
    setState(() {
      exerciseIndex = (exerciseIndex + 1) % exerciseQueue.length;
      _loadExercise();
    });
  }

  void _saveWorkout() {
    if (loggedSets.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Add at least one set.')));
      return;
    }

    final notes = notesController.text.trim();
    final bodyWeightKg = _latestBodyWeightKg(
      context.read<AppState>().personalLogEntries,
    );
    final grouped = <String, List<_LoggedWorkoutSet>>{};

    for (final set in loggedSets) {
      grouped.putIfAbsent(set.exerciseName, () => []).add(set);
    }

    for (final entry in grouped.entries) {
      final sets = entry.value;
      final calories = _estimatedWorkoutCalories(
        bodyWeightKg: bodyWeightKg,
        setCount: sets.length,
      );
      final metric = [
        for (var index = 0; index < sets.length; index++)
          sets[index].summary(index + 1),
        if (calories > 0) 'Estimated calories: $calories kcal',
        'Body weight used: ${_formatWeightKg(bodyWeightKg)} kg',
      ].join('\n');

      context.read<AppState>().addPersonalLogEntry(
        PersonalLogEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}-${entry.key}',
          category: PersonalLogCategory.gym,
          date: DateTime.now(),
          title: '${widget.split.name}: ${entry.key}',
          metric: metric,
          notes: notes,
        ),
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final loggedExerciseCount = loggedSets
        .map((set) => set.exerciseName)
        .toSet()
        .length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ListView(
        shrinkWrap: true,
        children: [
          _SheetHeader(title: widget.split.name),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(label: 'Sets', value: '${loggedSets.length}'),
              _MetricPill(label: 'Exercises', value: '$loggedExerciseCount'),
            ],
          ),
          const SizedBox(height: 14),
          _CoachPanel(
            title: 'Current exercise',
            body: exercise.name,
            detail: exercise.target.isEmpty
                ? '${exercise.defaultSets} sets x ${exercise.defaultReps} reps'
                : exercise.target,
          ),
          const SizedBox(height: 10),
          _ExerciseQueueChips(
            exercises: exerciseQueue,
            selectedIndex: exerciseIndex,
            onSelected: _jumpToExercise,
          ),
          if (exercise.alternatives.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SubstituteChips(
              alternatives: exercise.alternatives,
              onSelected: _useSubstitute,
            ),
          ],
          if (exercise.cue.isNotEmpty) ...[
            const SizedBox(height: 10),
            _CoachPanel(
              title: 'Cue',
              body: exercise.cue,
              detail: 'Log what you actually did. Switch exercise anytime.',
            ),
          ],
          const SizedBox(height: 12),
          if (exercise.tracksLoad)
            Row(
              children: [
                Expanded(
                  child: _WeightStepper(
                    value: weightKg,
                    onChanged: (value) {
                      setState(() => weightKg = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberStepper(
                    label: 'Reps',
                    value: reps,
                    min: 0,
                    onChanged: (value) {
                      setState(() => reps = value);
                    },
                  ),
                ),
              ],
            )
          else
            _NumberStepper(
              label: 'Reps / seconds',
              value: reps,
              min: 0,
              onChanged: (value) {
                setState(() => reps = value);
              },
            ),
          const SizedBox(height: 10),
          if (lastWeightKg != null || lastReps != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _useLastSet,
                icon: const Icon(Icons.replay_rounded),
                label: Text(
                  'Use last set'
                  '${lastWeightKg == null ? '' : ' ${_formatWeightKg(lastWeightKg!)} kg'}'
                  '${lastReps == null ? '' : ' x $lastReps reps'}',
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: notesController,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Trainer notes',
              hintText: 'Form, pump, pain, progression, next target',
            ),
          ),
          if (loggedSets.isNotEmpty) ...[
            const SizedBox(height: 12),
            _LoggedSetsList(items: loggedSets, onRemove: _removeSet),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _addSet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Set'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _nextExercise,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Next Exercise'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _moveBusyExerciseLater,
            icon: const Icon(Icons.swap_vert_rounded),
            label: const Text('Machine busy - move later'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: loggedSets.isEmpty ? null : _saveWorkout,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Workout'),
          ),
        ],
      ),
    );
  }
}

class _LoggedWorkoutSet {
  const _LoggedWorkoutSet({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
  });

  final String exerciseName;
  final double weightKg;
  final int reps;

  String summary(int setNumber) {
    return [
      'Set $setNumber',
      if (weightKg > 0) '${_formatWeightKg(weightKg)} kg',
      '$reps reps',
    ].join(' | ');
  }
}

class _CoachPanel extends StatelessWidget {
  const _CoachPanel({
    required this.title,
    required this.body,
    required this.detail,
  });

  final String title;
  final String body;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseQueueChips extends StatelessWidget {
  const _ExerciseQueueChips({
    required this.exercises,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_WorkoutExercise> exercises;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available now',
            style: TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < exercises.length; index++)
                ChoiceChip(
                  selected: index == selectedIndex,
                  label: Text(exercises[index].name),
                  onSelected: (_) => onSelected(index),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubstituteChips extends StatelessWidget {
  const _SubstituteChips({
    required this.alternatives,
    required this.onSelected,
  });

  final List<String> alternatives;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13294D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'If this is taken',
            style: TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final alternative in alternatives)
                ActionChip(
                  avatar: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(alternative),
                  onPressed: () => onSelected(alternative),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoggedSetsList extends StatelessWidget {
  const _LoggedSetsList({required this.items, required this.onRemove});

  final List<_LoggedWorkoutSet> items;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Logged sets',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < items.length; index++)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${items[index].exerciseName} | '
                    '${items[index].summary(index + 1)}',
                    style: const TextStyle(color: Color(0xFFD8E2FF)),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove set',
                  onPressed: () => onRemove(index),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeightStepper extends StatelessWidget {
  const _WeightStepper({
    required this.value,
    required this.onChanged,
    this.label = 'Weight',
    this.smallStep = 2.5,
    this.largeStep = 5,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double smallStep;
  final double largeStep;

  @override
  Widget build(BuildContext context) {
    return _StepperPanel(
      label: label,
      value: '${_formatWeightKg(value)} kg',
      buttons: [
        _StepperAction(
          label: '-${_formatStep(largeStep)}',
          onTap: () => _change(-largeStep),
        ),
        _StepperAction(
          label: '-${_formatStep(smallStep)}',
          onTap: () => _change(-smallStep),
        ),
        _StepperAction(
          label: '+${_formatStep(smallStep)}',
          onTap: () => _change(smallStep),
        ),
        _StepperAction(
          label: '+${_formatStep(largeStep)}',
          onTap: () => _change(largeStep),
        ),
      ],
    );
  }

  void _change(double amount) {
    final changed = (value + amount).clamp(0, 500).toDouble();

    onChanged((changed * 10).roundToDouble() / 10);
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;

  @override
  Widget build(BuildContext context) {
    return _StepperPanel(
      label: label,
      value: '$value',
      buttons: [
        _StepperAction(
          label: 'Decrease $label',
          icon: Icons.remove_rounded,
          onTap: () => onChanged((value - 1).clamp(min, 99)),
        ),
        _StepperAction(
          label: 'Increase $label',
          icon: Icons.add_rounded,
          onTap: () => onChanged((value + 1).clamp(min, 99)),
        ),
      ],
    );
  }
}

class _StepperPanel extends StatelessWidget {
  const _StepperPanel({
    required this.label,
    required this.value,
    required this.buttons,
  });

  final String label;
  final String value;
  final List<_StepperAction> buttons;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final button in buttons)
                IconButton.filledTonal(
                  tooltip: button.label,
                  onPressed: button.onTap,
                  icon: button.icon == null
                      ? Text(
                          button.label,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        )
                      : Icon(button.icon),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperAction {
  const _StepperAction({this.label = '', this.icon, required this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
}

class _ExerciseLogSheet extends StatefulWidget {
  const _ExerciseLogSheet({
    required this.split,
    required this.exercise,
    required this.latestLog,
  });

  final _WorkoutSplit split;
  final _WorkoutExercise exercise;
  final PersonalLogEntry? latestLog;

  @override
  State<_ExerciseLogSheet> createState() => _ExerciseLogSheetState();
}

class _ExerciseLogSheetState extends State<_ExerciseLogSheet> {
  final notesController = TextEditingController();
  final loggedSets = <_LoggedWorkoutSet>[];
  double weightKg = 0;
  int reps = 12;
  String timing = '3:2:1';

  @override
  void initState() {
    super.initState();
    reps = int.tryParse(widget.exercise.defaultReps) ?? 12;
    _loadLatestLog();
    notesController.text = widget.exercise.cue;
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  void _loadLatestLog() {
    final latestLog = widget.latestLog;

    if (latestLog == null) return;

    final parsed =
        _parseGuidedMetric(latestLog.metric) ??
        _parseManualMetric(latestLog.metric);

    if (parsed == null) return;
    if (parsed.bestWeightKg > 0) weightKg = parsed.bestWeightKg;
    if (parsed.sets > 0 && parsed.reps > 0) {
      reps = (parsed.reps / parsed.sets).round();
    }
  }

  void _addSet() {
    setState(() {
      loggedSets.add(
        _LoggedWorkoutSet(
          exerciseName: widget.exercise.name,
          weightKg: widget.exercise.tracksLoad ? weightKg : 0,
          reps: reps,
        ),
      );
    });
  }

  void _removeSet(int index) {
    setState(() => loggedSets.removeAt(index));
  }

  void _save() {
    if (loggedSets.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Add at least one set.')));
      return;
    }

    final notes = notesController.text.trim();
    final bodyWeightKg = _latestBodyWeightKg(
      context.read<AppState>().personalLogEntries,
    );
    final calories = _estimatedWorkoutCalories(
      bodyWeightKg: bodyWeightKg,
      setCount: loggedSets.length,
    );
    final metricParts = <String>[
      for (var index = 0; index < loggedSets.length; index++)
        loggedSets[index].summary(index + 1),
      if (calories > 0) 'Estimated calories: $calories kcal',
      'Body weight used: ${_formatWeightKg(bodyWeightKg)} kg',
      'tempo $timing',
    ];

    context.read<AppState>().addPersonalLogEntry(
      PersonalLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: PersonalLogCategory.gym,
        date: DateTime.now(),
        title: '${widget.split.name}: ${widget.exercise.name}',
        metric: metricParts.join(' | '),
        notes: notes,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final latestLog = widget.latestLog;
    final latestProgress = latestLog == null
        ? null
        : _GymProgressLog.fromEntry(latestLog);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ListView(
        shrinkWrap: true,
        children: [
          _SheetHeader(
            title: widget.exercise.name,
            subtitle: widget.split.name,
          ),
          if (latestProgress != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.exercise.tracksLoad)
                  _MetricPill(
                    label: 'Last kg',
                    value: _formatCompactNumber(latestProgress.bestWeightKg),
                  ),
                _MetricPill(
                  label: 'Avg reps',
                  value: _formatCompactNumber(latestProgress.averageRepsPerSet),
                ),
                _MetricPill(label: 'Sets', value: '${latestProgress.sets}'),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (widget.exercise.tracksLoad) ...[
            _WeightStepper(
              value: weightKg,
              smallStep: 0.5,
              largeStep: 2.5,
              onChanged: (value) {
                setState(() => weightKg = value);
              },
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _NumberStepper(
                  label: 'Reps',
                  value: reps,
                  min: 0,
                  onChanged: (value) {
                    setState(() => reps = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '3:2:1', label: Text('3:2:1')),
              ButtonSegment(value: 'Controlled', label: Text('Control')),
              ButtonSegment(value: 'Failure', label: Text('Failure')),
            ],
            selected: {timing},
            onSelectionChanged: (values) =>
                setState(() => timing = values.first),
          ),
          if (loggedSets.isNotEmpty) ...[
            const SizedBox(height: 12),
            _LoggedSetsList(items: loggedSets, onRemove: _removeSet),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _addSet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Set'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Form, pain, pump, progression, next target',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Exercise'),
          ),
        ],
      ),
    );
  }
}

class _PersonalLogSheet extends StatefulWidget {
  const _PersonalLogSheet();

  @override
  State<_PersonalLogSheet> createState() => _PersonalLogSheetState();
}

class _PersonalLogSheetState extends State<_PersonalLogSheet> {
  final titleController = TextEditingController();
  final metricController = TextEditingController();
  final notesController = TextEditingController();
  PersonalLogCategory category = PersonalLogCategory.gym;

  @override
  void dispose() {
    titleController.dispose();
    metricController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _save() {
    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    final metric = metricController.text.trim();

    if (title.isEmpty && notes.isEmpty && metric.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Add a log first.')));
      return;
    }

    context.read<AppState>().addPersonalLogEntry(
      PersonalLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: category,
        date: DateTime.now(),
        title: title.isEmpty ? category.label : title,
        notes: notes,
        metric: metric,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ListView(
        shrinkWrap: true,
        children: [
          const _SheetHeader(title: 'Personal Log'),
          const SizedBox(height: 14),
          SegmentedButton<PersonalLogCategory>(
            segments: const [
              ButtonSegment(
                value: PersonalLogCategory.gym,
                icon: Icon(Icons.fitness_center_rounded),
                label: Text('Gym'),
              ),
              ButtonSegment(
                value: PersonalLogCategory.bodyWeight,
                icon: Icon(Icons.monitor_weight_rounded),
                label: Text('Weight'),
              ),
              ButtonSegment(
                value: PersonalLogCategory.health,
                icon: Icon(Icons.favorite_border_rounded),
                label: Text('Health'),
              ),
              ButtonSegment(
                value: PersonalLogCategory.goal,
                icon: Icon(Icons.flag_outlined),
                label: Text('Goal'),
              ),
              ButtonSegment(
                value: PersonalLogCategory.note,
                icon: Icon(Icons.note_alt_outlined),
                label: Text('Note'),
              ),
            ],
            selected: {category},
            onSelectionChanged: (values) {
              setState(() => category = values.first);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: metricController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Metric',
              hintText: 'Sets, reps, weight, distance, time, or body weight',
              prefixIcon: Icon(Icons.trending_up_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            minLines: 5,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Progress notes',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Log'),
          ),
        ],
      ),
    );
  }
}

class _WorkoutSplit {
  const _WorkoutSplit({
    required this.name,
    required this.icon,
    required this.focus,
    required this.exercises,
  });

  final String name;
  final IconData icon;
  final String focus;
  final List<_WorkoutExercise> exercises;
}

class _WorkoutExercise {
  const _WorkoutExercise({
    required this.name,
    this.target = '',
    this.cue = '',
    this.alternatives = const [],
    this.defaultSetCount = 3,
    this.defaultRepCount = 12,
    this.tracksLoad = true,
  });

  final String name;
  final String target;
  final String cue;
  final List<String> alternatives;
  final int defaultSetCount;
  final int defaultRepCount;
  final bool tracksLoad;

  String get defaultSets => '$defaultSetCount';

  String get defaultReps => '$defaultRepCount';
}

const _workoutSplits = [
  _WorkoutSplit(
    name: 'Back',
    icon: Icons.accessibility_new_rounded,
    focus: 'Pull strength, lat width, rear delts, and biceps.',
    exercises: [
      _WorkoutExercise(
        name: 'Conventional deadlift',
        target: '5 sets x 5 reps',
        cue: 'Brace hard, push the floor away, keep the bar close.',
        alternatives: ['Romanian deadlift', 'Trap bar deadlift'],
      ),
      _WorkoutExercise(
        name: 'Reverse lat pulldown machine',
        alternatives: ['Single-arm cable pulldown', 'Dumbbell row'],
      ),
      _WorkoutExercise(
        name: 'Cable lat prayers',
        cue: 'Hinge slightly, drive elbows down, keep lats loaded.',
        alternatives: ['Band straight-arm pulldown', 'Dumbbell pullover'],
      ),
      _WorkoutExercise(
        name: 'Reverse pec deck',
        alternatives: ['Cable face pull', 'Rear delt dumbbell fly'],
      ),
      _WorkoutExercise(
        name: 'Seated cable pull apart',
        alternatives: ['Band pull apart', 'Cable face pull'],
      ),
      _WorkoutExercise(
        name: 'Reverse seated incline dumbbell pulls',
        alternatives: ['Rear delt row', 'Chest-supported dumbbell row'],
      ),
      _WorkoutExercise(
        name: 'Bicep EZ bar',
        alternatives: ['Cable curl', 'Dumbbell curl'],
      ),
      _WorkoutExercise(
        name: 'Bicep alternating dumbbells',
        alternatives: ['Hammer curl', 'Cable curl'],
      ),
    ],
  ),
  _WorkoutSplit(
    name: 'Legs',
    icon: Icons.directions_walk_rounded,
    focus:
        'Hypertrophy focus. Track exercise, form, sets, reps, and tempo 3:2:1.',
    exercises: [
      _WorkoutExercise(
        name: 'Glute bridges with sand bag holds',
        target: '3 sets to failure',
        cue: 'Pause hard at the top and keep glutes loaded.',
        alternatives: ['Hip thrust machine', 'Dumbbell glute bridge'],
      ),
      _WorkoutExercise(
        name: 'Banded sideways walk',
        target: 'Until warmed up',
        alternatives: ['Cable hip abduction', 'Side-lying abduction'],
      ),
      _WorkoutExercise(
        name: 'Walking lunges',
        target: '6 sets x 25 reps',
        alternatives: ['Reverse lunges', 'Step-ups'],
      ),
      _WorkoutExercise(
        name: 'Box squats',
        alternatives: ['Goblet squat', 'Leg press'],
      ),
      _WorkoutExercise(
        name: 'Split squats',
        alternatives: ['Reverse lunge', 'Step-up'],
      ),
      _WorkoutExercise(
        name: 'Single-leg RDL',
        alternatives: ['Dumbbell RDL', 'Cable pull-through'],
      ),
      _WorkoutExercise(
        name: 'Back extension',
        cue: 'Rounded back, glute focus, control the top squeeze.',
        alternatives: ['Cable pull-through', 'Dumbbell RDL'],
      ),
    ],
  ),
  _WorkoutSplit(
    name: 'Chest + Shoulders',
    icon: Icons.fitness_center_rounded,
    focus:
        'Press strength, chest stimulus, side delts, and bodyweight finishers.',
    exercises: [
      _WorkoutExercise(
        name: 'Bench press',
        alternatives: ['Dumbbell bench press', 'Push ups'],
      ),
      _WorkoutExercise(
        name: 'Chest flys - 3 heights',
        alternatives: ['Dumbbell fly', 'Cable fly'],
      ),
      _WorkoutExercise(
        name: 'Iso press / seated chest fly machine',
        alternatives: ['Dumbbell press', 'Push ups'],
      ),
      _WorkoutExercise(
        name: 'Standing overhead press',
        alternatives: ['Seated dumbbell press', 'Machine shoulder press'],
      ),
      _WorkoutExercise(
        name: 'Lateral raises',
        alternatives: ['Cable lateral raise', 'Machine lateral raise'],
      ),
      _WorkoutExercise(
        name: 'Dips',
        alternatives: ['Close-grip push ups', 'Triceps pressdown'],
      ),
      _WorkoutExercise(
        name: 'Push ups',
        alternatives: ['Incline push ups', 'Machine chest press'],
      ),
    ],
  ),
  _WorkoutSplit(
    name: 'Stretch + Abs',
    icon: Icons.self_improvement_rounded,
    focus:
        'Sun salutations, RSI-friendly wrist and elbow care, then harder abs '
        'without forcing painful hand loading.',
    exercises: [
      _WorkoutExercise(
        name: 'Wrist-safe sun salutation',
        target: '3 slow rounds',
        cue:
            'Mountain, reach up, fold to shins or blocks, half lift, step back '
            'to low lunge, return to fold, rise. Skip plank and down dog.',
        defaultSetCount: 3,
        defaultRepCount: 1,
        tracksLoad: false,
      ),
      _WorkoutExercise(
        name: 'Low lunge hip opener',
        target: '2 sets x 30 seconds each side',
        cue:
            'Hands on thigh, blocks, or bench. Keep wrists neutral and ease the '
            'front hip open.',
        defaultSetCount: 2,
        defaultRepCount: 30,
        tracksLoad: false,
      ),
      _WorkoutExercise(
        name: 'RSI wrist flexor stretch',
        target: '2 sets x 20 seconds each side',
        cue:
            'Elbow straight but soft, palm up, gently draw fingers back. Keep '
            'it mild, not sharp.',
        defaultSetCount: 2,
        defaultRepCount: 20,
        tracksLoad: false,
      ),
      _WorkoutExercise(
        name: 'RSI wrist extensor stretch',
        target: '2 sets x 20 seconds each side',
        cue:
            'Arm forward, palm down, gently bend the wrist so knuckles point '
            'down. Stop if elbow pain spikes.',
        defaultSetCount: 2,
        defaultRepCount: 20,
        tracksLoad: false,
      ),
      _WorkoutExercise(
        name: 'Dead bug press',
        target: '3 sets x 8 reps each side',
        cue:
            'Low back heavy, opposite hand presses into knee. Move slowly and '
            'keep ribs down.',
        defaultSetCount: 3,
        defaultRepCount: 8,
        tracksLoad: false,
      ),
      _WorkoutExercise(
        name: 'Reverse crunch',
        target: '3 sets x 10 reps',
        cue:
            'Curl pelvis up, do not swing legs. Stop if hip flexors or low back '
            'take over.',
        defaultSetCount: 3,
        defaultRepCount: 10,
        tracksLoad: false,
      ),
      _WorkoutExercise(
        name: 'Hollow tuck hold',
        target: '3 sets x 15 seconds',
        cue:
            'Knees tucked, ribs down, shoulder blades barely lifted. Make it '
            'easier before neck or back complains.',
        defaultSetCount: 3,
        defaultRepCount: 15,
        tracksLoad: false,
      ),
      _WorkoutExercise(
        name: 'Forearm side plank from knees',
        target: '2 sets x 20 seconds each side',
        cue:
            'Use forearm, not wrist. Skip this if elbow pressure is sore and do '
            'dead bug instead.',
        defaultSetCount: 2,
        defaultRepCount: 20,
        tracksLoad: false,
      ),
    ],
  ),
];

const _allExercisesLabel = 'All gym logs';
const _defaultBodyWeightKg = 112.5;

enum _GymChartMetric {
  estimatedMax('Estimated max', 'Est max'),
  bestWeight('Best weight', 'Kg'),
  sets('Sets completed', 'Sets'),
  reps('Reps completed', 'Reps');

  const _GymChartMetric(this.label, this.shortLabel);

  final String label;
  final String shortLabel;

  double valueFor(_GymProgressPoint point) {
    switch (this) {
      case _GymChartMetric.estimatedMax:
        return point.bestEstimatedMaxKg;
      case _GymChartMetric.bestWeight:
        return point.bestWeightKg;
      case _GymChartMetric.sets:
        return point.sets.toDouble();
      case _GymChartMetric.reps:
        return point.reps.toDouble();
    }
  }
}

class _GymProgressLog {
  const _GymProgressLog({
    required this.date,
    required this.exerciseName,
    required this.bestWeightKg,
    required this.bestEstimatedMaxKg,
    required this.estimatedCalories,
    required this.sets,
    required this.reps,
  });

  final DateTime date;
  final String exerciseName;
  final double bestWeightKg;
  final double bestEstimatedMaxKg;
  final int estimatedCalories;
  final int sets;
  final int reps;

  double get averageRepsPerSet => sets <= 0 ? 0 : reps / sets;

  bool get hasLoad => bestWeightKg > 0;

  static _GymProgressLog? fromEntry(PersonalLogEntry entry) {
    final metric = entry.metric.trim();

    if (metric.isEmpty) return null;

    final guided = _parseGuidedMetric(metric);
    final manual = guided ?? _parseManualMetric(metric);

    if (manual == null) return null;

    return _GymProgressLog(
      date: DateTime(entry.date.year, entry.date.month, entry.date.day),
      exerciseName: _exerciseNameFromTitle(entry.title),
      bestWeightKg: manual.bestWeightKg,
      bestEstimatedMaxKg: manual.bestEstimatedMaxKg,
      estimatedCalories: _caloriesForMetric(metric, manual.sets),
      sets: manual.sets,
      reps: manual.reps,
    );
  }
}

class _GymProgressPoint {
  const _GymProgressPoint({
    required this.date,
    required this.bestWeightKg,
    required this.bestEstimatedMaxKg,
    required this.sets,
    required this.reps,
    required this.sessions,
  });

  final DateTime date;
  final double bestWeightKg;
  final double bestEstimatedMaxKg;
  final int sets;
  final int reps;
  final int sessions;

  double get averageRepsPerSet => sets <= 0 ? 0 : reps / sets;

  static List<_GymProgressPoint> fromLogs(List<_GymProgressLog> logs) {
    final grouped = <DateTime, List<_GymProgressLog>>{};

    for (final log in logs) {
      grouped.putIfAbsent(log.date, () => []).add(log);
    }

    return grouped.entries.map((entry) {
      final dayLogs = entry.value;
      final bestWeight = dayLogs.fold<double>(
        0,
        (best, log) => log.bestWeightKg > best ? log.bestWeightKg : best,
      );
      final bestEstimatedMax = dayLogs.fold<double>(
        0,
        (best, log) =>
            log.bestEstimatedMaxKg > best ? log.bestEstimatedMaxKg : best,
      );
      final sets = dayLogs.fold<int>(0, (total, log) => total + log.sets);
      final reps = dayLogs.fold<int>(0, (total, log) => total + log.reps);

      return _GymProgressPoint(
        date: entry.key,
        bestWeightKg: bestWeight,
        bestEstimatedMaxKg: bestEstimatedMax,
        sets: sets,
        reps: reps,
        sessions: dayLogs.length,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }
}

class _GymProgressTotals {
  const _GymProgressTotals({
    required this.bestWeightKg,
    required this.bestEstimatedMaxKg,
    required this.sets,
    required this.reps,
    required this.sessions,
    required this.loadedSessions,
  });

  final double bestWeightKg;
  final double bestEstimatedMaxKg;
  final int sets;
  final int reps;
  final int sessions;
  final int loadedSessions;

  double get averageRepsPerSet => sets <= 0 ? 0 : reps / sets;

  double get averageSetsPerSession => sessions <= 0 ? 0 : sets / sessions;

  double get loadedSessionRatio =>
      sessions <= 0 ? 0 : loadedSessions / sessions;

  factory _GymProgressTotals.fromLogs(List<_GymProgressLog> logs) {
    return _GymProgressTotals(
      bestWeightKg: logs.fold<double>(
        0,
        (best, log) => log.bestWeightKg > best ? log.bestWeightKg : best,
      ),
      bestEstimatedMaxKg: logs.fold<double>(
        0,
        (best, log) =>
            log.bestEstimatedMaxKg > best ? log.bestEstimatedMaxKg : best,
      ),
      sets: logs.fold<int>(0, (total, log) => total + log.sets),
      reps: logs.fold<int>(0, (total, log) => total + log.reps),
      sessions: logs.length,
      loadedSessions: logs.where((log) => log.hasLoad).length,
    );
  }
}

class _ExerciseRecord {
  const _ExerciseRecord({
    required this.exerciseName,
    required this.date,
    required this.bestWeightKg,
    required this.estimatedMaxKg,
  });

  final String exerciseName;
  final DateTime date;
  final double bestWeightKg;
  final double estimatedMaxKg;

  static List<_ExerciseRecord> fromLogs(List<_GymProgressLog> logs) {
    final bestByExercise = <String, _ExerciseRecord>{};

    for (final log in logs) {
      if (log.bestEstimatedMaxKg <= 0 && log.bestWeightKg <= 0) continue;

      final current = bestByExercise[log.exerciseName];

      if (current == null || log.bestEstimatedMaxKg > current.estimatedMaxKg) {
        bestByExercise[log.exerciseName] = _ExerciseRecord(
          exerciseName: log.exerciseName,
          date: log.date,
          bestWeightKg: log.bestWeightKg,
          estimatedMaxKg: log.bestEstimatedMaxKg,
        );
      }
    }

    return bestByExercise.values.toList()
      ..sort((a, b) => b.estimatedMaxKg.compareTo(a.estimatedMaxKg));
  }
}

class _CaloriesByDate {
  const _CaloriesByDate({required this.date, required this.calories});

  final DateTime date;
  final int calories;

  static List<_CaloriesByDate> fromLogs(List<_GymProgressLog> logs) {
    final grouped = <DateTime, int>{};

    for (final log in logs) {
      if (log.estimatedCalories <= 0) continue;

      grouped.update(
        log.date,
        (value) => value + log.estimatedCalories,
        ifAbsent: () => log.estimatedCalories,
      );
    }

    return grouped.entries
        .map((entry) => _CaloriesByDate(date: entry.key, calories: entry.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}

class _BodyWeightPoint {
  const _BodyWeightPoint({required this.date, required this.weightKg});

  final DateTime date;
  final double weightKg;

  static List<_BodyWeightPoint> fromEntries(List<PersonalLogEntry> entries) {
    return entries
        .map((entry) {
          final weight = _parseBodyWeightKg(entry.metric);

          if (weight <= 0) return null;

          return _BodyWeightPoint(
            date: DateTime(entry.date.year, entry.date.month, entry.date.day),
            weightKg: weight,
          );
        })
        .whereType<_BodyWeightPoint>()
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}

class _ParsedGymMetric {
  const _ParsedGymMetric({
    required this.bestWeightKg,
    required this.bestEstimatedMaxKg,
    required this.sets,
    required this.reps,
  });

  final double bestWeightKg;
  final double bestEstimatedMaxKg;
  final int sets;
  final int reps;
}

_ParsedGymMetric? _parseGuidedMetric(String metric) {
  final setLines = metric
      .split('\n')
      .where(
        (line) => RegExp(r'\bset\s+\d+\b', caseSensitive: false).hasMatch(line),
      )
      .toList();

  if (setLines.isEmpty) return null;

  var bestWeightKg = 0.0;
  var bestEstimatedMaxKg = 0.0;
  var reps = 0;

  for (final line in setLines) {
    final weight = _firstDouble(
      RegExp(r'(\d+(?:\.\d+)?)\s*kg', caseSensitive: false),
      line,
    );
    final lineReps = _firstInt(
      RegExp(r'(\d+)\s*reps?', caseSensitive: false),
      line,
    );

    if (weight > bestWeightKg) bestWeightKg = weight;
    final estimatedMax = _estimatedMaxKg(weight: weight, reps: lineReps);
    if (estimatedMax > bestEstimatedMaxKg) {
      bestEstimatedMaxKg = estimatedMax;
    }
    reps += lineReps;
  }

  return _ParsedGymMetric(
    bestWeightKg: bestWeightKg,
    bestEstimatedMaxKg: bestEstimatedMaxKg,
    sets: setLines.length,
    reps: reps,
  );
}

_ParsedGymMetric? _parseManualMetric(String metric) {
  final weight = _firstDouble(
    RegExp(r'(\d+(?:\.\d+)?)\s*kg', caseSensitive: false),
    metric,
  );
  final setRepMatch = RegExp(
    r'(\d+)\s*x\s*(\d+)(?!\s*-)',
    caseSensitive: false,
  ).firstMatch(metric);
  final sets = int.tryParse(setRepMatch?.group(1) ?? '') ?? 0;
  final repsPerSet = int.tryParse(setRepMatch?.group(2) ?? '') ?? 0;
  final reps = sets * repsPerSet;

  if (weight <= 0 && sets <= 0 && reps <= 0) return null;

  return _ParsedGymMetric(
    bestWeightKg: weight,
    bestEstimatedMaxKg: _estimatedMaxKg(weight: weight, reps: repsPerSet),
    sets: sets,
    reps: reps,
  );
}

double _estimatedMaxKg({required double weight, required int reps}) {
  if (weight <= 0 || reps <= 0) return 0;

  return weight * (1 + reps / 30);
}

double _firstDouble(RegExp pattern, String value) {
  final match = pattern.firstMatch(value);
  return double.tryParse(match?.group(1) ?? '') ?? 0;
}

int _firstInt(RegExp pattern, String value) {
  if (RegExp(r'\d+\s*-\s*\d+\s*reps?', caseSensitive: false).hasMatch(value)) {
    return 0;
  }

  final match = pattern.firstMatch(value);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

int _parseEstimatedCalories(String value) {
  final match = RegExp(
    r'(?:estimated\s*)?(\d+)\s*kcal',
    caseSensitive: false,
  ).firstMatch(value);

  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

int _caloriesForMetric(String metric, int setCount) {
  final bodyWeightKg = _parseLoggedBodyWeightKg(metric);

  if (bodyWeightKg <= 0) return _parseEstimatedCalories(metric);

  return _estimatedWorkoutCalories(
    bodyWeightKg: bodyWeightKg,
    setCount: setCount,
  );
}

double _parseLoggedBodyWeightKg(String value) {
  return _firstDouble(
    RegExp(
      r'\bbody\s*weight(?:\s*used)?\s*:?\s*(\d+(?:\.\d+)?)\s*kg',
      caseSensitive: false,
    ),
    value,
  );
}

int _estimatedWorkoutCalories({
  required double bodyWeightKg,
  required int setCount,
}) {
  if (bodyWeightKg <= 0 || setCount <= 0) return 0;

  const activeMet = 5.0;
  const restMet = 1.5;
  const activeMinutesPerSet = 0.75;
  const restMinutesPerSet = 1.25;
  final activeCalories =
      activeMet * 3.5 * bodyWeightKg / 200 * activeMinutesPerSet * setCount;
  final restCalories =
      restMet * 3.5 * bodyWeightKg / 200 * restMinutesPerSet * setCount;

  return (activeCalories + restCalories).round();
}

String _displayMetric(PersonalLogEntry entry) {
  final metric = entry.metric.trim();

  if (entry.category != PersonalLogCategory.gym || metric.isEmpty) {
    return metric;
  }

  var displayMetric = metric.replaceAllMapped(
    RegExp(r'(\d+)\s*x\s*(\d+\s*-\s*\d+)', caseSensitive: false),
    (match) => '${match.group(1)} sets | target ${match.group(2)} reps',
  );
  final parsed = _parseGuidedMetric(metric) ?? _parseManualMetric(metric);
  final calories = parsed == null ? 0 : _caloriesForMetric(metric, parsed.sets);

  if (calories > 0) {
    displayMetric = displayMetric.replaceAll(
      RegExp(r'Estimated calories:\s*\d+\s*kcal', caseSensitive: false),
      'Estimated calories: $calories kcal',
    );
  }

  return displayMetric;
}

String _exerciseNameFromTitle(String title) {
  final parts = title.split(':');
  final name = parts.length > 1 ? parts.sublist(1).join(':') : title;
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Gym log' : trimmed;
}

double _latestBodyWeightKg(List<PersonalLogEntry> entries) {
  final weightEntries =
      entries
          .where((entry) => entry.category == PersonalLogCategory.bodyWeight)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  for (final entry in weightEntries) {
    final weight = _parseBodyWeightKg(entry.metric);

    if (weight > 0) return weight;
  }

  return _defaultBodyWeightKg;
}

double _parseBodyWeightKg(String value) {
  return _firstDouble(
    RegExp(r'(\d+(?:\.\d+)?)\s*kg', caseSensitive: false),
    value,
  );
}

DateTime _weekStart(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

int _currentTrainingStreak(Iterable<DateTime> dates) {
  final days = dates
      .map((date) => DateTime(date.year, date.month, date.day))
      .toSet();
  var cursor = DateTime.now();
  cursor = DateTime(cursor.year, cursor.month, cursor.day);
  var streak = 0;

  while (days.contains(cursor)) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return streak;
}

String _formatCompactNumber(double value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}m';
  }

  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }

  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
}

String _formatWeightKg(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
}

String _formatStep(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
}

IconData _categoryIcon(PersonalLogCategory category) {
  switch (category) {
    case PersonalLogCategory.gym:
      return Icons.fitness_center_rounded;
    case PersonalLogCategory.bodyWeight:
      return Icons.monitor_weight_rounded;
    case PersonalLogCategory.health:
      return Icons.favorite_border_rounded;
    case PersonalLogCategory.note:
      return Icons.note_alt_outlined;
    case PersonalLogCategory.goal:
      return Icons.flag_outlined;
  }
}
