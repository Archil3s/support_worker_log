import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/entry_type.dart';
import '../../core/models/work_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pay_period_utils.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/review_row.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onQuickEntry,
    required this.onPayPeriod,
    required this.onEntries,
  });

  final VoidCallback onQuickEntry;
  final VoidCallback onPayPeriod;
  final VoidCallback onEntries;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final entries = appState.entries;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final weekStart = todayOnly.subtract(Duration(days: todayOnly.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final todayEntries = entriesBetween(entries, todayOnly, todayOnly);
    final weekEntries = entriesBetween(entries, weekStart, weekEnd);

    final currentRange = currentFortnight(
      anchorDate: settings.payPeriodAnchorDate,
    );
    final previousRange = currentRange.previous;

    final periodEntries = entriesInRange(entries, currentRange);
    final previousEntries = entriesInRange(entries, previousRange);

    final weekOneEntries = entriesBetween(
      entries,
      currentRange.weekOneStart,
      currentRange.weekOneEnd,
    );
    final weekTwoEntries = entriesBetween(
      entries,
      currentRange.weekTwoStart,
      currentRange.weekTwoEnd,
    );

    final clientSummaries = _clientSummaries(periodEntries, settings);
    final typeSummaries = _typeSummaries(periodEntries);
    final noteSummaries = _noteSummaries(periodEntries);
    final warnings = _warnings(entries);

    final weeklyHours = totalHours(weekEntries);
    final weeklyGoal = settings.weeklyHoursGoal <= 0
        ? 10.0
        : settings.weeklyHoursGoal;
    final weeklyRemaining = math.max(0.0, weeklyGoal - weeklyHours);
    final daysLeft = math.max(1, weekEnd.difference(todayOnly).inDays + 1);
    final dailyPaceNeeded = weeklyRemaining / daysLeft;

    final periodHours = totalHours(periodEntries);
    final periodEarnings = totalEarnings(periodEntries, settings);
    final periodKm = totalKilometres(periodEntries);
    final periodFuel = _totalFuel(periodEntries, settings);

    final previousHours = totalHours(previousEntries);
    final previousEarnings = totalEarnings(previousEntries, settings);
    final previousKm = totalKilometres(previousEntries);

    final lastEntry = _latestEntry(entries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          title: 'Today',
          child: StatGrid(
            cards: [
              StatCard(title: 'Entries', value: '${todayEntries.length}'),
              StatCard(
                title: 'Hours',
                value: totalHours(todayEntries).toStringAsFixed(2),
              ),
              StatCard(
                title: 'Earned',
                value: money(totalEarnings(todayEntries, settings)),
              ),
              StatCard(
                title: 'KM',
                value: totalKilometres(todayEntries).toStringAsFixed(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'This Week Goal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GoalProgress(
                label: 'Weekly hours',
                current: weeklyHours,
                goal: weeklyGoal,
                suffix: 'h',
              ),
              const SizedBox(height: 12),
              ReviewRow(
                label: 'Remaining',
                value: '${weeklyRemaining.toStringAsFixed(2)}h',
              ),
              ReviewRow(
                label: 'Need per day',
                value: '${dailyPaceNeeded.toStringAsFixed(2)}h',
              ),
              ReviewRow(
                label: 'Week',
                value: '${formatDate(weekStart)} - ${formatDate(weekEnd)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Current Fortnight',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatDate(currentRange.start)} - ${formatDate(currentRange.end)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              StatGrid(
                cards: [
                  StatCard(title: 'Entries', value: '${periodEntries.length}'),
                  StatCard(
                    title: 'Hours',
                    value: periodHours.toStringAsFixed(2),
                  ),
                  StatCard(title: 'Earned', value: money(periodEarnings)),
                  StatCard(title: 'KM', value: periodKm.toStringAsFixed(1)),
                  StatCard(title: 'Fuel', value: money(periodFuel)),
                  StatCard(
                    title: 'Avg / Entry',
                    value: periodEntries.isEmpty
                        ? money(0)
                        : money(periodEarnings / periodEntries.length),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Fortnight Trend',
          child: Column(
            children: [
              ReviewRow(
                label: 'Entries vs previous',
                value: _signedNumber(
                  periodEntries.length - previousEntries.length,
                ),
              ),
              ReviewRow(
                label: 'Hours vs previous',
                value: _signedDecimal(periodHours - previousHours, suffix: 'h'),
              ),
              ReviewRow(
                label: 'Earnings vs previous',
                value: _signedMoney(periodEarnings - previousEarnings),
              ),
              ReviewRow(
                label: 'KM vs previous',
                value: _signedDecimal(periodKm - previousKm, suffix: 'km'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Fortnight Weekly Split',
          child: Column(
            children: [
              _GoalProgress(
                label: 'Week 1 hours',
                current: totalHours(weekOneEntries),
                goal: weeklyGoal,
                suffix: 'h',
              ),
              const SizedBox(height: 12),
              _GoalProgress(
                label: 'Week 2 hours',
                current: totalHours(weekTwoEntries),
                goal: weeklyGoal,
                suffix: 'h',
              ),
              const SizedBox(height: 12),
              _GoalProgress(
                label: 'Week 1 earnings',
                current: totalEarnings(weekOneEntries, settings),
                goal: settings.weeklyEarningsGoal,
                moneyValue: true,
              ),
              const SizedBox(height: 12),
              _GoalProgress(
                label: 'Week 2 earnings',
                current: totalEarnings(weekTwoEntries, settings),
                goal: settings.weeklyEarningsGoal,
                moneyValue: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Client Analytics',
          child: clientSummaries.isEmpty
              ? const EmptyState(
                  message: 'Client analytics appear after entries are saved.',
                )
              : Column(
                  children: [
                    for (final item in clientSummaries)
                      ReviewRow(
                        label: item.client,
                        value:
                            '${item.hours.toStringAsFixed(2)}h • ${item.kilometres.toStringAsFixed(1)}km • ${money(item.earnings)}',
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Support Type Analytics',
          child: typeSummaries.isEmpty
              ? const EmptyState(message: 'No support types yet.')
              : Column(
                  children: [
                    for (final item in typeSummaries)
                      ReviewRow(
                        label: item.type.label,
                        value:
                            '${item.count} entries • ${item.hours.toStringAsFixed(2)}h',
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Most Used Notes',
          child: noteSummaries.isEmpty
              ? const EmptyState(message: 'No note chips used yet.')
              : Column(
                  children: [
                    for (final item in noteSummaries.take(8))
                      ReviewRow(label: item.note, value: '${item.count}x'),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Data Check',
          child: warnings.isEmpty
              ? const ReviewRow(label: 'Status', value: 'No warnings')
              : Column(
                  children: [
                    for (final warning in warnings)
                      ReviewRow(label: warning.label, value: warning.value),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Quick Actions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onQuickEntry,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Start / Finish Visit'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: onPayPeriod,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('View Pay Period'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onEntries,
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('View Entries'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Last Entry',
          child: lastEntry == null
              ? const EmptyState(
                  message: 'No entries yet. Use Quick Entry to start logging.',
                )
              : _LastEntryCard(entry: lastEntry),
        ),
      ],
    );
  }

  WorkEntry? _latestEntry(List<WorkEntry> entries) {
    if (entries.isEmpty) return null;

    final sorted = entries.toList()
      ..sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;

        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return bMinutes.compareTo(aMinutes);
      });

    return sorted.first;
  }

  double _totalFuel(List<WorkEntry> entries, AppSettings settings) {
    return entries.fold<double>(
      0,
      (sum, entry) => sum + entry.fuelReimbursement(settings),
    );
  }

  List<_ClientSummary> _clientSummaries(
    List<WorkEntry> entries,
    AppSettings settings,
  ) {
    final map = <String, _ClientSummary>{};

    for (final entry in entries) {
      final current =
          map[entry.client] ??
          _ClientSummary(
            client: entry.client,
            count: 0,
            hours: 0,
            kilometres: 0,
            earnings: 0,
          );

      map[entry.client] = current.copyWith(
        count: current.count + 1,
        hours: current.hours + entry.hours,
        kilometres: current.kilometres + entry.kilometres,
        earnings: current.earnings + entry.earnings(settings),
      );
    }

    final summaries = map.values.toList()
      ..sort((a, b) => b.hours.compareTo(a.hours));

    return summaries;
  }

  List<_TypeSummary> _typeSummaries(List<WorkEntry> entries) {
    final map = <EntryType, _TypeSummary>{};

    for (final entry in entries) {
      final current =
          map[entry.type] ?? _TypeSummary(type: entry.type, count: 0, hours: 0);

      map[entry.type] = current.copyWith(
        count: current.count + 1,
        hours: current.hours + entry.hours,
      );
    }

    final summaries = map.values.toList()
      ..sort((a, b) => b.hours.compareTo(a.hours));

    return summaries;
  }

  List<_NoteSummary> _noteSummaries(List<WorkEntry> entries) {
    final counts = <String, int>{};

    for (final entry in entries) {
      for (final note in entry.notes) {
        final clean = note.trim();
        if (clean.isEmpty) continue;

        counts[clean] = (counts[clean] ?? 0) + 1;
      }
    }

    final summaries = [
      for (final item in counts.entries)
        _NoteSummary(note: item.key, count: item.value),
    ]..sort((a, b) => b.count.compareTo(a.count));

    return summaries;
  }

  List<_WarningSummary> _warnings(List<WorkEntry> entries) {
    final now = DateTime.now();
    final warnings = <_WarningSummary>[];

    final missingFinishOdo = entries
        .where(
          (entry) =>
              entry.type == EntryType.homeVisit && entry.odometerEnd == null,
        )
        .length;

    final longShifts = entries.where((entry) => entry.minutes > 480).length;

    final futureEntries = entries.where((entry) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final today = DateTime(now.year, now.month, now.day);
      return day.isAfter(today);
    }).length;

    if (missingFinishOdo > 0) {
      warnings.add(
        _WarningSummary(
          label: 'Missing finish odo',
          value: '$missingFinishOdo entries',
        ),
      );
    }

    if (longShifts > 0) {
      warnings.add(
        _WarningSummary(label: 'Long shifts', value: '$longShifts over 8h'),
      );
    }

    if (futureEntries > 0) {
      warnings.add(
        _WarningSummary(label: 'Future dates', value: '$futureEntries entries'),
      );
    }

    return warnings;
  }

  String _signedNumber(int value) {
    if (value > 0) return '+$value';
    return value.toString();
  }

  String _signedDecimal(double value, {required String suffix}) {
    final text = value.toStringAsFixed(2);
    if (value > 0) return '+$text $suffix';
    return '$text $suffix';
  }

  String _signedMoney(double value) {
    if (value > 0) return '+${money(value)}';
    return value < 0 ? '-${money(value.abs())}' : money(value);
  }
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({
    required this.label,
    required this.current,
    required this.goal,
    this.suffix = '',
    this.moneyValue = false,
  });

  final String label;
  final double current;
  final double goal;
  final String suffix;
  final bool moneyValue;

  @override
  Widget build(BuildContext context) {
    final safeGoal = goal <= 0 ? 1.0 : goal;
    final progress = (current / safeGoal).clamp(0.0, 1.0);
    final currentText = moneyValue
        ? money(current)
        : '${current.toStringAsFixed(2)}$suffix';
    final goalText = moneyValue
        ? money(goal)
        : '${goal.toStringAsFixed(2)}$suffix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReviewRow(label: label, value: '$currentText / $goalText'),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress, minHeight: 8),
        ),
      ],
    );
  }
}

class _LastEntryCard extends StatelessWidget {
  const _LastEntryCard({required this.entry});

  final WorkEntry entry;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(entry.type.icon)),
          title: Text(entry.client),
          subtitle: Text(
            '${entry.type.label} • ${formatDate(entry.date)} • ${formatTime(entry.startTime)} • ${entry.minutes} min',
          ),
          trailing: Text(money(entry.earnings(settings))),
        ),
        if (entry.notes.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final note in entry.notes)
                Chip(label: Text(note), visualDensity: VisualDensity.compact),
            ],
          ),
      ],
    );
  }
}

class _ClientSummary {
  const _ClientSummary({
    required this.client,
    required this.count,
    required this.hours,
    required this.kilometres,
    required this.earnings,
  });

  final String client;
  final int count;
  final double hours;
  final double kilometres;
  final double earnings;

  _ClientSummary copyWith({
    int? count,
    double? hours,
    double? kilometres,
    double? earnings,
  }) {
    return _ClientSummary(
      client: client,
      count: count ?? this.count,
      hours: hours ?? this.hours,
      kilometres: kilometres ?? this.kilometres,
      earnings: earnings ?? this.earnings,
    );
  }
}

class _TypeSummary {
  const _TypeSummary({
    required this.type,
    required this.count,
    required this.hours,
  });

  final EntryType type;
  final int count;
  final double hours;

  _TypeSummary copyWith({int? count, double? hours}) {
    return _TypeSummary(
      type: type,
      count: count ?? this.count,
      hours: hours ?? this.hours,
    );
  }
}

class _NoteSummary {
  const _NoteSummary({required this.note, required this.count});

  final String note;
  final int count;
}

class _WarningSummary {
  const _WarningSummary({required this.label, required this.value});

  final String label;
  final String value;
}
