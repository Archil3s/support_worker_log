import '../../../../core/models/entry_type.dart';
import '../../../../core/services/local_support_note_service.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/totals.dart';
import 'work_contact_type_display.dart';

class WorkMonthSummary {
  const WorkMonthSummary({
    required this.label,
    required this.entries,
    required this.hours,
    required this.earned,
    required this.kilometres,
    required this.notesToFinish,
    required this.openActions,
    required this.entriesByType,
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
    final entriesByType = <EntryType, int>{
      for (final type in EntryType.values) type: 0,
    };
    for (final entry in entries) {
      entriesByType[entry.type] = entriesByType[entry.type]! + 1;
    }

    return WorkMonthSummary(
      label: '${_monthNames[now.month - 1]} ${now.year}',
      entries: entries.length,
      hours: totalHours(entries),
      earned: totalEarnings(entries, appState.settings),
      kilometres: totalKilometres(entries),
      notesToFinish: notesToFinish,
      openActions: entryActions + generalActions,
      entriesByType: Map.unmodifiable(entriesByType),
    );
  }

  final String label;
  final int entries;
  final double hours;
  final double earned;
  final double kilometres;
  final int notesToFinish;
  final int openActions;
  final Map<EntryType, int> entriesByType;

  String get readableText {
    final buffer = StringBuffer()
      ..writeln('Work totals - $label')
      ..writeln('Total entries: $entries')
      ..writeln('Billable hours: ${hours.toStringAsFixed(2)}')
      ..writeln('Earnings: ${money(earned)}')
      ..writeln('Travel: ${kilometres.toStringAsFixed(1)} km')
      ..writeln()
      ..writeln('Contact type totals');

    for (final type in workContactTypeDisplayOrder) {
      buffer.writeln(
        '${workContactTypeDisplayLabel(type)}: ${entriesByType[type] ?? 0}',
      );
    }

    buffer
      ..writeln()
      ..writeln('Notes to finish: $notesToFinish')
      ..write('Open actions: $openActions');

    return buffer.toString();
  }
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
