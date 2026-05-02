import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/chart_utils.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/review_row.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  late PayPeriodRange selectedRange;

  @override
  void initState() {
    super.initState();
    selectedRange = currentFortnight();
  }

  void showCurrentPeriod() {
    setState(() => selectedRange = currentFortnight());
  }

  void showPreviousPeriod() {
    setState(() => selectedRange = selectedRange.previous);
  }

  void showNextPeriod() {
    setState(() => selectedRange = selectedRange.next);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;

    final periodEntries = entriesInRange(appState.entries, selectedRange);
    final dailyPoints = buildDailyChartPoints(
      entries: periodEntries,
      settings: settings,
      range: selectedRange,
    );
    final typeBreakdown = buildEntryTypeBreakdown(periodEntries);
    final earnings = totalEarnings(periodEntries, settings);
    final average = averageEarningsPerEntry(
      entries: periodEntries,
      settings: settings,
    );
    final bestDay = bestDayByHours(dailyPoints);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Chart Period',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatDate(selectedRange.start)} - ${formatDate(selectedRange.end)}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: showPreviousPeriod,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: showCurrentPeriod,
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Current'),
                  ),
                  OutlinedButton.icon(
                    onPressed: showNextPeriod,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StatGrid(
          cards: [
            StatCard(title: 'Entries', value: '${periodEntries.length}'),
            StatCard(
              title: 'Hours',
              value: totalHours(periodEntries).toStringAsFixed(2),
            ),
            StatCard(title: 'Earned', value: money(earnings)),
            StatCard(
              title: 'KM',
              value: totalKilometres(periodEntries).toStringAsFixed(1),
            ),
            StatCard(
              title: 'Best Day',
              value: bestDay == null
                  ? '-'
                  : '${formatDate(bestDay.date)} - ${bestDay.hours.toStringAsFixed(2)}h',
            ),
            StatCard(title: 'Avg / Entry', value: money(average)),
          ],
        ),
        const SizedBox(height: 16),
        if (periodEntries.isEmpty)
          const SectionCard(
            title: 'Charts',
            child: EmptyState(
              message:
                  'Charts will populate after entries are saved in this period.',
            ),
          )
        else ...[
          SectionCard(
            title: 'Hours by Day',
            child: _DailyBarChart(
              points: dailyPoints,
              valueSelector: (point) => point.hours,
              valueLabel: 'hours',
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Earnings by Day',
            child: _DailyBarChart(
              points: dailyPoints,
              valueSelector: (point) => point.earnings,
              valueLabel: 'earned',
              formatValue: money,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Entry Type Breakdown',
            child: _EntryTypeBreakdownChart(breakdown: typeBreakdown),
          ),
        ],
      ],
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({
    required this.points,
    required this.valueSelector,
    required this.valueLabel,
    this.formatValue,
  });

  final List<DailyChartPoint> points;
  final double Function(DailyChartPoint point) valueSelector;
  final String valueLabel;
  final String Function(double value)? formatValue;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(
      0,
      (currentMax, point) => math.max(currentMax, valueSelector(point)),
    );

    final safeMaxY = maxValue <= 0 ? 1.0 : maxValue * 1.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: safeMaxY,
              gridData: const FlGridData(show: true),
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

                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          points[index].date.day.toString(),
                          style: const TextStyle(fontSize: 10),
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
                        toY: valueSelector(points[index]),
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = points[group.x.toInt()];
                    final rawValue = valueSelector(point);
                    final displayValue = formatValue == null
                        ? rawValue.toStringAsFixed(2)
                        : formatValue!(rawValue);

                    return BarTooltipItem(
                      '${formatDate(point.date)}\n$displayValue',
                      const TextStyle(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bottom labels show day of month. Tap bars to view $valueLabel.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EntryTypeBreakdownChart extends StatelessWidget {
  const _EntryTypeBreakdownChart({required this.breakdown});

  final List<EntryTypeBreakdown> breakdown;

  @override
  Widget build(BuildContext context) {
    final activeBreakdown = breakdown.where((item) => item.count > 0).toList();

    if (activeBreakdown.isEmpty) {
      return const EmptyState(message: 'No entry types in this period.');
    }

    final total = activeBreakdown.fold<int>(0, (sum, item) => sum + item.count);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 36,
              sectionsSpace: 2,
              sections: [
                for (final item in activeBreakdown)
                  PieChartSectionData(
                    value: item.count.toDouble(),
                    title:
                        '${((item.count / total) * 100).toStringAsFixed(0)}%',
                    radius: 72,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in activeBreakdown)
          ReviewRow(label: item.type.label, value: '${item.count}'),
      ],
    );
  }
}
