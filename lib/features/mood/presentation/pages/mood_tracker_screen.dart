import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/home_screen_shortcut_button.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../data/models/mood_check_in_model.dart';
import '../../domain/entities/mood_check_in.dart';

class MoodTrackerScreen extends StatelessWidget {
  const MoodTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries =
        context
            .watch<AppState>()
            .personalLogEntries
            .map(MoodCheckInModel.fromPersonalLogEntry)
            .whereType<MoodCheckIn>()
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          title: 'Mood Tracker',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TrackerIntro(),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _showCheckInSheet(context),
                icon: const Icon(Icons.add_reaction_outlined),
                label: const Text('Add emotion check-in'),
              ),
              const SizedBox(height: 10),
              const HomeScreenShortcutButton(
                title: 'Mood Tracker',
                mode: 'mood',
                icon: Icons.add_to_home_screen_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Colour-coded pattern chart',
          child: entries.isEmpty
              ? const EmptyState(message: 'Add a check-in to start the chart.')
              : _PatternChart(checkIns: entries),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'What the pattern suggests',
          child: _PatternInsight(checkIns: entries),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Recent check-ins',
          child: entries.isEmpty
              ? const EmptyState(message: 'No emotion check-ins yet.')
              : Column(
                  children: [
                    for (final checkIn in entries.reversed.take(12))
                      _CheckInTile(checkIn: checkIn),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showCheckInSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _MoodCheckInSheet(),
    );
  }
}

class _TrackerIntro extends StatelessWidget {
  const _TrackerIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF13294D), Color(0xFF2A1938)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Track feelings, timing, and context',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Compare emotions with gel timing, dose changes, stress, sleep, '
            'and notable events over time. This is evidence-informed pattern '
            'tracking, but it cannot prove that testosterone caused a feeling.',
            style: TextStyle(
              color: Color(0xFFE6E0F8),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Daily cue scores are custom, not clinically validated. Add PHQ-9 '
            'and GAD-7 totals when available for stronger mood and anxiety '
            'tracking, while keeping the quick daily cues.',
            style: TextStyle(
              color: Color(0xFFE6E0F8),
              height: 1.35,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Use testosterone exactly as prescribed. Contact your prescriber '
            'about significant mood changes; seek urgent help for severe '
            'depression, mania, aggression, hallucinations, or thoughts of '
            'self-harm.',
            style: TextStyle(
              color: Color(0xFFFFC857),
              height: 1.35,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternChart extends StatelessWidget {
  const _PatternChart({required this.checkIns});

  static const emotionalColor = Color(0xFFEC4899);
  static const hormoneColor = Color(0xFFF59E0B);
  static const contextColor = Color(0xFF4F8DF7);

  final List<MoodCheckIn> checkIns;

  @override
  Widget build(BuildContext context) {
    final points = checkIns.length > 14
        ? checkIns.sublist(checkIns.length - 14)
        : checkIns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _ChartLegend(color: emotionalColor, label: 'Emotional load'),
            _ChartLegend(color: hormoneColor, label: 'Gel-timing signal'),
            _ChartLegend(color: contextColor, label: 'Life / context'),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 280,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: 5,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0xFF27324B), strokeWidth: 1),
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
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
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
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final checkIn = points[group.x];
                    final label = switch (rodIndex) {
                      0 => 'Emotional load',
                      1 => 'Gel timing',
                      _ => 'Context',
                    };
                    return BarTooltipItem(
                      '${formatDate(checkIn.date)}\n$label: '
                      '${rod.toY.toStringAsFixed(1)}/5',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var index = 0; index < points.length; index++)
                  BarChartGroupData(
                    x: index,
                    barsSpace: 2,
                    barRods: [
                      _rod(points[index].emotionalLoad, emotionalColor),
                      _rod(points[index].hormoneTimingSignal, hormoneColor),
                      _rod(points[index].contextSignal, contextColor),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BarChartRodData _rod(double value, Color color) {
    return BarChartRodData(
      toY: value.clamp(0, 5),
      width: 7,
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCDD7F0),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PatternInsight extends StatelessWidget {
  const _PatternInsight({required this.checkIns});

  final List<MoodCheckIn> checkIns;

  @override
  Widget build(BuildContext context) {
    final insight = _buildInsight();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: insight.color.withAlpha(28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: insight.color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insight.icon, color: insight.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.body,
                  style: const TextStyle(
                    color: Color(0xFFCDD7F0),
                    height: 1.35,
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

  _Insight _buildInsight() {
    if (checkIns.length < 5) {
      return const _Insight(
        title: 'Not enough history yet',
        body:
            'Add at least five check-ins across different gel timings, sleep '
            'levels, and stress levels. More varied entries make the comparison '
            'more useful.',
        color: Color(0xFF8396C7),
        icon: Icons.hourglass_top_rounded,
      );
    }

    final nearGel = checkIns
        .where(
          (item) =>
              item.gelTiming == GelTiming.after0To4 ||
              item.gelTiming == GelTiming.after4To8,
        )
        .toList();
    final awayFromGel = checkIns
        .where(
          (item) =>
              item.gelTiming == GelTiming.before ||
              item.gelTiming == GelTiming.after16Plus ||
              item.gelTiming == GelTiming.missed,
        )
        .toList();
    final highContext = checkIns
        .where(
          (item) =>
              item.stress >= 3 || item.sleepQuality <= 2 || item.notableEvent,
        )
        .toList();
    final lowContext = checkIns
        .where(
          (item) =>
              item.stress <= 2 && item.sleepQuality >= 3 && !item.notableEvent,
        )
        .toList();
    final gelPattern =
        nearGel.length >= 2 &&
        awayFromGel.length >= 2 &&
        _averageLoad(nearGel) >= _averageLoad(awayFromGel) + 0.75;
    final contextPattern =
        highContext.length >= 2 &&
        lowContext.length >= 2 &&
        _averageLoad(highContext) >= _averageLoad(lowContext) + 0.75;

    if (gelPattern && contextPattern) {
      return const _Insight(
        title: 'Mixed timing and context pattern',
        body:
            'Stronger feelings appear both closer to gel application and on '
            'higher-stress or poorer-sleep days. Keep tracking and discuss the '
            'possible association with your prescriber.',
        color: Color(0xFF8B5CF6),
        icon: Icons.hub_outlined,
      );
    }
    if (gelPattern) {
      return const _Insight(
        title: 'Possible gel-timing pattern',
        body:
            'Emotional load has been higher within eight hours of gel than '
            'before, much later, or on missed days. This is correlation, not '
            'proof of a hormone effect; show the chart to your prescriber.',
        color: Color(0xFFF59E0B),
        icon: Icons.medication_liquid_outlined,
      );
    }
    if (contextPattern) {
      return const _Insight(
        title: 'Stronger life / context pattern',
        body:
            'Emotional load has been higher on stressful, event-heavy, or '
            'poor-sleep days than on lower-context days. Testosterone may '
            'still be relevant, but the current association follows context '
            'more.',
        color: Color(0xFF4F8DF7),
        icon: Icons.psychology_alt_outlined,
      );
    }

    return const _Insight(
      title: 'No clear pattern yet',
      body:
          'The entries do not currently separate into a clear gel-timing or '
          'life/context pattern. Continue consistent check-ins without changing '
          'your prescribed dose based on this chart.',
      color: Color(0xFF31E981),
      icon: Icons.balance_rounded,
    );
  }

  double _averageLoad(List<MoodCheckIn> values) {
    return values.fold<double>(0, (sum, item) => sum + item.emotionalLoad) /
        values.length;
  }
}

class _Insight {
  const _Insight({
    required this.title,
    required this.body,
    required this.color,
    required this.icon,
  });

  final String title;
  final String body;
  final Color color;
  final IconData icon;
}

class _CheckInTile extends StatelessWidget {
  const _CheckInTile({required this.checkIn});

  final MoodCheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final strongest = checkIn.feelings.entries.reduce(
      (current, next) => next.value > current.value ? next : current,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _feelingColor(strongest.key),
            child: Text(
              '${strongest.value}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${strongest.key.label} - ${formatDate(checkIn.date)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${checkIn.gelTiming.label} | stress ${checkIn.stress}/5 | '
                  'sleep ${checkIn.sleepQuality}/5',
                  style: const TextStyle(
                    color: Color(0xFF8396C7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (checkIn.phq9Score != null || checkIn.gad7Score != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      _validatedScoreSummary(checkIn),
                      style: const TextStyle(
                        color: Color(0xFFCDD7F0),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete check-in',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete emotion check-in?'),
        content: const Text('This removes the entry from the chart and logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final entry = context
        .read<AppState>()
        .personalLogEntries
        .where((item) => item.id == checkIn.id)
        .firstOrNull;
    if (entry != null) {
      context.read<AppState>().deletePersonalLogEntry(entry);
    }
  }
}

class _MoodCheckInSheet extends StatefulWidget {
  const _MoodCheckInSheet();

  @override
  State<_MoodCheckInSheet> createState() => _MoodCheckInSheetState();
}

class _MoodCheckInSheetState extends State<_MoodCheckInSheet> {
  GelTiming gelTiming = GelTiming.after0To4;
  bool recentDoseChange = false;
  bool notableEvent = false;
  double stress = 2;
  double sleepQuality = 3;
  final notesController = TextEditingController();
  final phq9Responses = List<int?>.filled(9, null);
  final gad7Responses = List<int?>.filled(7, null);
  final selectedCueIds = <String>{};

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
      child: ListView(
        children: [
          const Text(
            'Emotion check-in',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tick anything that fits right now. The app works out each '
            'feeling level for you. These cues are not a clinical scale.',
            style: TextStyle(color: Color(0xFFCDD7F0)),
          ),
          const SizedBox(height: 16),
          for (final feeling in MoodFeeling.values)
            _FeelingCueGroup(
              feeling: feeling,
              cues: _emotionCues[feeling]!,
              selectedCueIds: selectedCueIds,
              onChanged: (cueId, selected) {
                setState(() {
                  if (selected) {
                    selectedCueIds.add(cueId);
                  } else {
                    selectedCueIds.remove(cueId);
                  }
                });
              },
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GelTiming>(
            initialValue: gelTiming,
            decoration: const InputDecoration(
              labelText: 'Timing compared with today\'s gel',
            ),
            items: [
              for (final timing in GelTiming.values)
                DropdownMenuItem(value: timing, child: Text(timing.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => gelTiming = value);
            },
          ),
          const SizedBox(height: 12),
          _ContextSlider(
            label: 'Stress',
            lowLabel: 'Low',
            highLabel: 'High',
            value: stress,
            onChanged: (value) => setState(() => stress = value),
          ),
          _ContextSlider(
            label: 'Sleep quality',
            lowLabel: 'Poor',
            highLabel: 'Good',
            value: sleepQuality,
            onChanged: (value) => setState(() => sleepQuality = value),
          ),
          SwitchListTile(
            value: recentDoseChange,
            onChanged: (value) => setState(() => recentDoseChange = value),
            title: const Text('Dose changed recently'),
            subtitle: const Text('Include only prescriber-directed changes'),
          ),
          SwitchListTile(
            value: notableEvent,
            onChanged: (value) => setState(() => notableEvent = value),
            title: const Text('Notable emotional event today'),
            subtitle: const Text(
              'Conflict, upsetting news, major stress, etc.',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional: complete PHQ-9 or GAD-7 to add validated low-mood and '
            'anxiety scores. These scores track severity over time, but they '
            'are not a diagnosis by themselves.',
            style: TextStyle(color: Color(0xFFCDD7F0), height: 1.35),
          ),
          const SizedBox(height: 10),
          _ValidatedMeasureSection(
            title: 'PHQ-9 low mood',
            maxScore: 27,
            items: _phq9Items,
            responses: phq9Responses,
            severityLabel: phq9SeverityLabel,
            warningIndex: 8,
            warningText:
                'If this reflects current thoughts of self-harm or danger, '
                'seek urgent help now rather than using the tracker.',
            onChanged: (index, score) {
              setState(() => phq9Responses[index] = score);
            },
          ),
          const SizedBox(height: 10),
          _ValidatedMeasureSection(
            title: 'GAD-7 anxiety',
            maxScore: 21,
            items: _gad7Items,
            responses: gad7Responses,
            severityLabel: gad7SeverityLabel,
            onChanged: (index, score) {
              setState(() => gad7Responses[index] = score);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'What happened? (optional)',
              hintText: 'Trigger, body feeling, thought, or anything unusual',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save check-in'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (selectedCueIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tick at least one emotional cue that fits right now.'),
        ),
      );
      return;
    }
    if (_isPartialMeasure(phq9Responses)) {
      _showMeasureError('PHQ-9');
      return;
    }
    if (_isPartialMeasure(gad7Responses)) {
      _showMeasureError('GAD-7');
      return;
    }

    final checkIn = MoodCheckIn(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      gelTiming: gelTiming,
      recentDoseChange: recentDoseChange,
      stress: stress.round(),
      sleepQuality: sleepQuality.round(),
      notableEvent: notableEvent,
      feelings: {
        for (final feeling in MoodFeeling.values)
          feeling: moodScoreFromCueCount(
            _emotionCues[feeling]!
                .where((cue) => selectedCueIds.contains(cue.id))
                .length,
          ),
      },
      notes: notesController.text.trim(),
      phq9Score: _completedMeasureScore(phq9Responses),
      gad7Score: _completedMeasureScore(gad7Responses),
    );
    context.read<AppState>().addPersonalLogEntry(
      MoodCheckInModel(checkIn).toPersonalLogEntry(),
    );
    Navigator.of(context).pop();
  }

  bool _isPartialMeasure(List<int?> responses) {
    final answered = responses.whereType<int>().length;
    return answered > 0 && answered < responses.length;
  }

  int? _completedMeasureScore(List<int?> responses) {
    if (responses.every((score) => score == null)) return null;
    return responses.whereType<int>().fold<int>(0, (sum, score) => sum + score);
  }

  void _showMeasureError(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Finish every $label item or leave it blank.')),
    );
  }
}

class _FeelingCueGroup extends StatelessWidget {
  const _FeelingCueGroup({
    required this.feeling,
    required this.cues,
    required this.selectedCueIds,
    required this.onChanged,
  });

  final MoodFeeling feeling;
  final List<_EmotionCue> cues;
  final Set<String> selectedCueIds;
  final void Function(String cueId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final color = _feelingColor(feeling);
    final selectedCount = cues
        .where((cue) => selectedCueIds.contains(cue.id))
        .length;
    final score = moodScoreFromCueCount(selectedCount);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(120)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: color,
        collapsedIconColor: color,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(
          feeling.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          selectedCount == 0
              ? 'Tap to see cues'
              : '$selectedCount cue${selectedCount == 1 ? '' : 's'} selected',
          style: const TextStyle(color: Color(0xFFB7C4E2)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: color.withAlpha(150)),
              ),
              child: Text(
                moodScoreLabel(score),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, color: color),
          ],
        ),
        children: [
          for (final cue in cues)
            CheckboxListTile(
              value: selectedCueIds.contains(cue.id),
              onChanged: (value) => onChanged(cue.id, value ?? false),
              activeColor: color,
              checkColor: const Color(0xFF07111F),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              dense: true,
              title: Text(
                cue.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmotionCue {
  const _EmotionCue({required this.id, required this.label});

  final String id;
  final String label;
}

class _ValidatedMeasureSection extends StatelessWidget {
  const _ValidatedMeasureSection({
    required this.title,
    required this.maxScore,
    required this.items,
    required this.responses,
    required this.severityLabel,
    required this.onChanged,
    this.warningIndex,
    this.warningText,
  });

  final String title;
  final int maxScore;
  final List<String> items;
  final List<int?> responses;
  final String Function(int?) severityLabel;
  final void Function(int index, int? score) onChanged;
  final int? warningIndex;
  final String? warningText;

  @override
  Widget build(BuildContext context) {
    final answered = responses.whereType<int>().length;
    final complete = answered == responses.length;
    final score = complete
        ? responses.whereType<int>().fold(0, (sum, value) => sum + value)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          _measureSubtitle(answered, responses.length, score, maxScore),
          style: const TextStyle(color: Color(0xFFB7C4E2)),
        ),
        trailing: score == null
            ? const Icon(Icons.expand_more)
            : Text(
                '${severityLabel(score)} $score/$maxScore',
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'Over the last two weeks, select how often each has bothered '
              'you.',
              style: TextStyle(color: Color(0xFFCDD7F0), height: 1.35),
            ),
          ),
          for (var index = 0; index < items.length; index++)
            _ValidatedMeasureItem(
              number: index + 1,
              label: items[index],
              value: responses[index],
              onChanged: (score) => onChanged(index, score),
            ),
          if (warningIndex != null &&
              warningText != null &&
              (responses[warningIndex!] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                warningText!,
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _measureSubtitle(
    int answered,
    int totalItems,
    int? score,
    int maxScore,
  ) {
    if (score != null) return 'Score $score/$maxScore';
    if (answered == 0) return 'Optional - not completed';
    return '$answered of $totalItems answered';
  }
}

class _ValidatedMeasureItem extends StatelessWidget {
  const _ValidatedMeasureItem({
    required this.number,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final int number;
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $label',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in _measureOptions)
                ChoiceChip(
                  label: Text(option.label),
                  selected: value == option.score,
                  onSelected: (selected) {
                    onChanged(selected ? option.score : null);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeasureOption {
  const _MeasureOption(this.score, this.label);

  final int score;
  final String label;
}

const _measureOptions = [
  _MeasureOption(0, '0 Not at all'),
  _MeasureOption(1, '1 Several days'),
  _MeasureOption(2, '2 Half+ days'),
  _MeasureOption(3, '3 Nearly daily'),
];

const _phq9Items = [
  'Little interest or pleasure in doing things',
  'Feeling down, depressed, or hopeless',
  'Trouble falling or staying asleep, or sleeping too much',
  'Feeling tired or having little energy',
  'Poor appetite or overeating',
  'Feeling bad about yourself or that you have let people down',
  'Trouble concentrating on things',
  'Moving or speaking slowly, or being fidgety and restless',
  'Thoughts of being better off dead or hurting yourself',
];

const _gad7Items = [
  'Feeling nervous, anxious, or on edge',
  'Not being able to stop or control worrying',
  'Worrying too much about different things',
  'Trouble relaxing',
  'Being so restless that it is hard to sit still',
  'Becoming easily annoyed or irritable',
  'Feeling afraid as if something awful might happen',
];

const _emotionCues = <MoodFeeling, List<_EmotionCue>>{
  MoodFeeling.calm: [
    _EmotionCue(id: 'calm_body', label: 'My body feels relaxed'),
    _EmotionCue(id: 'calm_thoughts', label: 'My thoughts feel steady'),
    _EmotionCue(id: 'calm_patient', label: 'I feel patient with people'),
    _EmotionCue(id: 'calm_settled', label: 'I can settle without much effort'),
    _EmotionCue(
      id: 'calm_unbothered',
      label: 'Small things are not bothering me',
    ),
  ],
  MoodFeeling.upbeat: [
    _EmotionCue(id: 'upbeat_enjoying', label: 'I am enjoying things'),
    _EmotionCue(id: 'upbeat_positive', label: 'I feel positive or hopeful'),
    _EmotionCue(id: 'upbeat_smiling', label: 'I am smiling or laughing more'),
    _EmotionCue(id: 'upbeat_social', label: 'I want to connect with people'),
    _EmotionCue(id: 'upbeat_natural', label: 'My good mood feels natural'),
  ],
  MoodFeeling.energised: [
    _EmotionCue(id: 'energy_tasks', label: 'I feel ready to get things done'),
    _EmotionCue(id: 'energy_awake', label: 'I feel awake rather than tired'),
    _EmotionCue(id: 'energy_active', label: 'My body feels switched on'),
    _EmotionCue(id: 'energy_motivated', label: 'I feel more motivated'),
    _EmotionCue(id: 'energy_high', label: 'My energy is higher than usual'),
  ],
  MoodFeeling.irritable: [
    _EmotionCue(id: 'irritable_small', label: 'Small things are annoying me'),
    _EmotionCue(id: 'irritable_temper', label: 'My temper feels shorter'),
    _EmotionCue(id: 'irritable_snap', label: 'I am responding sharply'),
    _EmotionCue(
      id: 'irritable_body',
      label: 'Anger or frustration is in my body',
    ),
    _EmotionCue(id: 'irritable_stuck', label: 'It is hard to let things go'),
  ],
  MoodFeeling.anxious: [
    _EmotionCue(id: 'anxious_racing', label: 'My thoughts are racing'),
    _EmotionCue(id: 'anxious_edge', label: 'I feel tense or on edge'),
    _EmotionCue(id: 'anxious_settle', label: 'I am finding it hard to settle'),
    _EmotionCue(id: 'anxious_worry', label: 'I am worrying more than usual'),
    _EmotionCue(
      id: 'anxious_body',
      label: 'My body feels keyed up or restless',
    ),
  ],
  MoodFeeling.low: [
    _EmotionCue(id: 'low_interest', label: 'I have less interest in things'),
    _EmotionCue(id: 'low_heavy', label: 'I feel sad or emotionally heavy'),
    _EmotionCue(id: 'low_motivation', label: 'My motivation feels low'),
    _EmotionCue(id: 'low_withdrawn', label: 'I want to withdraw from people'),
    _EmotionCue(id: 'low_harder', label: 'Everything feels harder than usual'),
  ],
  MoodFeeling.sensitive: [
    _EmotionCue(id: 'sensitive_tears', label: 'I feel tearful more easily'),
    _EmotionCue(id: 'sensitive_criticism', label: 'Criticism hits me harder'),
    _EmotionCue(id: 'sensitive_change', label: 'My emotions change quickly'),
    _EmotionCue(
      id: 'sensitive_overwhelmed',
      label: 'I feel easily overwhelmed',
    ),
    _EmotionCue(id: 'sensitive_reassurance', label: 'I need more reassurance'),
  ],
};

class _ContextSlider extends StatelessWidget {
  const _ContextSlider({
    required this.label,
    required this.lowLabel,
    required this.highLabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String lowLabel;
  final String highLabel;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.round()}/5',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        Slider(
          value: value,
          min: 0,
          max: 5,
          divisions: 5,
          label: '${value.round()}',
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lowLabel, style: const TextStyle(color: Color(0xFF8396C7))),
            Text(highLabel, style: const TextStyle(color: Color(0xFF8396C7))),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

Color _feelingColor(MoodFeeling feeling) {
  return switch (feeling) {
    MoodFeeling.calm => const Color(0xFF31E981),
    MoodFeeling.upbeat => const Color(0xFFFFC857),
    MoodFeeling.energised => const Color(0xFF22D3EE),
    MoodFeeling.irritable => const Color(0xFFEF4444),
    MoodFeeling.anxious => const Color(0xFFF97316),
    MoodFeeling.low => const Color(0xFF6366F1),
    MoodFeeling.sensitive => const Color(0xFFEC4899),
  };
}

String _validatedScoreSummary(MoodCheckIn checkIn) {
  final scores = <String>[
    if (checkIn.phq9Score != null)
      'PHQ-9 ${checkIn.phq9Score}/27 ${phq9SeverityLabel(checkIn.phq9Score)}',
    if (checkIn.gad7Score != null)
      'GAD-7 ${checkIn.gad7Score}/21 ${gad7SeverityLabel(checkIn.gad7Score)}',
  ];
  return scores.join(' | ');
}
