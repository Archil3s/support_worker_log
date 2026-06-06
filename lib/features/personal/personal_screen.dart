import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/personal_log_entry.dart';
import '../../core/models/google_export_account_scope.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/google_account_connection_card.dart';
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
        const GoogleAccountConnectionCard(
          scope: GoogleExportAccountScope.personal,
        ),
        const SizedBox(height: 12),
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
              _SplitExerciseInsightsPanel(split: split, gymEntries: gymEntries),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      _showGuidedWorkoutSheet(context, split: split),
                  icon: const Icon(Icons.directions_run_rounded),
                  label: const Text('Start Flexible Workout'),
                ),
              ),
              if (split.name == 'Stretch + Abs') ...[
                const SizedBox(height: 10),
                _StretchRecommendationsPanel(
                  key: ValueKey(_swapReasonSignature(gymEntries)),
                ),
              ],
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

class _SplitExerciseInsightsPanel extends StatelessWidget {
  const _SplitExerciseInsightsPanel({
    required this.split,
    required this.gymEntries,
  });

  final _WorkoutSplit split;
  final List<PersonalLogEntry> gymEntries;

  @override
  Widget build(BuildContext context) {
    final logs = _logsForSplit(split, gymEntries);
    final baselines = _performanceBaselines(logs);
    final exerciseCounts = {
      for (final exercise in split.exercises)
        exercise.name: logs
            .where((log) => _sameExercise(log.exerciseName, exercise.name))
            .length,
    };
    final leastLogged = exerciseCounts.entries.reduce((current, next) {
      if (next.value < current.value) return next;
      return current;
    });
    final bestScore = logs.fold<double>(0, (best, log) {
      final score = _smartScoreForLog(log, baselines);
      return score > best ? score : best;
    });
    final sets = logs.fold<int>(0, (total, log) => total + log.sets);
    final reps = logs.fold<int>(0, (total, log) => total + log.reps);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Color(0xFF31E981)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${split.name} data',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                logs.isEmpty ? 'New' : '${_formatCompactNumber(bestScore)}%',
                style: const TextStyle(
                  color: Color(0xFF31E981),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(label: 'Logs', value: '${logs.length}'),
              _MetricPill(label: 'Sets', value: '$sets'),
              _MetricPill(label: 'Reps', value: '$reps'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _splitPrompt(split, logs, leastLogged.key),
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final row in _exerciseInsightRows(split, logs).take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB5C3EA),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      row.detail,
                      style: const TextStyle(
                        color: Color(0xFF8396C7),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
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

class _StretchRecommendationsPanel extends StatelessWidget {
  const _StretchRecommendationsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.select<AppState, List<PersonalLogEntry>>(
      (appState) => appState.personalLogEntries
          .where((entry) => entry.category == PersonalLogCategory.gym)
          .toList(),
    );
    final reasonCounts = _swapReasonCounts(entries);
    final recommendations = _stretchRecommendationsForReasons(reasonCounts);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13294D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2F65A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.self_improvement_rounded,
                color: Color(0xFF31E981),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Stretch focus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (reasonCounts.isNotEmpty)
                Text(
                  reasonCounts.keys.first,
                  style: const TextStyle(
                    color: Color(0xFF31E981),
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reasonCounts.isEmpty
                ? 'Log exercise swap reasons to tune this section.'
                : 'Based on your most common swap reasons.',
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final recommendation in recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    recommendation.icon,
                    color: const Color(0xFF4F8DF7),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recommendation.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recommendation.detail,
                          style: const TextStyle(
                            color: Color(0xFFB5C3EA),
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ],
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
  _GymChartMetric selectedMetric = _GymChartMetric.smartScore;

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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_GymChartMetric>(
            segments: const [
              ButtonSegment(
                value: _GymChartMetric.smartScore,
                icon: Icon(Icons.psychology_rounded),
                label: Text('Smart'),
              ),
              ButtonSegment(
                value: _GymChartMetric.estimatedMax,
                icon: Icon(Icons.stacked_line_chart_rounded),
                label: Text('Est max'),
              ),
              ButtonSegment(
                value: _GymChartMetric.bestWeight,
                icon: Icon(Icons.scale_rounded),
                label: Text('Load'),
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
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricPill(
              label: 'Smart score',
              value: '${_formatCompactNumber(totals.averageSmartScore)}%',
            ),
            _MetricPill(label: 'Exercises', value: '${totals.uniqueExercises}'),
            _MetricPill(
              label: 'Avg reps/set',
              value: _formatCompactNumber(totals.averageRepsPerSet),
            ),
            _MetricPill(label: 'Sessions', value: '${totals.sessions}'),
          ],
        ),
        const SizedBox(height: 14),
        _SmartTrainingPanel(logs: filtered, totals: totals),
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
        _ExerciseSmartScoreBars(logs: filtered),
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
    final latestSmartScore = latest?.smartScore ?? 0;
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
          icon: Icons.psychology_rounded,
          label: 'Latest smart score',
          value: '${_formatCompactNumber(latestSmartScore)}%',
          color: const Color(0xFF31E981),
          progress: latestSmartScore / 100,
        ),
        _VisualMetricCard(
          icon: Icons.scale_rounded,
          label: 'Latest est max',
          value: '${_formatCompactNumber(latestEstimatedMax)} kg',
          color: const Color(0xFF4F8DF7),
          progress: estimatedMaxProgress,
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

class _SmartTrainingPanel extends StatelessWidget {
  const _SmartTrainingPanel({required this.logs, required this.totals});

  final List<_GymProgressLog> logs;
  final _GymProgressTotals totals;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    final intelligence = _TrainingIntelligence.fromLogs(logs);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13294D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2F65A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Color(0xFF31E981)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Smart training readout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_formatCompactNumber(intelligence.overallScore)}%',
                style: const TextStyle(
                  color: Color(0xFF31E981),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProfileBar(
            label: 'Recent performance',
            value: intelligence.performanceScore,
            maxValue: 100,
            color: const Color(0xFF31E981),
            suffix: '%',
          ),
          const SizedBox(height: 10),
          _ProfileBar(
            label: 'Consistency',
            value: intelligence.consistencyScore,
            maxValue: 100,
            color: const Color(0xFF4F8DF7),
            suffix: '%',
          ),
          const SizedBox(height: 10),
          _ProfileBar(
            label: 'Exercise coverage',
            value: intelligence.varietyScore,
            maxValue: 100,
            color: const Color(0xFFF59E0B),
            suffix: '%',
          ),
          const SizedBox(height: 10),
          _ProfileBar(
            label: 'Split balance',
            value: intelligence.balanceScore,
            maxValue: 100,
            color: const Color(0xFFE879F9),
            suffix: '%',
          ),
          const SizedBox(height: 12),
          Text(
            intelligence.nextNudge,
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
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
            '${_formatCompactNumber(record.smartScore)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF31E981),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            record.bestWeightKg > 0
                ? 'best ${_formatCompactNumber(record.bestWeightKg)} kg'
                : 'best ${record.bestReps} reps',
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
    final points = _GymProgressPoint.fromLogs(logs);
    final first = points.isEmpty ? null : points.first;
    final latest = points.isEmpty ? null : points.last;
    final firstSmartScore = first?.smartScore ?? 0;
    final latestSmartScore = latest?.smartScore ?? 0;
    final change = latestSmartScore - firstSmartScore;
    final changeText = change == 0
        ? 'No smart score change yet'
        : '${change > 0 ? '+' : ''}${_formatCompactNumber(change)}% smart score';

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
                : '$changeText from first to latest training day.',
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          if (totals.bestWeightKg > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Raw load is still tracked, but the main score compares each exercise against its own best.',
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

class _ExerciseSmartScoreBars extends StatelessWidget {
  const _ExerciseSmartScoreBars({required this.logs});

  final List<_GymProgressLog> logs;

  @override
  Widget build(BuildContext context) {
    final baselines = _performanceBaselines(logs);
    final bests = <String, double>{};

    for (final log in logs) {
      final score = _smartScoreForLog(log, baselines);

      bests.update(
        log.exerciseName,
        (value) => score > value ? score : value,
        ifAbsent: () => score,
      );
    }

    final rows = bests.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (rows.isEmpty) {
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
            'Exercise smart scores',
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
                  '${_formatCompactNumber(row.value)}%',
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
                value: (row.value / 100).clamp(0.0, 1.0),
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
                  _isBodyweightExerciseName(log.exerciseName)
                      ? '${log.reps} reps'
                      : '${_formatCompactNumber(log.bestWeightKg)} kg',
                  style: const TextStyle(
                    color: Color(0xFF31E981),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _exerciseHistoryDetail(log),
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
  String selectedSwapReason = _swapReasons.first;

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
    final current = exercise;

    setState(() {
      exerciseQueue[exerciseIndex] = current.swappedWith(
        name,
        selectedSwapReason,
      );
      _loadExercise();
    });
  }

  void _selectSwapReason(String reason) {
    setState(() {
      selectedSwapReason = reason;
      if (exercise.isSwap) {
        exerciseQueue[exerciseIndex] = exercise.withSwapReason(reason);
      }
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
          originalExerciseName: exercise.originalName,
          swapReason: exercise.swapReason,
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
        if (sets.first.originalExerciseName != null)
          'Swapped from: ${sets.first.originalExerciseName}',
        if (sets.first.swapReason.isNotEmpty)
          'Swap reason: ${sets.first.swapReason}',
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
              selectedReason: selectedSwapReason,
              selectedExerciseName: exercise.name,
              onReasonSelected: _selectSwapReason,
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
    this.originalExerciseName,
    this.swapReason = '',
  });

  final String exerciseName;
  final double weightKg;
  final int reps;
  final String? originalExerciseName;
  final String swapReason;

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
    required this.selectedReason,
    required this.selectedExerciseName,
    required this.onReasonSelected,
    required this.onSelected,
  });

  final List<String> alternatives;
  final String selectedReason;
  final String selectedExerciseName;
  final ValueChanged<String> onReasonSelected;
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
            'Swap exercise',
            style: TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: alternatives.contains(selectedExerciseName)
                ? selectedExerciseName
                : null,
            dropdownColor: const Color(0xFF20283B),
            decoration: const InputDecoration(
              labelText: 'Replacement',
              prefixIcon: Icon(Icons.swap_horiz_rounded),
            ),
            items: [
              for (final alternative in alternatives)
                DropdownMenuItem(value: alternative, child: Text(alternative)),
            ],
            onChanged: (value) {
              if (value == null) return;
              onSelected(value);
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in _swapReasons)
                FilterChip(
                  selected: selectedReason == reason,
                  avatar: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(reason),
                  onSelected: (_) => onReasonSelected(reason),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${items[index].exerciseName} | '
                        '${items[index].summary(index + 1)}',
                        style: const TextStyle(color: Color(0xFFD8E2FF)),
                      ),
                      if (items[index].swapReason.isNotEmpty)
                        Text(
                          'Swap reason: ${items[index].swapReason}',
                          style: const TextStyle(
                            color: Color(0xFF8396C7),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
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
  late _WorkoutExercise selectedExercise;
  double weightKg = 0;
  int reps = 12;
  String timing = '3:2:1';
  String selectedSwapReason = _swapReasons.first;

  @override
  void initState() {
    super.initState();
    selectedExercise = widget.exercise;
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

  void _selectExercise(String name) {
    setState(() {
      selectedExercise = widget.exercise.swappedWith(name, selectedSwapReason);
      reps = int.tryParse(selectedExercise.defaultReps) ?? reps;
    });
  }

  void _selectSwapReason(String reason) {
    setState(() {
      selectedSwapReason = reason;
      if (selectedExercise.isSwap) {
        selectedExercise = selectedExercise.withSwapReason(reason);
      }
    });
  }

  void _addSet() {
    setState(() {
      loggedSets.add(
        _LoggedWorkoutSet(
          exerciseName: selectedExercise.name,
          weightKg: selectedExercise.tracksLoad ? weightKg : 0,
          reps: reps,
          originalExerciseName: selectedExercise.originalName,
          swapReason: selectedExercise.swapReason,
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
      if (selectedExercise.originalName != null)
        'Swapped from: ${selectedExercise.originalName}',
      if (selectedExercise.swapReason.isNotEmpty)
        'Swap reason: ${selectedExercise.swapReason}',
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
        title: '${widget.split.name}: ${selectedExercise.name}',
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
            title: selectedExercise.name,
            subtitle: widget.split.name,
          ),
          if (widget.exercise.alternatives.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SubstituteChips(
              alternatives: widget.exercise.alternatives,
              selectedReason: selectedSwapReason,
              selectedExerciseName: selectedExercise.name,
              onReasonSelected: _selectSwapReason,
              onSelected: _selectExercise,
            ),
          ],
          if (latestProgress != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (selectedExercise.tracksLoad)
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
          if (selectedExercise.tracksLoad) ...[
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
    this.originalName,
    this.swapReason = '',
  });

  final String name;
  final String target;
  final String cue;
  final List<String> alternatives;
  final int defaultSetCount;
  final int defaultRepCount;
  final bool tracksLoad;
  final String? originalName;
  final String swapReason;

  String get defaultSets => '$defaultSetCount';

  String get defaultReps => '$defaultRepCount';

  bool get isSwap => originalName != null;

  _WorkoutExercise swappedWith(String replacementName, String reason) {
    final baseName = originalName ?? name;

    return _WorkoutExercise(
      name: replacementName,
      target: 'Substitute for $baseName',
      cue: cue,
      alternatives: alternatives,
      defaultSetCount: defaultSetCount,
      defaultRepCount: _defaultRepCountForExerciseName(
        replacementName,
        defaultRepCount,
      ),
      tracksLoad: _tracksLoadForExerciseName(replacementName, tracksLoad),
      originalName: baseName,
      swapReason: reason,
    );
  }

  _WorkoutExercise withSwapReason(String reason) {
    return _WorkoutExercise(
      name: name,
      target: target,
      cue: cue,
      alternatives: alternatives,
      defaultSetCount: defaultSetCount,
      defaultRepCount: defaultRepCount,
      tracksLoad: tracksLoad,
      originalName: originalName,
      swapReason: reason,
    );
  }
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
        alternatives: [
          'Chest-supported row',
          'Seated cable row',
          'Machine row',
          'Romanian deadlift',
          'Trap bar deadlift',
        ],
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
        alternatives: [
          'Seated hamstring curl',
          'Cable pull-through',
          'Dumbbell RDL',
        ],
      ),
      _WorkoutExercise(
        name: 'Back extension',
        cue: 'Rounded back, glute focus, control the top squeeze.',
        alternatives: [
          'Hip thrust machine',
          'Dead bug press',
          'Cable pull-through',
          'Dumbbell RDL',
        ],
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
        defaultRepCount: 10,
        tracksLoad: false,
        alternatives: ['Close-grip push ups', 'Triceps pressdown'],
      ),
      _WorkoutExercise(
        name: 'Push ups',
        defaultRepCount: 15,
        tracksLoad: false,
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
        name: 'Knee-to-chest stretch',
        target: '2 sets x 20 seconds each side',
        cue:
            'Pull one knee toward the chest, keep the low back heavy, then try '
            'both knees if it feels good.',
        defaultSetCount: 2,
        defaultRepCount: 20,
        tracksLoad: false,
      ),
      _WorkoutExercise(
        name: 'Cat-cow back mobiliser',
        target: '2 sets x 5 slow reps',
        cue:
            'Move slowly through the spine. Keep it gentle and stop if pain '
            'gets sharper.',
        defaultSetCount: 2,
        defaultRepCount: 5,
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
const _swapReasons = [
  'Lower back pain',
  'Machine busy',
  'Equipment unavailable',
  'Wrist / RSI',
  'Knee discomfort',
  'Shoulder discomfort',
  'Form feels off',
  'Too fatigued',
];

class _StretchRecommendation {
  const _StretchRecommendation({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;
}

class _ExerciseInsightRow {
  const _ExerciseInsightRow({
    required this.exerciseName,
    required this.detail,
    required this.date,
  });

  final String exerciseName;
  final String detail;
  final DateTime date;
}

enum _GymChartMetric {
  smartScore('Smart score', 'Score'),
  estimatedMax('Estimated max', 'Est max'),
  bestWeight('Best weight', 'Kg'),
  sets('Sets completed', 'Sets'),
  reps('Reps completed', 'Reps');

  const _GymChartMetric(this.label, this.shortLabel);

  final String label;
  final String shortLabel;

  double valueFor(_GymProgressPoint point) {
    switch (this) {
      case _GymChartMetric.smartScore:
        return point.smartScore;
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
    required this.splitName,
    required this.exerciseName,
    required this.bestWeightKg,
    required this.bestEstimatedMaxKg,
    required this.volumeLoadKg,
    required this.estimatedCalories,
    required this.sets,
    required this.reps,
  });

  final DateTime date;
  final String splitName;
  final String exerciseName;
  final double bestWeightKg;
  final double bestEstimatedMaxKg;
  final double volumeLoadKg;
  final int estimatedCalories;
  final int sets;
  final int reps;

  double get averageRepsPerSet => sets <= 0 ? 0 : reps / sets;

  bool get hasLoad => bestWeightKg > 0;

  double get performanceValue {
    if (_isBodyweightExerciseName(exerciseName)) {
      return reps + sets * 2;
    }
    if (bestEstimatedMaxKg > 0) return bestEstimatedMaxKg;
    if (volumeLoadKg > 0) return volumeLoadKg;
    return reps.toDouble();
  }

  static _GymProgressLog? fromEntry(PersonalLogEntry entry) {
    final metric = entry.metric.trim();

    if (metric.isEmpty) return null;

    final guided = _parseGuidedMetric(metric);
    final manual = guided ?? _parseManualMetric(metric);

    if (manual == null) return null;

    return _GymProgressLog(
      date: DateTime(entry.date.year, entry.date.month, entry.date.day),
      splitName: _splitNameFromTitle(entry.title),
      exerciseName: _exerciseNameFromTitle(entry.title),
      bestWeightKg: manual.bestWeightKg,
      bestEstimatedMaxKg: manual.bestEstimatedMaxKg,
      volumeLoadKg: manual.volumeLoadKg,
      estimatedCalories: _caloriesForMetric(metric, manual.sets),
      sets: manual.sets,
      reps: manual.reps,
    );
  }
}

class _GymProgressPoint {
  const _GymProgressPoint({
    required this.date,
    required this.smartScore,
    required this.bestWeightKg,
    required this.bestEstimatedMaxKg,
    required this.volumeLoadKg,
    required this.sets,
    required this.reps,
    required this.sessions,
  });

  final DateTime date;
  final double smartScore;
  final double bestWeightKg;
  final double bestEstimatedMaxKg;
  final double volumeLoadKg;
  final int sets;
  final int reps;
  final int sessions;

  double get averageRepsPerSet => sets <= 0 ? 0 : reps / sets;

  static List<_GymProgressPoint> fromLogs(List<_GymProgressLog> logs) {
    final grouped = <DateTime, List<_GymProgressLog>>{};
    final baselines = _performanceBaselines(logs);

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
      final volumeLoad = dayLogs.fold<double>(
        0,
        (total, log) => total + log.volumeLoadKg,
      );
      final sets = dayLogs.fold<int>(0, (total, log) => total + log.sets);
      final reps = dayLogs.fold<int>(0, (total, log) => total + log.reps);
      final smartScore = _averageSmartScore(dayLogs, baselines);

      return _GymProgressPoint(
        date: entry.key,
        smartScore: smartScore,
        bestWeightKg: bestWeight,
        bestEstimatedMaxKg: bestEstimatedMax,
        volumeLoadKg: volumeLoad,
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
    required this.averageSmartScore,
    required this.uniqueExercises,
    required this.sets,
    required this.reps,
    required this.sessions,
    required this.loadedSessions,
  });

  final double bestWeightKg;
  final double bestEstimatedMaxKg;
  final double averageSmartScore;
  final int uniqueExercises;
  final int sets;
  final int reps;
  final int sessions;
  final int loadedSessions;

  double get averageRepsPerSet => sets <= 0 ? 0 : reps / sets;

  double get averageSetsPerSession => sessions <= 0 ? 0 : sets / sessions;

  double get loadedSessionRatio =>
      sessions <= 0 ? 0 : loadedSessions / sessions;

  factory _GymProgressTotals.fromLogs(List<_GymProgressLog> logs) {
    final baselines = _performanceBaselines(logs);

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
      averageSmartScore: _averageSmartScore(logs, baselines),
      uniqueExercises: logs.map((log) => log.exerciseName).toSet().length,
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
    required this.smartScore,
    required this.bestWeightKg,
    required this.bestReps,
    required this.estimatedMaxKg,
  });

  final String exerciseName;
  final DateTime date;
  final double smartScore;
  final double bestWeightKg;
  final int bestReps;
  final double estimatedMaxKg;

  static List<_ExerciseRecord> fromLogs(List<_GymProgressLog> logs) {
    final baselines = _performanceBaselines(logs);
    final bestByExercise = <String, _ExerciseRecord>{};

    for (final log in logs) {
      final smartScore = _smartScoreForLog(log, baselines);

      if (smartScore <= 0 && log.bestEstimatedMaxKg <= 0) continue;

      final current = bestByExercise[log.exerciseName];

      if (current == null ||
          smartScore > current.smartScore ||
          (smartScore == current.smartScore &&
              log.date.isAfter(current.date))) {
        bestByExercise[log.exerciseName] = _ExerciseRecord(
          exerciseName: log.exerciseName,
          date: log.date,
          smartScore: smartScore,
          bestWeightKg: log.bestWeightKg,
          bestReps: log.reps,
          estimatedMaxKg: log.bestEstimatedMaxKg,
        );
      }
    }

    return bestByExercise.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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
    required this.volumeLoadKg,
    required this.sets,
    required this.reps,
  });

  final double bestWeightKg;
  final double bestEstimatedMaxKg;
  final double volumeLoadKg;
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
  var volumeLoadKg = 0.0;
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
    volumeLoadKg += weight * lineReps;
    reps += lineReps;
  }

  return _ParsedGymMetric(
    bestWeightKg: bestWeightKg,
    bestEstimatedMaxKg: bestEstimatedMaxKg,
    volumeLoadKg: volumeLoadKg,
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
    volumeLoadKg: weight * reps,
    sets: sets,
    reps: reps,
  );
}

double _estimatedMaxKg({required double weight, required int reps}) {
  if (weight <= 0 || reps <= 0) return 0;

  return weight * (1 + reps / 30);
}

Map<String, double> _performanceBaselines(List<_GymProgressLog> logs) {
  final baselines = <String, double>{};

  for (final log in logs) {
    final value = log.performanceValue;

    if (value <= 0) continue;

    baselines.update(
      log.exerciseName,
      (current) => value > current ? value : current,
      ifAbsent: () => value,
    );
  }

  return baselines;
}

double _smartScoreForLog(_GymProgressLog log, Map<String, double> baselines) {
  final baseline = baselines[log.exerciseName] ?? 0;
  final value = log.performanceValue;

  if (baseline <= 0 || value <= 0) return 0;

  return (value / baseline * 100).clamp(0.0, 100.0);
}

double _averageSmartScore(
  List<_GymProgressLog> logs,
  Map<String, double> baselines,
) {
  final scores = [
    for (final log in logs)
      if (_smartScoreForLog(log, baselines) > 0)
        _smartScoreForLog(log, baselines),
  ];

  if (scores.isEmpty) return 0;

  return scores.fold<double>(0, (total, score) => total + score) /
      scores.length;
}

List<_GymProgressLog> _logsForSplit(
  _WorkoutSplit split,
  List<PersonalLogEntry> entries,
) {
  final exerciseNames = split.exercises.map((exercise) => exercise.name);

  return entries
      .map((entry) => _GymProgressLog.fromEntry(entry))
      .whereType<_GymProgressLog>()
      .where((log) {
        if (log.splitName == split.name) return true;

        return exerciseNames.any(
          (exerciseName) => _sameExercise(log.exerciseName, exerciseName),
        );
      })
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

List<_ExerciseInsightRow> _exerciseInsightRows(
  _WorkoutSplit split,
  List<_GymProgressLog> logs,
) {
  final rows = <_ExerciseInsightRow>[];

  for (final exercise in split.exercises) {
    final exerciseLogs = logs
        .where((log) => _sameExercise(log.exerciseName, exercise.name))
        .toList();

    if (exerciseLogs.isEmpty) continue;

    final latest = exerciseLogs.last;
    final detail = _isBodyweightExerciseName(latest.exerciseName)
        ? '${latest.reps} reps last'
        : '${_formatCompactNumber(latest.bestWeightKg)} kg last';

    rows.add(
      _ExerciseInsightRow(
        exerciseName: exercise.name,
        detail: detail,
        date: latest.date,
      ),
    );
  }

  return rows..sort((a, b) => b.date.compareTo(a.date));
}

String _splitPrompt(
  _WorkoutSplit split,
  List<_GymProgressLog> logs,
  String leastLoggedExercise,
) {
  if (logs.isEmpty) {
    return 'Prompt: log ${split.exercises.first.name} first so this tab starts tracking each exercise separately.';
  }

  if (split.name == 'Chest + Shoulders') {
    return 'Prompt: log $leastLoggedExercise next. Push ups are scored from reps and sets, so body weight will not skew chest progress.';
  }

  if (split.name == 'Stretch + Abs') {
    return 'Prompt: log the stretch reason and time held so recommendations can match what keeps coming up.';
  }

  return 'Prompt: log $leastLoggedExercise next so this tab does not over-read one exercise.';
}

String _exerciseHistoryDetail(_GymProgressLog log) {
  final base = '${formatDate(log.date)} | ${log.sets} sets | ${log.reps} reps';

  if (_isBodyweightExerciseName(log.exerciseName)) {
    return '$base | bodyweight score ${_formatCompactNumber(log.performanceValue)}';
  }

  return '$base | est max ${_formatCompactNumber(log.bestEstimatedMaxKg)} kg';
}

bool _sameExercise(String left, String right) {
  return _normaliseExerciseName(left) == _normaliseExerciseName(right);
}

String _normaliseExerciseName(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

bool _isBodyweightExerciseName(String exerciseName) {
  final normalised = _normaliseExerciseName(exerciseName);

  return normalised.contains('push up') ||
      normalised.contains('pushup') ||
      normalised == 'dips' ||
      normalised.contains('close grip push') ||
      normalised.contains('incline push');
}

bool _tracksLoadForExerciseName(String exerciseName, bool fallback) {
  final normalised = _normaliseExerciseName(exerciseName);

  if (_isBodyweightExerciseName(exerciseName)) return false;
  if (normalised.contains('machine') ||
      normalised.contains('pressdown') ||
      normalised.contains('dumbbell') ||
      normalised.contains('cable') ||
      normalised.contains('barbell')) {
    return true;
  }

  return fallback;
}

int _defaultRepCountForExerciseName(String exerciseName, int fallback) {
  if (_isBodyweightExerciseName(exerciseName)) return 15;

  return fallback;
}

class _TrainingIntelligence {
  const _TrainingIntelligence({
    required this.overallScore,
    required this.performanceScore,
    required this.consistencyScore,
    required this.varietyScore,
    required this.balanceScore,
    required this.nextNudge,
  });

  final double overallScore;
  final double performanceScore;
  final double consistencyScore;
  final double varietyScore;
  final double balanceScore;
  final String nextNudge;

  factory _TrainingIntelligence.fromLogs(List<_GymProgressLog> logs) {
    final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));
    final latestDate = sorted.last.date;
    final recentStart = latestDate.subtract(const Duration(days: 27));
    final recentLogs = sorted
        .where((log) => !log.date.isBefore(recentStart))
        .toList();
    final baselines = _performanceBaselines(sorted);
    final recentDays = recentLogs.map((log) => log.date).toSet().length;
    final uniqueExercises = recentLogs.map((log) => log.exerciseName).toSet();
    final splitCounts = <String, int>{};

    for (final log in recentLogs) {
      final split = log.splitName.isEmpty ? 'Other' : log.splitName;
      splitCounts.update(split, (value) => value + 1, ifAbsent: () => 1);
    }

    final performanceScore = _averageSmartScore(recentLogs, baselines);
    final consistencyScore = (recentDays / 12 * 100).clamp(0.0, 100.0);
    final varietyScore = (uniqueExercises.length / 8 * 100).clamp(0.0, 100.0);
    final balanceScore = _splitBalanceScore(splitCounts);
    final overallScore =
        performanceScore * 0.35 +
        consistencyScore * 0.25 +
        varietyScore * 0.2 +
        balanceScore * 0.2;

    return _TrainingIntelligence(
      overallScore: overallScore,
      performanceScore: performanceScore,
      consistencyScore: consistencyScore,
      varietyScore: varietyScore,
      balanceScore: balanceScore,
      nextNudge: _trainingNudge(
        splitCounts,
        recentDays,
        uniqueExercises.length,
      ),
    );
  }
}

double _splitBalanceScore(Map<String, int> splitCounts) {
  if (splitCounts.isEmpty) return 0;

  final plannedSplits = _workoutSplits.map((split) => split.name).toList();
  final covered = plannedSplits.where((split) => (splitCounts[split] ?? 0) > 0);
  final total = splitCounts.values.fold<int>(0, (sum, count) => sum + count);
  final busiest = splitCounts.values.fold<int>(
    0,
    (max, count) => count > max ? count : max,
  );
  final coverageScore = covered.length / plannedSplits.length * 100;
  final dominancePenalty = total <= 0 ? 0.0 : busiest / total * 35;

  return (coverageScore - dominancePenalty).clamp(0.0, 100.0);
}

String _trainingNudge(
  Map<String, int> splitCounts,
  int recentDays,
  int uniqueExercises,
) {
  if (recentDays < 3) {
    return 'Next nudge: log three separate training days before chasing bigger numbers.';
  }

  if (uniqueExercises < 5) {
    return 'Next nudge: add more exercise variety so progress is not just one big lift.';
  }

  final plannedSplits = _workoutSplits.map((split) => split.name).toList();
  final leastSplit = plannedSplits.reduce((current, next) {
    final currentCount = splitCounts[current] ?? 0;
    final nextCount = splitCounts[next] ?? 0;
    return nextCount < currentCount ? next : current;
  });

  if ((splitCounts[leastSplit] ?? 0) == 0) {
    return 'Next nudge: hit $leastSplit so the week is more balanced.';
  }

  return 'Next nudge: progress the weakest recent exercise, not just the heaviest compound.';
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

Map<String, int> _swapReasonCounts(List<PersonalLogEntry> entries) {
  final counts = <String, int>{};

  for (final entry in entries) {
    if (entry.category != PersonalLogCategory.gym) continue;

    final content = '${entry.metric}\n${entry.notes}';
    var matched = false;

    for (final match in RegExp(
      r'Swap reason:\s*([^|\n]+)',
      caseSensitive: false,
    ).allMatches(content)) {
      final reason = _normaliseSwapReason(match.group(1) ?? '');

      if (reason.isEmpty) continue;
      counts.update(reason, (value) => value + 1, ifAbsent: () => 1);
      matched = true;
    }

    if (matched) continue;

    final inferredReason = _inferSwapReason(content);

    if (inferredReason.isEmpty) continue;
    counts.update(inferredReason, (value) => value + 1, ifAbsent: () => 1);
  }

  final sorted = counts.entries.toList()
    ..sort((a, b) {
      final countCompare = b.value.compareTo(a.value);

      if (countCompare != 0) return countCompare;
      return a.key.compareTo(b.key);
    });

  return Map<String, int>.fromEntries(sorted);
}

String _swapReasonSignature(List<PersonalLogEntry> entries) {
  final counts = _swapReasonCounts(entries);

  if (counts.isEmpty) return 'none:${entries.length}';

  return counts.entries.map((entry) => '${entry.key}:${entry.value}').join('|');
}

String _normaliseSwapReason(String value) {
  final lower = value.trim().toLowerCase();

  if (lower.isEmpty) return '';
  if (lower.contains('back')) return 'Lower back pain';
  if (lower.contains('rsi') || lower.contains('wrist')) return 'Wrist / RSI';
  if (lower.contains('knee')) return 'Knee discomfort';
  if (lower.contains('shoulder')) return 'Shoulder discomfort';
  if (lower.contains('busy')) return 'Machine busy';
  if (lower.contains('equipment') || lower.contains('taken')) {
    return 'Equipment unavailable';
  }
  if (lower.contains('form')) return 'Form feels off';
  if (lower.contains('fatigue') || lower.contains('tired')) {
    return 'Too fatigued';
  }

  for (final reason in _swapReasons) {
    if (lower == reason.toLowerCase()) return reason;
  }

  return value.trim();
}

String _inferSwapReason(String content) {
  final lower = content.toLowerCase();

  if (lower.contains('lower back') || lower.contains('low back')) {
    return 'Lower back pain';
  }
  if (lower.contains('rsi') || lower.contains('wrist')) return 'Wrist / RSI';
  if (lower.contains('knee')) return 'Knee discomfort';
  if (lower.contains('shoulder')) return 'Shoulder discomfort';
  if (lower.contains('machine busy') || lower.contains('taken')) {
    return 'Machine busy';
  }

  return '';
}

List<_StretchRecommendation> _stretchRecommendationsForReasons(
  Map<String, int> reasonCounts,
) {
  final recommendations = <_StretchRecommendation>[];
  final titles = <String>{};

  void add(_StretchRecommendation recommendation) {
    if (!titles.add(recommendation.title)) return;
    recommendations.add(recommendation);
  }

  if (reasonCounts.isEmpty) {
    add(
      const _StretchRecommendation(
        title: 'Log swap reasons',
        detail: 'Pick a reason when you swap an exercise and this will adapt.',
        icon: Icons.flag_outlined,
      ),
    );
    add(
      const _StretchRecommendation(
        title: 'Lower back reset',
        detail: 'Start with knee-to-chest, cat-cow, then dead bug press.',
        icon: Icons.accessibility_new_rounded,
      ),
    );

    return recommendations;
  }

  for (final reason in reasonCounts.keys.take(3)) {
    switch (reason) {
      case 'Lower back pain':
        add(
          const _StretchRecommendation(
            title: 'Lower back reset',
            detail: 'Knee-to-chest, cat-cow, and dead bug press before abs.',
            icon: Icons.accessibility_new_rounded,
          ),
        );
        add(
          const _StretchRecommendation(
            title: 'Unload the hinge',
            detail: 'Use low lunge hip opener before heavy hinge work.',
            icon: Icons.self_improvement_rounded,
          ),
        );
        break;
      case 'Wrist / RSI':
        add(
          const _StretchRecommendation(
            title: 'Wrist care block',
            detail: 'Do wrist flexor and extensor stretches before floor work.',
            icon: Icons.back_hand_outlined,
          ),
        );
        add(
          const _StretchRecommendation(
            title: 'Forearm-supported core',
            detail: 'Use dead bug or forearm side plank instead of hand loads.',
            icon: Icons.pan_tool_alt_outlined,
          ),
        );
        break;
      case 'Knee discomfort':
        add(
          const _StretchRecommendation(
            title: 'Hip-first warm-up',
            detail: 'Low lunge hip opener, then controlled reverse crunches.',
            icon: Icons.directions_walk_rounded,
          ),
        );
        break;
      case 'Shoulder discomfort':
        add(
          const _StretchRecommendation(
            title: 'Shoulder unload',
            detail:
                'Use wrist-safe sun salutations and shoulder blade squeezes.',
            icon: Icons.fitness_center_rounded,
          ),
        );
        break;
      case 'Machine busy':
      case 'Equipment unavailable':
        add(
          const _StretchRecommendation(
            title: 'Waiting reset',
            detail: 'Do low lunge hip opener or wrist stretches between swaps.',
            icon: Icons.schedule_rounded,
          ),
        );
        break;
      case 'Form feels off':
      case 'Too fatigued':
        add(
          const _StretchRecommendation(
            title: 'Technique reset',
            detail:
                'Use cat-cow, dead bug press, then lighter controlled reps.',
            icon: Icons.psychology_rounded,
          ),
        );
        break;
    }
  }

  if (recommendations.isEmpty) {
    add(
      const _StretchRecommendation(
        title: 'General reset',
        detail: 'Use low lunge hip opener, cat-cow, and dead bug press.',
        icon: Icons.self_improvement_rounded,
      ),
    );
  }

  return recommendations.take(4).toList();
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

String _splitNameFromTitle(String title) {
  final parts = title.split(':');

  if (parts.length <= 1) return '';

  return parts.first.trim();
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
