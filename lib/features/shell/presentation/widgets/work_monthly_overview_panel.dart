import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/utils/formatters.dart';
import '../models/work_month_summary.dart';
import 'work_contact_type_breakdown.dart';

class WorkMonthlyOverviewPanel extends StatelessWidget {
  const WorkMonthlyOverviewPanel({
    required this.onWork,
    required this.onNotes,
    required this.onActions,
    required this.onPayPeriod,
    super.key,
  });

  final VoidCallback onWork;
  final VoidCallback onNotes;
  final VoidCallback onActions;
  final VoidCallback onPayPeriod;

  @override
  Widget build(BuildContext context) {
    final summary = WorkMonthSummary.fromState(
      context.watch<AppState>(),
      DateTime.now(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return _OverviewCard(
          summary: summary,
          maxWidth: constraints.maxWidth,
          onWork: onWork,
          onNotes: onNotes,
          onActions: onActions,
          onPayPeriod: onPayPeriod,
        );
      },
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.summary,
    required this.maxWidth,
    required this.onWork,
    required this.onNotes,
    required this.onActions,
    required this.onPayPeriod,
  });

  final WorkMonthSummary summary;
  final double maxWidth;
  final VoidCallback onWork;
  final VoidCallback onNotes;
  final VoidCallback onActions;
  final VoidCallback onPayPeriod;

  @override
  Widget build(BuildContext context) {
    final compact = maxWidth < 560;
    final contentWidth = maxWidth - 18 - (compact ? 26 : 32);
    final metricWidth = compact
        ? (contentWidth - 8) / 2
        : (contentWidth - 24) / 4;

    return Container(
      key: const ValueKey('work-monthly-overview-panel'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      padding: EdgeInsets.all(compact ? 13 : 16),
      decoration: _panelDecoration(compact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewHeader(summary: summary),
          const SizedBox(height: 13),
          _MonthlyMetrics(summary: summary, metricWidth: metricWidth),
          const SizedBox(height: 13),
          WorkContactTypeBreakdown(entriesByType: summary.entriesByType),
          const SizedBox(height: 13),
          _WorkflowStrip(
            summary: summary,
            onWork: onWork,
            onNotes: onNotes,
            onActions: onActions,
            onPayPeriod: onPayPeriod,
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration(bool compact) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF13294D), Color(0xFF101B32)],
      ),
      borderRadius: BorderRadius.circular(compact ? 18 : 22),
      border: Border.all(color: const Color(0xFF355C9A)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.summary});

  final WorkMonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4F8DF7).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.insights_rounded, color: Color(0xFF8CB8FF)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${summary.label} overview',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Month to date',
                style: TextStyle(
                  color: Color(0xFFAFC6F5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _CountBadge(count: summary.entries),
      ],
    );
  }
}

class _MonthlyMetrics extends StatelessWidget {
  const _MonthlyMetrics({required this.summary, required this.metricWidth});

  final WorkMonthSummary summary;
  final double metricWidth;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MonthlyMetric(
          key: const ValueKey('work-month-stat-entries'),
          width: metricWidth,
          label: 'Entries',
          value: '${summary.entries}',
        ),
        _MonthlyMetric(
          key: const ValueKey('work-month-stat-hours'),
          width: metricWidth,
          label: 'Hours',
          value: '${summary.hours.toStringAsFixed(2)}h',
        ),
        _MonthlyMetric(
          key: const ValueKey('work-month-stat-earned'),
          width: metricWidth,
          label: 'Earned',
          value: money(summary.earned),
        ),
        _MonthlyMetric(
          key: const ValueKey('work-month-stat-kilometres'),
          width: metricWidth,
          label: 'Travel',
          value: '${summary.kilometres.toStringAsFixed(1)}km',
        ),
      ],
    );
  }
}

class _WorkflowStrip extends StatelessWidget {
  const _WorkflowStrip({
    required this.summary,
    required this.onWork,
    required this.onNotes,
    required this.onActions,
    required this.onPayPeriod,
  });

  final WorkMonthSummary summary;
  final VoidCallback onWork;
  final VoidCallback onNotes;
  final VoidCallback onActions;
  final VoidCallback onPayPeriod;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WORK FLOW',
          style: TextStyle(
            color: Color(0xFFAFC6F5),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FlowStep(
                key: const ValueKey('work-flow-log-work'),
                number: 1,
                label: 'Log work',
                detail: 'Start below',
                active: true,
                onTap: onWork,
              ),
              const SizedBox(width: 8),
              _FlowStep(
                key: const ValueKey('work-flow-notes'),
                number: 2,
                label: 'Finish notes',
                detail: summary.notesToFinish == 0
                    ? 'All complete'
                    : '${summary.notesToFinish} to finish',
                onTap: onNotes,
              ),
              const SizedBox(width: 8),
              _FlowStep(
                key: const ValueKey('work-flow-actions'),
                number: 3,
                label: 'Actions',
                detail: summary.openActions == 0
                    ? 'Nothing open'
                    : '${summary.openActions} open',
                onTap: onActions,
              ),
              const SizedBox(width: 8),
              _FlowStep(
                key: const ValueKey('work-flow-pay'),
                number: 4,
                label: 'Review pay',
                detail: 'Invoices',
                onTap: onPayPeriod,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1527),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF355C9A)),
      ),
      child: Text(
        '$count ${count == 1 ? 'entry' : 'entries'}',
        style: const TextStyle(
          color: Color(0xFFD8E6FF),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MonthlyMetric extends StatelessWidget {
  const _MonthlyMetric({
    required this.width,
    required this.label,
    required this.value,
    super.key,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1527).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF294A7C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFAFC6F5),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.number,
    required this.label,
    required this.detail,
    required this.onTap,
    this.active = false,
    super.key,
  });

  final int number;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF31E981) : const Color(0xFF8CB8FF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 142,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0B301D) : const Color(0xFF0B1527),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? const Color(0xFF128A45) : const Color(0xFF294A7C),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFAFC6F5),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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
