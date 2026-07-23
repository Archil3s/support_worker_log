import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/core/state/app_state.dart';
import 'package:support_worker_log/features/shell/presentation/models/work_month_summary.dart';

void main() {
  test('counts current-month Work entries by contact type', () {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState(warmGoogleAccounts: false);
    addTearDown(appState.dispose);
    final now = DateTime(2026, 7, 24);

    appState
      ..addEntry(_entry('home-1', EntryType.homeVisit, now))
      ..addEntry(_entry('home-2', EntryType.homeVisit, now))
      ..addEntry(_entry('text-1', EntryType.textNote, now))
      ..addEntry(_entry('professional-1', EntryType.professionalContact, now))
      ..addEntry(
        _entry('previous-month', EntryType.phoneCall, DateTime(2026, 6, 30)),
      );

    final summary = WorkMonthSummary.fromState(appState, now);

    expect(summary.entries, 4);
    expect(summary.entriesByType[EntryType.homeVisit], 2);
    expect(summary.entriesByType[EntryType.textNote], 1);
    expect(summary.entriesByType[EntryType.professionalContact], 1);
    expect(summary.entriesByType[EntryType.phoneCall], 0);
    expect(summary.entriesByType.length, EntryType.values.length);
  });
}

WorkEntry _entry(String id, EntryType type, DateTime date) {
  return WorkEntry(
    id: id,
    client: 'Test client',
    type: type,
    date: date,
    startTime: const TimeOfDay(hour: 9, minute: 0),
    minutes: 0,
    notes: const [],
  );
}
