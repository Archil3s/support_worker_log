import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/google_calendar_event.dart';
import '../../core/models/work_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/totals.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/review_row.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

enum _CalendarMode { day, week, month }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDate = _dateOnly(DateTime.now());
  _CalendarMode mode = _CalendarMode.week;
  List<GoogleCalendarEvent> googleEvents = const [];

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  void _selectDate(DateTime value) {
    setState(() => selectedDate = _dateOnly(value));
  }

  void _goToday() {
    setState(() => selectedDate = _dateOnly(DateTime.now()));
  }

  void _goPrevious() {
    setState(() {
      selectedDate = switch (mode) {
        _CalendarMode.day => selectedDate.subtract(const Duration(days: 1)),
        _CalendarMode.week => selectedDate.subtract(const Duration(days: 7)),
        _CalendarMode.month => DateTime(
          selectedDate.year,
          selectedDate.month - 1,
          selectedDate.day,
        ),
      };
    });
  }

  void _goNext() {
    setState(() {
      selectedDate = switch (mode) {
        _CalendarMode.day => selectedDate.add(const Duration(days: 1)),
        _CalendarMode.week => selectedDate.add(const Duration(days: 7)),
        _CalendarMode.month => DateTime(
          selectedDate.year,
          selectedDate.month + 1,
          selectedDate.day,
        ),
      };
    });
  }

  List<DateTime> _visibleDays() {
    switch (mode) {
      case _CalendarMode.day:
        return [selectedDate];
      case _CalendarMode.week:
        final start = selectedDate.subtract(
          Duration(days: selectedDate.weekday - 1),
        );

        return List.generate(7, (index) => start.add(Duration(days: index)));
      case _CalendarMode.month:
        final first = DateTime(selectedDate.year, selectedDate.month);
        final last = DateTime(selectedDate.year, selectedDate.month + 1, 0);

        return List.generate(
          last.day,
          (index) => DateTime(first.year, first.month, index + 1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = appState.entries;
    final settings = appState.settings;
    final payeMode = appState.isPayeMode;
    final days = _visibleDays();
    final visibleEntries = _entriesForDays(entries, days);
    final selectedEntries = _entriesForDay(entries, selectedDate);
    final selectedGoogleEvents = _googleEventsForDay(
      googleEvents,
      selectedDate,
    );
    final selectedOverlapIds = _overlapEntryIds(selectedEntries);
    final selectedGoogleConflictIds = _googleConflictEntryIds(
      selectedEntries,
      selectedGoogleEvents,
    );
    final incompleteNotes = entries
        .where((entry) => entry.supportNoteBreakdown.trim().isEmpty)
        .length;
    final openActions = entries.fold<int>(
      0,
      (count, entry) =>
          count + entry.nextActions.where((item) => !item.isCompleted).length,
    );
    final notCalendared = entries
        .where((entry) => !entry.googleCalendarEntered)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          title: 'Notes & Calendar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_CalendarMode>(
                segments: const [
                  ButtonSegment<_CalendarMode>(
                    value: _CalendarMode.day,
                    icon: Icon(Icons.today_outlined),
                    label: Text('Day'),
                  ),
                  ButtonSegment<_CalendarMode>(
                    value: _CalendarMode.week,
                    icon: Icon(Icons.view_week_outlined),
                    label: Text('Week'),
                  ),
                  ButtonSegment<_CalendarMode>(
                    value: _CalendarMode.month,
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text('Month'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (values) {
                  setState(() => mode = values.first);
                },
              ),
              const SizedBox(height: 12),
              Text(
                _rangeLabel(days),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _goPrevious,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _goToday,
                      icon: const Icon(Icons.my_location_outlined),
                      label: const Text('Today'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _goNext,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StatGrid(
          cards: [
            StatCard(title: 'Entries', value: '${visibleEntries.length}'),
            StatCard(
              title: 'Hours',
              value: totalHours(visibleEntries).toStringAsFixed(2),
            ),
            if (!payeMode)
              StatCard(
                title: 'Earned',
                value: money(totalEarnings(visibleEntries, settings)),
              ),
            if (!payeMode)
              StatCard(
                title: 'KM',
                value: totalKilometres(visibleEntries).toStringAsFixed(1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Needs Attention',
          child: Column(
            children: [
              ReviewRow(label: 'Missing notes', value: '$incompleteNotes'),
              ReviewRow(label: 'Open next actions', value: '$openActions'),
              ReviewRow(label: 'Not in calendar', value: '$notCalendared'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: mode == _CalendarMode.month ? 'Month Map' : 'Day Strip',
          child: _CalendarDayGrid(
            days: days,
            selectedDate: selectedDate,
            entries: entries,
            googleEvents: googleEvents,
            onSelected: _selectDate,
          ),
        ),
        const SizedBox(height: 12),
        const SectionCard(
          title: 'Google Calendar',
          child: _GoogleCalendarPanel(),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Selected Day',
          child: _SelectedDaySummary(
            date: selectedDate,
            entries: selectedEntries,
            overlapCount: selectedOverlapIds.length,
            googleConflictCount: selectedGoogleConflictIds.length,
          ),
        ),
        const SizedBox(height: 12),
        if (selectedEntries.isEmpty)
          const SectionCard(
            title: 'Visits',
            child: EmptyState(message: 'No entries for this day.'),
          )
        else
          for (final entry in selectedEntries) ...[
            _CalendarEntryCard(
              entry: entry,
              hasOverlap: selectedOverlapIds.contains(entry.id),
              hasGoogleConflict: selectedGoogleConflictIds.contains(entry.id),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

String _calendarErrorText(Object error) {
  final text = error.toString().trim();

  if (text.startsWith('Bad state: ')) {
    return text.replaceFirst('Bad state: ', '').trim();
  }

  if (text.startsWith("Instance of 'minified:")) {
    return 'Google Calendar sync failed. Reconnect Google, then try Sync Google again.';
  }

  if (_needsGoogleReconnect(text)) {
    return 'Google needs Calendar permission. Reconnect Calendar + Drive, allow Calendar access, then sync again.';
  }

  return text.isEmpty ? 'Google Calendar sync failed.' : text;
}

bool _needsGoogleReconnect(String? error) {
  final text = (error ?? '').toLowerCase();

  return text.contains('insufficient authentication scopes') ||
      text.contains('insufficient permission') ||
      text.contains('calendar permission') ||
      text.contains('reconnect calendar') ||
      text.contains('calendar scope');
}

class _CalendarDayGrid extends StatelessWidget {
  const _CalendarDayGrid({
    required this.days,
    required this.selectedDate,
    required this.entries,
    required this.googleEvents,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final List<WorkEntry> entries;
  final List<GoogleCalendarEvent> googleEvents;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final day in days)
          _DayButton(
            day: day,
            selected: _sameDate(day, selectedDate),
            entries: _entriesForDay(entries, day),
            googleEvents: _googleEventsForDay(googleEvents, day),
            onTap: () => onSelected(day),
          ),
      ],
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.day,
    required this.selected,
    required this.entries,
    required this.googleEvents,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final List<WorkEntry> entries;
  final List<GoogleCalendarEvent> googleEvents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasMissingNote = entries.any(
      (entry) => entry.supportNoteBreakdown.trim().isEmpty,
    );
    final hasOpenAction = entries.any(
      (entry) => entry.nextActions.any((item) => !item.isCompleted),
    );
    final hasCalendarGap = entries.any((entry) => !entry.googleCalendarEntered);
    final hasOverlap = _overlapEntryIds(entries).isNotEmpty;
    final hasGoogleEvent = googleEvents.isNotEmpty;
    final hasGoogleConflict = _googleConflictEntryIds(
      entries,
      googleEvents,
    ).isNotEmpty;
    final color = selected
        ? const Color(0xFF4F8DF7)
        : entries.isEmpty
        ? const Color(0xFF20283B)
        : const Color(0xFF13294D);

    return SizedBox(
      width: 70,
      height: 86,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? Colors.white
                    : entries.isEmpty
                    ? const Color(0xFF34405F)
                    : const Color(0xFF4F8DF7),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _weekdayLabel(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD8E2FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${day.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entries.length} visits',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD8E2FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TinyDot(active: hasMissingNote, color: Color(0xFFFF6B6B)),
                    _TinyDot(active: hasOpenAction, color: Color(0xFFFFC857)),
                    _TinyDot(active: hasCalendarGap, color: Color(0xFF8B5CF6)),
                    _TinyDot(active: hasOverlap, color: Color(0xFFFF8A4C)),
                    _TinyDot(active: hasGoogleEvent, color: Color(0xFF34A853)),
                    _TinyDot(
                      active: hasGoogleConflict,
                      color: Color(0xFFFF2F2F),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyDot extends StatelessWidget {
  const _TinyDot({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: active ? color : const Color(0xFF34405F),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SelectedDaySummary extends StatelessWidget {
  const _SelectedDaySummary({
    required this.date,
    required this.entries,
    required this.overlapCount,
    required this.googleConflictCount,
  });

  final DateTime date;
  final List<WorkEntry> entries;
  final int overlapCount;
  final int googleConflictCount;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final missingNotes = entries
        .where((entry) => entry.supportNoteBreakdown.trim().isEmpty)
        .length;
    final openActions = entries.fold<int>(
      0,
      (count, entry) =>
          count + entry.nextActions.where((item) => !item.isCompleted).length,
    );

    return Column(
      children: [
        ReviewRow(label: 'Date', value: formatDate(date)),
        ReviewRow(label: 'Visits', value: '${entries.length}'),
        ReviewRow(
          label: 'Hours',
          value: totalHours(entries).toStringAsFixed(2),
        ),
        ReviewRow(
          label: 'Earned',
          value: money(totalEarnings(entries, settings)),
        ),
        ReviewRow(label: 'Overlaps', value: '$overlapCount'),
        ReviewRow(label: 'Google conflicts', value: '$googleConflictCount'),
        ReviewRow(label: 'Missing notes', value: '$missingNotes'),
        ReviewRow(label: 'Open actions', value: '$openActions'),
      ],
    );
  }
}

class _GoogleCalendarPanel extends StatelessWidget {
  const _GoogleCalendarPanel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Use Create Calendar Event on a visit. The app creates a Google Calendar event from the saved billable entry.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xFF31E981), fontWeight: FontWeight.w800),
    );
  }
}

class _CalendarEntryCard extends StatefulWidget {
  const _CalendarEntryCard({
    required this.entry,
    required this.hasOverlap,
    required this.hasGoogleConflict,
  });

  final WorkEntry entry;
  final bool hasOverlap;
  final bool hasGoogleConflict;

  @override
  State<_CalendarEntryCard> createState() => _CalendarEntryCardState();
}

class _CalendarEntryCardState extends State<_CalendarEntryCard> {
  bool calendarBusy = false;
  bool calendarEntered = false;
  String? calendarMessage;
  bool calendarError = false;

  @override
  void initState() {
    super.initState();
    calendarEntered = widget.entry.googleCalendarEntered;
  }

  @override
  void didUpdateWidget(covariant _CalendarEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.googleCalendarEntered !=
            widget.entry.googleCalendarEntered) {
      calendarEntered = widget.entry.googleCalendarEntered;
    }
  }

  Future<void> _createCalendarEvent(BuildContext context) async {
    final appState = context.read<AppState>();

    setState(() {
      calendarBusy = true;
      calendarMessage = 'Opening calendar draft...';
      calendarError = false;
    });

    try {
      await appState.createPrivateGoogleCalendarEvent(widget.entry);

      appState.updateEntry(widget.entry.copyWith(googleCalendarEntered: true));
      setState(() {
        calendarEntered = true;
        calendarMessage = 'Google Calendar draft opened. Review and save it.';
      });
    } catch (error) {
      setState(() {
        calendarMessage =
            'Calendar export failed: ${_calendarErrorText(error)}';
        calendarError = true;
      });
    } finally {
      if (mounted) {
        setState(() => calendarBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final entry = widget.entry;
    final missingNote = entry.supportNoteBreakdown.trim().isEmpty;
    final openActions = entry.nextActions
        .where((action) => !action.isCompleted)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(entry.type.icon)),
              title: Text(
                entry.client,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${entry.type.label} | ${formatTime(entry.startTime)} | ${entry.baseMinutes} min visit | ${entry.hours.toStringAsFixed(2)}h billable',
              ),
              trailing: Text(
                money(entry.earnings(settings)),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  icon: missingNote
                      ? Icons.edit_note_outlined
                      : Icons.fact_check_outlined,
                  label: missingNote ? 'Missing note' : 'Note ready',
                  color: missingNote
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF31E981),
                ),
                _StatusChip(
                  icon: Icons.checklist_rtl_outlined,
                  label: '$openActions actions',
                  color: openActions == 0
                      ? const Color(0xFF31E981)
                      : const Color(0xFFFFC857),
                ),
                _StatusChip(
                  icon: calendarEntered
                      ? Icons.event_available_outlined
                      : Icons.calendar_month_outlined,
                  label: calendarEntered
                      ? 'Calendar entered'
                      : 'Needs calendar',
                  color: calendarEntered
                      ? const Color(0xFF31E981)
                      : const Color(0xFF8B5CF6),
                ),
                if (widget.hasOverlap)
                  const _StatusChip(
                    icon: Icons.warning_amber_outlined,
                    label: 'Overlaps',
                    color: Color(0xFFFF8A4C),
                  ),
                if (widget.hasGoogleConflict)
                  const _StatusChip(
                    icon: Icons.event_busy_outlined,
                    label: 'Google conflict',
                    color: Color(0xFFFF2F2F),
                  ),
                if (entry.noteSeconds > 0)
                  _StatusChip(
                    icon: Icons.timer_outlined,
                    label: entry.noteAllowanceText,
                    color: const Color(0xFF4F8DF7),
                  ),
                if (entry.type == EntryType.textNote)
                  _StatusChip(
                    icon: Icons.sms_outlined,
                    label: entry.textContactDirection.label,
                    color: const Color(0xFF8B5CF6),
                  ),
                if (entry.type == EntryType.textNote)
                  _StatusChip(
                    icon: entry.importantText
                        ? Icons.priority_high_rounded
                        : Icons.label_outline,
                    label: entry.importantText
                        ? 'Important text'
                        : 'Normal text',
                    color: entry.importantText
                        ? const Color(0xFFD50000)
                        : const Color(0xFF039BE5),
                  ),
                if (entry.type == EntryType.textNote)
                  _StatusChip(
                    icon: entry.textReplyNeeded
                        ? Icons.reply_outlined
                        : Icons.check_circle_outline,
                    label: entry.textReplyNeeded
                        ? 'Reply needed'
                        : 'No reply needed',
                    color: entry.textReplyNeeded
                        ? const Color(0xFFFFD166)
                        : const Color(0xFF31E981),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: calendarEntered || calendarBusy
                    ? null
                    : () => _createCalendarEvent(context),
                icon: calendarBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calendar_month_outlined),
                label: Text(
                  calendarEntered
                      ? 'Calendar Entered'
                      : calendarBusy
                      ? 'Creating Event'
                      : 'Create Calendar Event',
                ),
              ),
            ),
            if (calendarBusy || calendarMessage != null) ...[
              const SizedBox(height: 10),
              if (calendarBusy)
                const LinearProgressIndicator(
                  minHeight: 6,
                  color: Color(0xFF4F8DF7),
                  backgroundColor: Color(0xFF20283B),
                ),
              if (calendarMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _calendarMessageText(calendarMessage!),
                  style: TextStyle(
                    color: calendarError
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF31E981),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

String _calendarMessageText(String message) {
  if (_needsGoogleReconnect(message)) {
    return 'Calendar export failed: ${_calendarErrorText(message)}';
  }

  return message;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17, color: color),
      label: Text(label),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.14),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w900),
    );
  }
}

List<WorkEntry> _entriesForDays(List<WorkEntry> entries, List<DateTime> days) {
  final dayKeys = days.map(_dayKey).toSet();

  return entries
      .where((entry) => dayKeys.contains(_dayKey(entry.date)))
      .toList()
    ..sort(_entryCompare);
}

List<WorkEntry> _entriesForDay(List<WorkEntry> entries, DateTime day) {
  return entries.where((entry) => _sameDate(entry.date, day)).toList()
    ..sort(_entryCompare);
}

Set<String> _overlapEntryIds(List<WorkEntry> entries) {
  final sorted = entries.toList()..sort(_entryCompare);
  final overlaps = <String>{};
  WorkEntry? activeEntry;
  var activeEnd = -1;

  for (final entry in sorted) {
    final start = _entryStartMinute(entry);
    final end = start + entry.baseMinutes;

    if (activeEntry != null && start < activeEnd) {
      overlaps
        ..add(activeEntry.id)
        ..add(entry.id);
    }

    if (end > activeEnd) {
      activeEntry = entry;
      activeEnd = end;
    }
  }

  return overlaps;
}

Set<String> _googleConflictEntryIds(
  List<WorkEntry> entries,
  List<GoogleCalendarEvent> events,
) {
  final conflicts = <String>{};

  for (final entry in entries) {
    final entryStart = _entryDateTime(entry);
    final entryEnd = entryStart.add(Duration(minutes: entry.baseMinutes));

    for (final event in events) {
      if (_rangesOverlap(
        startA: entryStart,
        endA: entryEnd,
        startB: event.start,
        endB: event.end,
      )) {
        conflicts.add(entry.id);
        break;
      }
    }
  }

  return conflicts;
}

List<GoogleCalendarEvent> _googleEventsForDay(
  List<GoogleCalendarEvent> events,
  DateTime day,
) {
  return events.where((event) {
    return _sameDate(event.start, day) || _sameDate(event.end, day);
  }).toList();
}

bool _rangesOverlap({
  required DateTime startA,
  required DateTime endA,
  required DateTime startB,
  required DateTime endB,
}) {
  return startA.isBefore(endB) && startB.isBefore(endA);
}

DateTime _entryDateTime(WorkEntry entry) {
  return DateTime(
    entry.date.year,
    entry.date.month,
    entry.date.day,
    entry.startTime.hour,
    entry.startTime.minute,
  );
}

int _entryStartMinute(WorkEntry entry) {
  return entry.startTime.hour * 60 + entry.startTime.minute;
}

int _entryCompare(WorkEntry a, WorkEntry b) {
  final dateCompare = a.date.compareTo(b.date);
  if (dateCompare != 0) return dateCompare;

  final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
  final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
  return aMinutes.compareTo(bMinutes);
}

String _rangeLabel(List<DateTime> days) {
  if (days.length == 1) return formatDate(days.first);

  return '${formatDate(days.first)} - ${formatDate(days.last)}';
}

String _weekdayLabel(DateTime day) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[day.weekday - 1];
}

String _dayKey(DateTime value) {
  return '${value.year}-${value.month}-${value.day}';
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
