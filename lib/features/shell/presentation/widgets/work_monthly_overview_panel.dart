import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/utils/formatters.dart';
import '../models/work_month_summary.dart';
import 'work_contact_type_breakdown.dart';
import 'work_month_controls.dart';

class WorkMonthlyOverviewLauncher extends StatelessWidget {
  const WorkMonthlyOverviewLauncher({
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
    final now = DateTime.now();
    final summary = WorkMonthSummary.fromState(
      context.watch<AppState>(),
      DateTime(now.year, now.month),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Material(
        key: const ValueKey('work-monthly-overview-launcher'),
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey('work-monthly-overview-open'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOverview(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF34405F)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F8DF7).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Color(0xFF8CB8FF),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Monthly overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${summary.label} · ${summary.entries} entries · '
                        '${summary.hours.toStringAsFixed(2)}h',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFAFC6F5),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: Color(0xFF8CB8FF),
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showOverview(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB3000000),
      builder: (sheetContext) {
        void closeAndRun(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) => action());
        }

        return FractionallySizedBox(
          heightFactor: 0.92,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF0B101B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 18),
              child: WorkMonthlyOverviewPanel(
                onClose: () => Navigator.of(sheetContext).pop(),
                onWork: () => closeAndRun(onWork),
                onNotes: () => closeAndRun(onNotes),
                onActions: () => closeAndRun(onActions),
                onPayPeriod: () => closeAndRun(onPayPeriod),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WorkMonthlyOverviewPanel extends StatefulWidget {
  const WorkMonthlyOverviewPanel({
    required this.onWork,
    required this.onNotes,
    required this.onActions,
    required this.onPayPeriod,
    this.onClose,
    super.key,
  });

  final VoidCallback onWork;
  final VoidCallback onNotes;
  final VoidCallback onActions;
  final VoidCallback onPayPeriod;
  final VoidCallback? onClose;

  @override
  State<WorkMonthlyOverviewPanel> createState() =>
      _WorkMonthlyOverviewPanelState();
}

class _WorkMonthlyOverviewPanelState extends State<WorkMonthlyOverviewPanel> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month);
  }

  Future<void> _copyTotals(WorkMonthSummary summary) async {
    await Clipboard.setData(ClipboardData(text: summary.readableText));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${summary.label} totals copied')));
  }

  @override
  Widget build(BuildContext context) {
    final summary = WorkMonthSummary.fromState(
      context.watch<AppState>(),
      _selectedMonth,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return _OverviewCard(
          summary: summary,
          maxWidth: constraints.maxWidth,
          onClose: widget.onClose,
          onPreviousMonth: () => _changeMonth(-1),
          onNextMonth: () => _changeMonth(1),
          canGoNext: _canGoNext,
          onCopy: () => _copyTotals(summary),
          onWork: widget.onWork,
          onNotes: widget.onNotes,
          onActions: widget.onActions,
          onPayPeriod: widget.onPayPeriod,
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
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.canGoNext,
    required this.onCopy,
    this.onClose,
  });

  final WorkMonthSummary summary;
  final double maxWidth;
  final VoidCallback onWork;
  final VoidCallback onNotes;
  final VoidCallback onActions;
  final VoidCallback onPayPeriod;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool canGoNext;
  final VoidCallback onCopy;
  final VoidCallback? onClose;

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
          _OverviewHeader(summary: summary, onClose: onClose),
          const SizedBox(height: 13),
          WorkMonthControls(
            label: summary.label,
            onPrevious: onPreviousMonth,
            onNext: onNextMonth,
            onCopy: onCopy,
            canGoNext: canGoNext,
          ),
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
  const _OverviewHeader({required this.summary, this.onClose});

  final WorkMonthSummary summary;
  final VoidCallback? onClose;

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
              const Text(
                'Work monthly overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                summary.label,
                style: const TextStyle(
                  color: Color(0xFFAFC6F5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _CountBadge(count: summary.entries),
        if (onClose != null) ...[
          const SizedBox(width: 4),
          IconButton(
            key: const ValueKey('work-monthly-overview-close'),
            onPressed: onClose,
            tooltip: 'Close monthly overview',
            icon: const Icon(Icons.close_rounded),
            color: const Color(0xFFD8E6FF),
          ),
        ],
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
