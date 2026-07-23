import '../../../../core/services/local_support_note_service.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/utils/totals.dart';

class WorkMonthSummary {
  const WorkMonthSummary({
    required this.label,
    required this.entries,
    required this.hours,
    required this.earned,
    required this.kilometres,
    required this.notesToFinish,
    required this.openActions,
  });

  factory WorkMonthSummary.fromState(AppState appState, DateTime now) {
    final entries = appState.workEntries.where((entry) {
      return entry.date.year == now.year && entry.date.month == now.month;
    }).toList();
    final notesToFinish = entries.where((entry) {
      return !LocalSupportNoteService.hasEnteredSupportNoteContent(
        entry.supportNoteBreakdown,
      );
    }).length;
    final entryActions = entries.fold<int>(
      0,
      (total, entry) =>
          total +
          entry.nextActions.where((action) => !action.isCompleted).length,
    );
    final generalActions = appState.generalActions
        .where((action) => !action.isCompleted)
        .length;

    return WorkMonthSummary(
      label: '${_monthNames[now.month - 1]} ${now.year}',
      entries: entries.length,
      hours: totalHours(entries),
      earned: totalEarnings(entries, appState.settings),
      kilometres: totalKilometres(entries),
      notesToFinish: notesToFinish,
      openActions: entryActions + generalActions,
    );
  }

  final String label;
  final int entries;
  final double hours;
  final double earned;
  final double kilometres;
  final int notesToFinish;
  final int openActions;
}

const _monthNames = [
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
