import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/app_settings.dart';
import '../models/entry_type.dart';
import '../models/personal_log_entry.dart';
import '../models/work_entry.dart';
import '../utils/formatters.dart';
import '../utils/pay_period_utils.dart';
import '../utils/totals.dart';

class ExcelWorkbookResult {
  const ExcelWorkbookResult({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class ExcelExportService {
  const ExcelExportService();

  ExcelWorkbookResult buildLiveWorkDriveWorkbook({
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    final excel = Excel.createExcel();
    final sortedEntries = [...entries]..sort(_newestWorkEntryFirst);

    _buildLiveWorkDashboard(
      sheet: excel['Dashboard'],
      entries: sortedEntries,
      settings: settings,
    );
    _buildLiveWeeklyAnalyticsSheet(
      sheet: excel['Weekly Analytics'],
      entries: sortedEntries,
      settings: settings,
    );
    _buildLiveClientSummarySheet(
      sheet: excel['Client Summary'],
      entries: sortedEntries,
      settings: settings,
    );
    _buildLiveVisitMixSheet(
      sheet: excel['Visit Mix'],
      entries: sortedEntries,
      settings: settings,
    );
    _buildLiveOpenActionsSheet(
      sheet: excel['Open Actions'],
      entries: sortedEntries,
    );
    _buildLiveWorkEntriesSheet(
      sheet: excel['Work Entries'],
      entries: sortedEntries,
      settings: settings,
    );

    _finalizeWorkbook(excel, 'Dashboard');

    final bytes = excel.encode() ?? <int>[];
    return ExcelWorkbookResult(
      fileName: 'Support Worker Log - Live Dashboard.xlsx',
      bytes: Uint8List.fromList(bytes),
    );
  }

  ExcelWorkbookResult buildLivePersonalDriveWorkbook({
    required List<PersonalLogEntry> entries,
  }) {
    final excel = Excel.createExcel();
    final sortedEntries = [...entries]..sort(_newestPersonalEntryFirst);

    _buildLivePersonalDashboard(
      sheet: excel['Dashboard'],
      entries: sortedEntries,
    );
    _buildLiveGymSummarySheet(
      sheet: excel['Gym Summary'],
      entries: sortedEntries,
    );
    _buildLiveWorkoutTrendSheet(
      sheet: excel['Workout Trend'],
      entries: sortedEntries,
    );
    _buildLiveWorkoutDaysSheet(
      sheet: excel['Workout Days'],
      entries: sortedEntries,
    );
    _buildLiveBodyWeightSheet(
      sheet: excel['Body Weight'],
      entries: sortedEntries,
    );
    _buildLivePersonalEntriesSheet(
      sheet: excel['Personal Logs'],
      entries: sortedEntries,
    );
    _buildLiveWorkoutDayTabs(excel, sortedEntries);

    _finalizeWorkbook(excel, 'Dashboard');

    final bytes = excel.encode() ?? <int>[];
    return ExcelWorkbookResult(
      fileName: 'Personal Log - Live Dashboard.xlsx',
      bytes: Uint8List.fromList(bytes),
    );
  }

  ExcelWorkbookResult buildPayPeriodWorkbook({
    required List<WorkEntry> entries,
    required AppSettings settings,
    required PayPeriodRange range,
  }) {
    final excel = Excel.createExcel();

    final summarySheet = excel['Summary'];
    final entriesSheet = excel['Entries'];
    final taxSheet = excel['Tax Estimate'];

    final periodEntries = entriesInRange(entries, range);
    final weekOneEntries = entriesBetween(
      entries,
      range.weekOneStart,
      range.weekOneEnd,
    );
    final weekTwoEntries = entriesBetween(
      entries,
      range.weekTwoStart,
      range.weekTwoEnd,
    );

    _buildSummarySheet(
      sheet: summarySheet,
      range: range,
      periodEntries: periodEntries,
      weekOneEntries: weekOneEntries,
      weekTwoEntries: weekTwoEntries,
      settings: settings,
    );

    _buildEntriesSheet(
      sheet: entriesSheet,
      entries: periodEntries,
      settings: settings,
    );

    _buildTaxSheet(sheet: taxSheet, entries: periodEntries, settings: settings);

    excel.setDefaultSheet('Summary');

    _deleteDefaultSheet(excel);

    final bytes = excel.encode() ?? <int>[];
    final fileName =
        'support_worker_log_${_fileDate(range.start)}_${_fileDate(range.end)}';

    return ExcelWorkbookResult(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
    );
  }

  void _buildLiveWorkDashboard({
    required Sheet sheet,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    _setColumnWidths(sheet, const [16, 16, 16, 16, 16, 16, 16, 16]);
    _appendTitle(sheet, 'Work Dashboard');
    _appendRow(sheet, ['Updated', formatDate(DateTime.now()), 'File', 'Excel']);
    _appendSpacer(sheet);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = _weekStart(today);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final allStats = _workStats(entries, settings);
    final weekStats = _workStats(
      entries
          .where((entry) => _isDateInRange(entry.date, weekStart, weekEnd))
          .toList(),
      settings,
    );
    final weekly = _weeklyWorkSummaries(entries, settings);
    final clients = _workClientSummaries(entries, settings);
    final visitMix = _workTypeSummaries(entries, settings);
    final topClient = clients.isEmpty ? null : clients.first;
    final maxWeekHours = weekly.fold<double>(
      0,
      (max, week) => week.hours > max ? week.hours : max,
    );

    _appendMetricCards(sheet, [
      _DashboardMetric(
        label: 'Week Hrs',
        value: weekStats.hours.toStringAsFixed(1),
        signal: _goalSignal(weekStats.hours, settings.weeklyHoursGoal),
        color: '#1F4E78',
      ),
      _DashboardMetric(
        label: 'Earned',
        value: money(weekStats.earnings),
        signal: weekStats.earnings >= settings.weeklyEarningsGoal
            ? 'On'
            : 'Under',
        color: '#2F6B4F',
      ),
      _DashboardMetric(
        label: 'Actions',
        value: '${allStats.openActions}',
        signal: allStats.openActions == 0 ? 'OK' : 'Due',
        color: allStats.openActions == 0 ? '#2F6B4F' : '#9A3412',
      ),
      _DashboardMetric(
        label: 'Replies',
        value: '${allStats.textRepliesNeeded}',
        signal: allStats.textRepliesNeeded == 0 ? 'OK' : 'Reply',
        color: allStats.textRepliesNeeded == 0 ? '#2F6B4F' : '#9A3412',
      ),
    ]);
    _appendSpacer(sheet);
    _appendMetricCards(sheet, [
      _DashboardMetric(
        label: 'Entries',
        value: '${weekStats.entryCount}',
        signal: 'Week',
        color: '#305496',
      ),
      _DashboardMetric(
        label: 'Travel',
        value: weekStats.kilometres.toStringAsFixed(1),
        signal: 'km',
        color: '#7030A0',
      ),
      _DashboardMetric(
        label: 'Top Client',
        value: topClient?.client ?? '-',
        signal: topClient == null
            ? 'None'
            : '${topClient.hours.toStringAsFixed(1)} h',
        color: '#365F91',
      ),
      _DashboardMetric(
        label: 'Total Hrs',
        value: allStats.hours.toStringAsFixed(1),
        signal: 'All',
        color: '#595959',
      ),
    ]);
    _appendSpacer(sheet);

    _appendSection(sheet, 'Week Bars');
    _appendHeader(sheet, ['Week', 'Hrs', 'Bar', r'$', 'Open']);
    for (final week in weekly.take(6)) {
      _appendRow(sheet, [
        formatDate(week.weekStart),
        week.hours.toStringAsFixed(1),
        _bar(week.hours, maxWeekHours),
        week.earnings,
        week.openActions,
      ]);
    }
    _appendSpacer(sheet);

    final maxClientHours = clients.fold<double>(
      0,
      (max, item) => item.hours > max ? item.hours : max,
    );
    _appendSection(sheet, 'Client Load');
    _appendHeader(sheet, ['Client', 'Hrs', 'Bar', 'R', 'A']);
    for (final client in clients.take(6)) {
      _appendRow(sheet, [
        client.client,
        client.hours.toStringAsFixed(1),
        _bar(client.hours, maxClientHours),
        client.textRepliesNeeded,
        client.openActions,
      ]);
    }
    _appendSpacer(sheet);

    _appendSection(sheet, 'Visit Mix');
    _appendHeader(sheet, ['Type', 'Share', 'Bar', 'Hrs']);
    for (final item in visitMix) {
      final share = entries.isEmpty ? 0.0 : item.entryCount / entries.length;
      _appendRow(sheet, [
        item.label,
        _percentText(item.entryCount, entries.length),
        _bar(share, 1),
        item.hours.toStringAsFixed(1),
      ]);
    }
  }

  void _buildLiveWorkEntriesSheet({
    required Sheet sheet,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    _setColumnWidths(sheet, const [
      13,
      11,
      20,
      22,
      12,
      12,
      13,
      11,
      12,
      14,
      14,
      14,
      18,
      42,
    ]);
    _appendTitle(sheet, 'Work Entries');
    _appendHeader(sheet, [
      'Date',
      'Start',
      'Client',
      'Type',
      'Visit min',
      'Billable h',
      'Earnings',
      'KM',
      'Fuel',
      'Calendar',
      'Important',
      'Reply needed',
      'Open actions',
      'Notes',
    ]);

    for (final entry in entries) {
      _appendRow(sheet, [
        formatDate(entry.date),
        formatTime(entry.startTime),
        entry.client,
        entry.type.label,
        entry.baseMinutes,
        entry.hours,
        entry.earnings(settings),
        entry.kilometres,
        entry.fuelReimbursement(settings),
        entry.googleCalendarEntered ? 'Entered' : 'Not entered',
        entry.importantText ? 'Yes' : 'No',
        entry.textReplyNeeded ? 'Yes' : 'No',
        entry.nextActions.where((action) => !action.isCompleted).length,
        _entryNotesPreview(entry),
      ]);
    }
  }

  void _buildLiveWeeklyAnalyticsSheet({
    required Sheet sheet,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    final weekly = _weeklyWorkSummaries(entries, settings);
    final maxHours = weekly.fold<double>(
      0,
      (max, item) => item.hours > max ? item.hours : max,
    );
    _setColumnWidths(sheet, const [14, 11, 12, 12, 14, 11, 14, 13, 18, 20]);
    _appendTitle(sheet, 'Weekly Analytics');
    _appendRow(sheet, [
      'Use this tab to see whether workload, pay, travel, and admin pressure are moving in the right direction.',
    ]);
    _appendSpacer(sheet);
    _appendHeader(sheet, [
      'Week',
      'Entries',
      'Hours',
      'Goal',
      'Earnings',
      'KM',
      'Reply needed',
      'Open actions',
      'Signal',
      'Hours bar',
    ]);

    for (final week in weekly) {
      _appendRow(sheet, [
        formatDate(week.weekStart),
        week.entryCount,
        week.hours,
        settings.weeklyHoursGoal,
        week.earnings,
        week.kilometres,
        week.textRepliesNeeded,
        week.openActions,
        _goalSignal(week.hours, settings.weeklyHoursGoal),
        _bar(week.hours, maxHours),
      ]);
    }
  }

  void _buildLiveClientSummarySheet({
    required Sheet sheet,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    final summaries = _workClientSummaries(entries, settings);
    _setColumnWidths(sheet, const [24, 12, 13, 13, 13, 14, 13, 14, 16, 18]);
    _appendTitle(sheet, 'Client Summary');
    _appendHeader(sheet, [
      'Client',
      'Entries',
      'Hours',
      'Avg h / entry',
      'Earnings',
      'KM',
      'Last contact',
      'Texts',
      'Reply needed',
      'Open actions',
      'Signal',
    ]);

    for (final item in summaries) {
      _appendRow(sheet, [
        item.client,
        item.entryCount,
        item.hours,
        item.averageHours,
        item.earnings,
        item.kilometres,
        formatDate(item.lastDate),
        item.textCount,
        item.textRepliesNeeded,
        item.openActions,
        _clientSignal(item),
      ]);
    }
  }

  void _buildLiveVisitMixSheet({
    required Sheet sheet,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    final summaries = _workTypeSummaries(entries, settings);
    _setColumnWidths(sheet, const [24, 12, 13, 13, 11, 13, 15, 18]);
    _appendTitle(sheet, 'Visit Mix');
    _appendRow(sheet, [
      'Shows what type of work is driving time, pay, travel, and follow-up load.',
    ]);
    _appendSpacer(sheet);
    _appendHeader(sheet, [
      'Entry type',
      'Entries',
      'Hours',
      'Earnings',
      'KM',
      'Share',
      'Reply needed',
      'Open actions',
    ]);

    for (final item in summaries) {
      _appendRow(sheet, [
        item.label,
        item.entryCount,
        item.hours,
        item.earnings,
        item.kilometres,
        _percentText(item.entryCount, entries.length),
        item.textRepliesNeeded,
        item.openActions,
      ]);
    }
  }

  void _buildLiveOpenActionsSheet({
    required Sheet sheet,
    required List<WorkEntry> entries,
  }) {
    _setColumnWidths(sheet, const [13, 20, 18, 50, 14, 16, 18]);
    _appendTitle(sheet, 'Open Actions');
    _appendHeader(sheet, [
      'Source date',
      'Client',
      'Source type',
      'Action',
      'Status',
      'Created',
      'Age',
    ]);

    for (final entry in entries) {
      for (final action in entry.nextActions) {
        if (action.isCompleted) continue;

        _appendRow(sheet, [
          formatDate(entry.date),
          entry.client,
          entry.type.label,
          _phoneBullets([action.text], maxItems: 1),
          'Open',
          formatDate(action.createdAt),
          _ageText(action.createdAt),
        ]);
      }
    }
  }

  void _buildLivePersonalDashboard({
    required Sheet sheet,
    required List<PersonalLogEntry> entries,
  }) {
    _setColumnWidths(sheet, const [16, 16, 16, 16, 16, 16, 16, 16]);
    _appendTitle(sheet, 'Personal Dashboard');
    _appendRow(sheet, ['Updated', formatDate(DateTime.now()), 'File', 'Excel']);
    _appendSpacer(sheet);

    final bodyWeight = entries
        .where((entry) => entry.category == PersonalLogCategory.bodyWeight)
        .toList();
    final health = entries
        .where((entry) => entry.category == PersonalLogCategory.health)
        .toList();
    final weekly = _personalWeeklySummaries(entries);
    final exercises = _personalGymSummaries(entries);
    final latestWeek = weekly.isEmpty ? null : weekly.first;
    final topExercise = exercises.isEmpty ? null : exercises.first;
    final bodyTrend = _bodyWeightTrendText(bodyWeight);
    final maxGymSessions = weekly.fold<int>(
      0,
      (max, item) => item.gymSessions > max ? item.gymSessions : max,
    );
    final maxExerciseSessions = exercises.fold<int>(
      0,
      (max, item) => item.sessionCount > max ? item.sessionCount : max,
    );

    _appendMetricCards(sheet, [
      _DashboardMetric(
        label: 'Gym Wk',
        value: latestWeek == null ? '0' : '${latestWeek.gymSessions}',
        signal: latestWeek == null
            ? 'None'
            : latestWeek.gymSessions >= 3
            ? 'Strong'
            : latestWeek.gymSessions >= 1
            ? 'Some'
            : 'Low',
        color: '#1F4E78',
      ),
      _DashboardMetric(
        label: 'Weight',
        value: _latestBodyWeight(bodyWeight),
        signal: bodyTrend.signal,
        color: '#2F6B4F',
      ),
      _DashboardMetric(
        label: 'Top Lift',
        value: topExercise?.exercise ?? '-',
        signal: topExercise == null ? 'None' : '${topExercise.sessionCount}',
        color: '#7030A0',
      ),
      _DashboardMetric(
        label: 'Health',
        value: '${health.length}',
        signal: health.isEmpty ? 'None' : 'Notes',
        color: health.isEmpty ? '#595959' : '#9A3412',
      ),
    ]);
    _appendSpacer(sheet);

    _appendSection(sheet, 'Workout Bars');
    _appendHeader(sheet, ['Week', 'Gym', 'Bar', 'BW', 'Health']);
    for (final item in weekly.take(6)) {
      _appendRow(sheet, [
        formatDate(item.weekStart),
        item.gymSessions,
        _bar(item.gymSessions.toDouble(), maxGymSessions.toDouble()),
        item.bodyWeightLogs,
        item.healthLogs,
      ]);
    }
    _appendSpacer(sheet);

    _appendSection(sheet, 'Exercise Bars');
    _appendHeader(sheet, ['Exercise', 'Logs', 'Bar', 'Latest']);
    for (final item in exercises.take(6)) {
      _appendRow(sheet, [
        item.exercise,
        item.sessionCount,
        _bar(item.sessionCount.toDouble(), maxExerciseSessions.toDouble()),
        item.latestMetric,
      ]);
    }
    _appendSpacer(sheet);

    _appendSection(sheet, 'Recent');
    _appendHeader(sheet, ['Date', 'Type', 'Metric']);
    for (final entry in entries.take(6)) {
      _appendRow(sheet, [
        formatDate(entry.date),
        entry.category.label,
        entry.metric.trim().isEmpty ? entry.title : entry.metric,
      ]);
    }
  }

  void _buildLivePersonalEntriesSheet({
    required Sheet sheet,
    required List<PersonalLogEntry> entries,
  }) {
    _setColumnWidths(sheet, const [13, 16, 32, 32, 56]);
    _appendTitle(sheet, 'Personal Logs');
    _appendHeader(sheet, ['Date', 'Category', 'Title', 'Metric', 'Notes']);

    for (final entry in entries) {
      _appendRow(sheet, [
        formatDate(entry.date),
        entry.category.label,
        entry.title,
        entry.metric,
        _phoneBullets([entry.notes]),
      ]);
    }
  }

  void _buildLiveGymSummarySheet({
    required Sheet sheet,
    required List<PersonalLogEntry> entries,
  }) {
    final summaries = _personalGymSummaries(entries);
    _setColumnWidths(sheet, const [30, 14, 13, 32, 48, 18]);
    _appendTitle(sheet, 'Gym Summary');
    _appendHeader(sheet, [
      'Exercise',
      'Sessions',
      'Last logged',
      'Latest metric',
      'Latest notes',
      'Signal',
    ]);

    for (final item in summaries) {
      _appendRow(sheet, [
        item.exercise,
        item.sessionCount,
        formatDate(item.lastDate),
        item.latestMetric,
        _phoneBullets([item.latestNotes]),
        _gymSummarySignal(item),
      ]);
    }
  }

  void _buildLiveWorkoutTrendSheet({
    required Sheet sheet,
    required List<PersonalLogEntry> entries,
  }) {
    final weekly = _personalWeeklySummaries(entries);
    final maxGymSessions = weekly.fold<int>(
      0,
      (max, item) => item.gymSessions > max ? item.gymSessions : max,
    );
    _setColumnWidths(sheet, const [14, 12, 12, 16, 16, 18, 20]);
    _appendTitle(sheet, 'Workout Trend');
    _appendRow(sheet, [
      'Weekly personal activity summary for training consistency and logging habits.',
    ]);
    _appendSpacer(sheet);
    _appendHeader(sheet, [
      'Week',
      'Total logs',
      'Gym',
      'Body weight',
      'Health notes',
      'Signal',
      'Gym bar',
    ]);

    for (final item in weekly) {
      _appendRow(sheet, [
        formatDate(item.weekStart),
        item.totalLogs,
        item.gymSessions,
        item.bodyWeightLogs,
        item.healthLogs,
        item.gymSessions >= 3
            ? 'Strong week'
            : item.gymSessions >= 1
            ? 'Some training'
            : 'No training logs',
        _bar(item.gymSessions.toDouble(), maxGymSessions.toDouble()),
      ]);
    }
  }

  void _buildLiveWorkoutDaysSheet({
    required Sheet sheet,
    required List<PersonalLogEntry> entries,
  }) {
    final days = _personalWorkoutDaySummaries(entries);
    final maxLogs = days.fold<int>(
      0,
      (max, item) => item.logCount > max ? item.logCount : max,
    );

    _setColumnWidths(sheet, const [13, 11, 13, 22, 18, 20]);
    _appendTitle(sheet, 'Workout Days');
    _appendHeader(sheet, ['Date', 'Logs', 'Exercises', 'Top', 'Bar', 'Notes']);

    for (final day in days) {
      _appendRow(sheet, [
        formatDate(day.date),
        day.logCount,
        day.exerciseCount,
        day.mainMetric,
        _bar(day.logCount.toDouble(), maxLogs.toDouble()),
        day.notesPreview,
      ]);
    }
  }

  void _buildLiveWorkoutDayTabs(Excel excel, List<PersonalLogEntry> entries) {
    final usedNames = excel.sheets.keys.toSet();

    for (final day in _personalWorkoutDaySummaries(entries)) {
      final sheetName = _uniqueSheetName(
        _safeSheetName('Gym ${_sheetDate(day.date)}'),
        usedNames,
      );
      usedNames.add(sheetName);

      final sheet = excel[sheetName];
      _setColumnWidths(sheet, const [24, 18, 18, 34]);
      _appendTitle(sheet, 'Workout ${formatDate(day.date)}');
      _appendHeader(sheet, ['Exercise', 'Metric', 'Trend', 'Notes']);

      for (final entry in day.entries) {
        _appendRow(sheet, [
          _personalExerciseName(entry.title),
          entry.metric.trim().isEmpty ? '-' : entry.metric.trim(),
          _personalWorkoutSignal(entry),
          _phoneBullets([entry.notes]),
        ]);
      }
    }
  }

  void _buildLiveBodyWeightSheet({
    required Sheet sheet,
    required List<PersonalLogEntry> entries,
  }) {
    final bodyWeight =
        entries
            .where((entry) => entry.category == PersonalLogCategory.bodyWeight)
            .toList()
          ..sort(_newestPersonalEntryFirst);
    _setColumnWidths(sheet, const [13, 18, 18, 50]);
    _appendTitle(sheet, 'Body Weight');
    _appendHeader(sheet, ['Date', 'Weight', 'Trend from last', 'Notes']);

    for (var index = 0; index < bodyWeight.length; index++) {
      final entry = bodyWeight[index];
      final current = _bodyWeightKg(entry);
      final previous = index + 1 < bodyWeight.length
          ? _bodyWeightKg(bodyWeight[index + 1])
          : null;
      final change = current == null || previous == null
          ? 'Baseline'
          : '${_signedNumber(current - previous)} kg';

      _appendRow(sheet, [
        formatDate(entry.date),
        current ?? _latestBodyWeight([entry]),
        change,
        _phoneBullets([entry.notes]),
      ]);
    }
  }

  void _buildSummarySheet({
    required Sheet sheet,
    required PayPeriodRange range,
    required List<WorkEntry> periodEntries,
    required List<WorkEntry> weekOneEntries,
    required List<WorkEntry> weekTwoEntries,
    required AppSettings settings,
  }) {
    _appendTitle(sheet, 'Support Worker Log - Pay Period Summary');
    _appendSpacer(sheet);

    _appendRow(sheet, ['Period Start', formatDate(range.start)]);
    _appendRow(sheet, ['Period End', formatDate(range.end)]);
    _appendRow(sheet, ['Generated', formatDate(DateTime.now())]);
    _appendSpacer(sheet);

    _appendHeader(sheet, ['Period Totals', 'Value']);
    _appendRow(sheet, ['Entries', periodEntries.length]);
    _appendRow(sheet, ['Hours', totalHours(periodEntries)]);
    _appendRow(sheet, ['Earnings', totalEarnings(periodEntries, settings)]);
    _appendRow(sheet, ['Kilometres', totalKilometres(periodEntries)]);
    _appendRow(sheet, [
      'Fuel Reimbursement',
      _totalFuel(periodEntries, settings),
    ]);
    _appendSpacer(sheet);

    _appendHeader(sheet, [
      'Week 1',
      '${formatDate(range.weekOneStart)} - ${formatDate(range.weekOneEnd)}',
    ]);
    _appendRow(sheet, ['Entries', weekOneEntries.length]);
    _appendRow(sheet, ['Hours', totalHours(weekOneEntries)]);
    _appendRow(sheet, ['Earnings', totalEarnings(weekOneEntries, settings)]);
    _appendRow(sheet, ['Kilometres', totalKilometres(weekOneEntries)]);
    _appendSpacer(sheet);

    _appendHeader(sheet, [
      'Week 2',
      '${formatDate(range.weekTwoStart)} - ${formatDate(range.weekTwoEnd)}',
    ]);
    _appendRow(sheet, ['Entries', weekTwoEntries.length]);
    _appendRow(sheet, ['Hours', totalHours(weekTwoEntries)]);
    _appendRow(sheet, ['Earnings', totalEarnings(weekTwoEntries, settings)]);
    _appendRow(sheet, ['Kilometres', totalKilometres(weekTwoEntries)]);
  }

  void _buildEntriesSheet({
    required Sheet sheet,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    _appendTitle(sheet, 'Selected Fortnight Entries');
    _appendSpacer(sheet);

    _appendHeader(sheet, [
      'Date',
      'Start Time',
      'Client',
      'Entry Type',
      'Minutes',
      'Hours',
      'Earnings',
      'Odometer Start',
      'Odometer Finish',
      'Kilometres',
      'Fuel Reimbursement',
      'Notes',
    ]);

    for (final entry in entries) {
      _appendRow(sheet, [
        formatDate(entry.date),
        formatTime(entry.startTime),
        entry.client,
        entry.type.label,
        entry.minutes,
        entry.hours,
        entry.earnings(settings),
        entry.odometerStart ?? '',
        entry.odometerEnd ?? '',
        entry.kilometres,
        entry.fuelReimbursement(settings),
        entry.notes.join('; '),
      ]);
    }
  }

  void _buildTaxSheet({
    required Sheet sheet,
    required List<WorkEntry> entries,
    required AppSettings settings,
  }) {
    final gross = totalEarnings(entries, settings);
    final acc = gross * settings.accRate;
    final kiwiSaver = settings.kiwiSaverEnabled
        ? gross * settings.kiwiSaverRate
        : 0.0;
    final gst = gross * settings.gstRate;
    final net = gross - acc - kiwiSaver - gst;

    _appendTitle(sheet, 'Tax Estimate');
    _appendSpacer(sheet);

    _appendHeader(sheet, ['Item', 'Amount', 'Rate']);
    _appendRow(sheet, ['Gross Income', gross, '']);
    _appendRow(sheet, ['ACC Levy', -acc, settings.accRate]);
    _appendRow(sheet, [
      'KiwiSaver',
      -kiwiSaver,
      settings.kiwiSaverEnabled ? settings.kiwiSaverRate : 'Off',
    ]);
    _appendRow(sheet, ['GST Estimate', -gst, settings.gstRate]);
    _appendRow(sheet, ['Net Take-home Estimate', net, '']);
    _appendSpacer(sheet);

    _appendHeader(sheet, ['Period Inputs', 'Value']);
    _appendRow(sheet, ['Entries', entries.length]);
    _appendRow(sheet, ['Hours', totalHours(entries)]);
    _appendRow(sheet, ['Kilometres', totalKilometres(entries)]);
    _appendRow(sheet, ['Hourly Rate', settings.hourlyRate]);
    _appendRow(sheet, ['Fuel Rate / KM', settings.fuelRate]);
  }

  void _appendTitle(Sheet sheet, String title) {
    _appendStyledRow(sheet, [title], style: _titleStyle());
  }

  void _appendHeader(Sheet sheet, List<Object?> values) {
    _appendStyledRow(sheet, values, style: _headerStyle());
  }

  void _appendSection(Sheet sheet, String title) {
    _appendStyledRow(sheet, [title], style: _sectionStyle());
  }

  void _appendMetricCards(Sheet sheet, List<_DashboardMetric> metrics) {
    final labelRow = sheet.maxRows;
    sheet.appendRow(metrics.map((metric) => _cellValue(metric.label)).toList());
    final valueRow = sheet.maxRows;
    sheet.appendRow(metrics.map((metric) => _cellValue(metric.value)).toList());
    final signalRow = sheet.maxRows;
    sheet.appendRow(
      metrics.map((metric) => _cellValue(metric.signal)).toList(),
    );

    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      _styleCell(sheet, labelRow, index, _cardLabelStyle(metric.color));
      _styleCell(sheet, valueRow, index, _cardValueStyle(metric.color));
      _styleCell(sheet, signalRow, index, _cardSignalStyle(metric.color));
    }
  }

  void _appendRow(Sheet sheet, List<Object?> values) {
    sheet.appendRow(values.map(_cellValue).toList());
  }

  void _appendStyledRow(
    Sheet sheet,
    List<Object?> values, {
    required CellStyle style,
  }) {
    final rowIndex = sheet.maxRows;
    sheet.appendRow(values.map(_cellValue).toList());

    for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
        _cellValue(values[columnIndex]),
        cellStyle: style,
      );
    }
  }

  void _styleCell(Sheet sheet, int rowIndex, int columnIndex, CellStyle style) {
    final cell = CellIndex.indexByColumnRow(
      columnIndex: columnIndex,
      rowIndex: rowIndex,
    );
    sheet.updateCell(cell, sheet.cell(cell).value, cellStyle: style);
  }

  void _appendSpacer(Sheet sheet) {
    sheet.appendRow([TextCellValue('')]);
  }

  void _setColumnWidths(Sheet sheet, List<double> widths) {
    for (var index = 0; index < widths.length; index++) {
      sheet.setColumnWidth(index, widths[index]);
    }
  }

  CellStyle _titleStyle() {
    return CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1F4E78'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
  }

  CellStyle _headerStyle() {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#305496'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
  }

  CellStyle _sectionStyle() {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#1F4E78'),
      backgroundColorHex: ExcelColor.fromHexString('#D9EAF7'),
    );
  }

  CellStyle _cardLabelStyle(String color) {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString(color),
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  CellStyle _cardValueStyle(String color) {
    return CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString(color),
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  CellStyle _cardSignalStyle(String color) {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString(color),
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  CellValue _cellValue(Object? value) {
    if (value == null) {
      return TextCellValue('');
    }

    if (value is int) {
      return IntCellValue(value);
    }

    if (value is double) {
      return DoubleCellValue(value);
    }

    if (value is num) {
      return DoubleCellValue(value.toDouble());
    }

    if (value is bool) {
      return BoolCellValue(value);
    }

    return TextCellValue(value.toString());
  }

  void _finalizeWorkbook(Excel excel, String defaultSheet) {
    excel.setDefaultSheet(defaultSheet);
    _deleteDefaultSheet(excel);
  }

  void _deleteDefaultSheet(Excel excel) {
    final defaultSheet = excel.sheets.keys.contains('Sheet1');
    if (defaultSheet) {
      excel.delete('Sheet1');
    }
  }

  double _totalFuel(List<WorkEntry> entries, AppSettings settings) {
    return entries.fold<double>(
      0,
      (sum, entry) => sum + entry.fuelReimbursement(settings),
    );
  }

  String _fileDate(DateTime value) {
    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  int _newestWorkEntryFirst(WorkEntry a, WorkEntry b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;

    final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
    final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
    return bMinutes.compareTo(aMinutes);
  }

  int _newestPersonalEntryFirst(PersonalLogEntry a, PersonalLogEntry b) {
    return b.date.compareTo(a.date);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _weekStart(DateTime value) {
    final date = _dateOnly(value);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  bool _isDateInRange(DateTime value, DateTime start, DateTime end) {
    final date = _dateOnly(value);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  String _goalSignal(double value, double goal) {
    if (goal <= 0) return value > 0 ? 'Tracked' : 'No data';

    final ratio = value / goal;
    if (ratio >= 1) return 'Target met';
    if (ratio >= 0.75) return 'Close';
    if (ratio >= 0.4) return 'Building';
    return 'Low';
  }

  String _percentText(int value, int total) {
    if (total <= 0) return '0%';

    return '${(value / total * 100).toStringAsFixed(1)}%';
  }

  String _signedNumber(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(1)}';
  }

  String _ageText(DateTime value) {
    final days = _dateOnly(DateTime.now()).difference(_dateOnly(value)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day';
    return '$days days';
  }

  _WorkStats _workStats(List<WorkEntry> entries, AppSettings settings) {
    return _WorkStats(
      entryCount: entries.length,
      hours: totalHours(entries),
      earnings: totalEarnings(entries, settings),
      kilometres: totalKilometres(entries),
      textRepliesNeeded: entries
          .where(
            (entry) =>
                entry.type == EntryType.textNote && entry.textReplyNeeded,
          )
          .length,
      openActions: entries
          .expand((entry) => entry.nextActions)
          .where((action) => !action.isCompleted)
          .length,
    );
  }

  List<_WeeklyWorkSummary> _weeklyWorkSummaries(
    List<WorkEntry> entries,
    AppSettings settings,
  ) {
    final grouped = <DateTime, List<WorkEntry>>{};

    for (final entry in entries) {
      final week = _weekStart(entry.date);
      grouped.putIfAbsent(week, () => <WorkEntry>[]).add(entry);
    }

    final summaries = grouped.entries
        .map(
          (item) => _WeeklyWorkSummary(
            weekStart: item.key,
            entryCount: item.value.length,
            hours: totalHours(item.value),
            earnings: totalEarnings(item.value, settings),
            kilometres: totalKilometres(item.value),
            textRepliesNeeded: item.value
                .where(
                  (entry) =>
                      entry.type == EntryType.textNote && entry.textReplyNeeded,
                )
                .length,
            openActions: item.value
                .expand((entry) => entry.nextActions)
                .where((action) => !action.isCompleted)
                .length,
          ),
        )
        .toList();

    summaries.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return summaries;
  }

  List<_WorkClientSummary> _workClientSummaries(
    List<WorkEntry> entries,
    AppSettings settings,
  ) {
    final grouped = <String, List<WorkEntry>>{};

    for (final entry in entries) {
      final client = entry.client.trim().isEmpty
          ? 'Unknown Client'
          : entry.client.trim();
      grouped.putIfAbsent(client, () => <WorkEntry>[]).add(entry);
    }

    final summaries = grouped.entries.map((item) {
      final textEntries = item.value.where(
        (entry) => entry.type == EntryType.textNote,
      );

      return _WorkClientSummary(
        client: item.key,
        entryCount: item.value.length,
        hours: totalHours(item.value),
        averageHours: item.value.isEmpty
            ? 0
            : totalHours(item.value) / item.value.length,
        earnings: totalEarnings(item.value, settings),
        kilometres: totalKilometres(item.value),
        lastDate: item.value
            .map((entry) => entry.date)
            .reduce((a, b) => a.isAfter(b) ? a : b),
        textCount: textEntries.length,
        textRepliesNeeded: textEntries
            .where((entry) => entry.textReplyNeeded)
            .length,
        openActions: item.value
            .expand((entry) => entry.nextActions)
            .where((action) => !action.isCompleted)
            .length,
      );
    }).toList();

    summaries.sort((a, b) => b.entryCount.compareTo(a.entryCount));
    return summaries;
  }

  List<_WorkTypeSummary> _workTypeSummaries(
    List<WorkEntry> entries,
    AppSettings settings,
  ) {
    final summaries = <_WorkTypeSummary>[];

    for (final type in EntryType.values) {
      final typeEntries = entries.where((entry) => entry.type == type).toList();
      final textRepliesNeeded = typeEntries
          .where(
            (entry) =>
                entry.type == EntryType.textNote && entry.textReplyNeeded,
          )
          .length;
      summaries.add(
        _WorkTypeSummary(
          label: type.label,
          entryCount: typeEntries.length,
          hours: totalHours(typeEntries),
          earnings: totalEarnings(typeEntries, settings),
          kilometres: totalKilometres(typeEntries),
          textRepliesNeeded: textRepliesNeeded,
          openActions: typeEntries
              .expand((entry) => entry.nextActions)
              .where((action) => !action.isCompleted)
              .length,
        ),
      );
    }

    summaries.sort((a, b) => b.entryCount.compareTo(a.entryCount));
    return summaries;
  }

  String _clientSignal(_WorkClientSummary item) {
    if (item.openActions > 0 && item.textRepliesNeeded > 0) {
      return 'Action + reply';
    }
    if (item.openActions > 0) return 'Open action';
    if (item.textRepliesNeeded > 0) return 'Reply needed';
    return 'Clear';
  }

  String _entryNotesPreview(WorkEntry entry) {
    final notes = [
      ...entry.notes,
      entry.supportNoteBreakdown,
    ].map((item) => item.trim()).where((item) => item.isNotEmpty).toList();

    return _phoneBullets(notes);
  }

  String _phoneBullets(
    Iterable<String> values, {
    int maxItems = 2,
    int maxWords = 5,
  }) {
    final items = values
        .expand(_shortTextParts)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(maxItems)
        .map((item) => '- ${_clipWords(item, maxWords)}')
        .toList();

    return items.join('\n');
  }

  Iterable<String> _shortTextParts(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split(RegExp(r'\n+|\s*[|;.!?]\s+'));
  }

  String _clipWords(String value, int maxWords) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = compact
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .take(maxWords)
        .toList();

    return words.join(' ');
  }

  String _bar(double value, double max) {
    if (value <= 0 || max <= 0) return '';

    final filled = ((value / max) * 12).round().clamp(1, 12);
    final empty = 12 - filled;
    return '[${List.filled(filled, '#').join()}'
        '${List.filled(empty, '-').join()}]';
  }

  String _latestBodyWeight(List<PersonalLogEntry> entries) {
    if (entries.isEmpty) return 'Not logged';

    final sorted = [...entries]..sort(_newestPersonalEntryFirst);
    final latest = sorted.first;
    final metric = latest.metric.trim();
    if (metric.isNotEmpty) return metric;

    return latest.title.trim().isEmpty ? 'Logged' : latest.title.trim();
  }

  _BodyWeightTrend _bodyWeightTrendText(List<PersonalLogEntry> entries) {
    if (entries.length < 2) {
      return const _BodyWeightTrend(
        signal: 'Needs data',
        detail: 'Add at least two body-weight logs for a trend.',
      );
    }

    final sorted = [...entries]..sort(_newestPersonalEntryFirst);
    final latest = _bodyWeightKg(sorted.first);
    final previous = _bodyWeightKg(sorted[1]);

    if (latest == null || previous == null) {
      return const _BodyWeightTrend(
        signal: 'Text only',
        detail: 'Use a kg value in the metric for trend calculation.',
      );
    }

    final change = latest - previous;
    final signal = change.abs() < 0.2
        ? 'Stable'
        : change > 0
        ? 'Up'
        : 'Down';

    return _BodyWeightTrend(
      signal: signal,
      detail: '${_signedNumber(change)} kg since the previous log.',
    );
  }

  double? _bodyWeightKg(PersonalLogEntry entry) {
    final text = '${entry.metric} ${entry.title} ${entry.notes}';
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*kg',
      caseSensitive: false,
    ).firstMatch(text);

    return double.tryParse(match?.group(1) ?? '');
  }

  List<_PersonalWorkoutDaySummary> _personalWorkoutDaySummaries(
    List<PersonalLogEntry> entries,
  ) {
    final grouped = <DateTime, List<PersonalLogEntry>>{};

    for (final entry in entries) {
      if (entry.category != PersonalLogCategory.gym) continue;

      final day = _dateOnly(entry.date);
      grouped.putIfAbsent(day, () => <PersonalLogEntry>[]).add(entry);
    }

    final summaries = grouped.entries.map((item) {
      final logs = [...item.value]..sort(_newestPersonalEntryFirst);
      final exercises = logs
          .map((entry) => _personalExerciseName(entry.title))
          .toSet();
      final metric = logs
          .map((entry) => entry.metric.trim())
          .firstWhere((metric) => metric.isNotEmpty, orElse: () => '-');

      return _PersonalWorkoutDaySummary(
        date: item.key,
        entries: logs,
        logCount: logs.length,
        exerciseCount: exercises.length,
        mainMetric: metric,
        notesPreview: _phoneBullets(logs.map((entry) => entry.notes)),
      );
    }).toList();

    summaries.sort((a, b) => b.date.compareTo(a.date));
    return summaries;
  }

  List<_PersonalWeeklySummary> _personalWeeklySummaries(
    List<PersonalLogEntry> entries,
  ) {
    final grouped = <DateTime, List<PersonalLogEntry>>{};

    for (final entry in entries) {
      final week = _weekStart(entry.date);
      grouped.putIfAbsent(week, () => <PersonalLogEntry>[]).add(entry);
    }

    final summaries = grouped.entries.map((item) {
      final logs = item.value;

      return _PersonalWeeklySummary(
        weekStart: item.key,
        totalLogs: logs.length,
        gymSessions: logs
            .where((entry) => entry.category == PersonalLogCategory.gym)
            .length,
        bodyWeightLogs: logs
            .where((entry) => entry.category == PersonalLogCategory.bodyWeight)
            .length,
        healthLogs: logs
            .where((entry) => entry.category == PersonalLogCategory.health)
            .length,
      );
    }).toList();

    summaries.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return summaries;
  }

  List<_PersonalGymSummary> _personalGymSummaries(
    List<PersonalLogEntry> entries,
  ) {
    final gym = entries.where(
      (entry) => entry.category == PersonalLogCategory.gym,
    );
    final grouped = <String, List<PersonalLogEntry>>{};

    for (final entry in gym) {
      final exercise = _personalExerciseName(entry.title);
      grouped.putIfAbsent(exercise, () => <PersonalLogEntry>[]).add(entry);
    }

    final summaries = grouped.entries.map((item) {
      final sorted = [...item.value]..sort(_newestPersonalEntryFirst);
      final latest = sorted.first;

      return _PersonalGymSummary(
        exercise: item.key,
        sessionCount: sorted.length,
        lastDate: latest.date,
        latestMetric: latest.metric,
        latestNotes: latest.notes,
      );
    }).toList();

    summaries.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return summaries;
  }

  String _gymSummarySignal(_PersonalGymSummary item) {
    if (item.latestNotes.toLowerCase().contains('pain') ||
        item.latestNotes.toLowerCase().contains('hurt')) {
      return 'Review pain';
    }
    if (item.sessionCount >= 3) return 'Established';
    return 'Build data';
  }

  String _personalWorkoutSignal(PersonalLogEntry entry) {
    final text = '${entry.metric} ${entry.notes}'.toLowerCase();
    if (text.contains('pain') || text.contains('hurt')) return 'Review';
    if (text.contains('pr') || text.contains('best')) return 'Best';
    if (entry.metric.trim().isNotEmpty) return 'Logged';
    return 'Note';
  }

  String _personalExerciseName(String title) {
    final parts = title.split(':');
    final exercise = parts.length < 2 ? title : parts.sublist(1).join(':');
    final trimmed = exercise.trim();
    return trimmed.isEmpty ? 'General' : trimmed;
  }

  String _sheetDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _safeSheetName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[:\\/?*\[\]]'), '-').trim();
    final fallback = cleaned.isEmpty ? 'Sheet' : cleaned;
    return fallback.length <= 31 ? fallback : fallback.substring(0, 31);
  }

  String _uniqueSheetName(String preferred, Set<String> usedNames) {
    if (!usedNames.contains(preferred)) return preferred;

    for (var index = 2; index < 100; index++) {
      final suffix = ' $index';
      final baseLength = 31 - suffix.length;
      final base = preferred.length <= baseLength
          ? preferred
          : preferred.substring(0, baseLength);
      final candidate = '$base$suffix';
      if (!usedNames.contains(candidate)) return candidate;
    }

    return _safeSheetName('${DateTime.now().microsecondsSinceEpoch}');
  }
}

class _DashboardMetric {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.signal,
    required this.color,
  });

  final String label;
  final String value;
  final String signal;
  final String color;
}

class _WorkStats {
  const _WorkStats({
    required this.entryCount,
    required this.hours,
    required this.earnings,
    required this.kilometres,
    required this.textRepliesNeeded,
    required this.openActions,
  });

  final int entryCount;
  final double hours;
  final double earnings;
  final double kilometres;
  final int textRepliesNeeded;
  final int openActions;
}

class _WeeklyWorkSummary {
  const _WeeklyWorkSummary({
    required this.weekStart,
    required this.entryCount,
    required this.hours,
    required this.earnings,
    required this.kilometres,
    required this.textRepliesNeeded,
    required this.openActions,
  });

  final DateTime weekStart;
  final int entryCount;
  final double hours;
  final double earnings;
  final double kilometres;
  final int textRepliesNeeded;
  final int openActions;
}

class _WorkClientSummary {
  const _WorkClientSummary({
    required this.client,
    required this.entryCount,
    required this.hours,
    required this.averageHours,
    required this.earnings,
    required this.kilometres,
    required this.lastDate,
    required this.textCount,
    required this.textRepliesNeeded,
    required this.openActions,
  });

  final String client;
  final int entryCount;
  final double hours;
  final double averageHours;
  final double earnings;
  final double kilometres;
  final DateTime lastDate;
  final int textCount;
  final int textRepliesNeeded;
  final int openActions;
}

class _WorkTypeSummary {
  const _WorkTypeSummary({
    required this.label,
    required this.entryCount,
    required this.hours,
    required this.earnings,
    required this.kilometres,
    required this.textRepliesNeeded,
    required this.openActions,
  });

  final String label;
  final int entryCount;
  final double hours;
  final double earnings;
  final double kilometres;
  final int textRepliesNeeded;
  final int openActions;
}

class _BodyWeightTrend {
  const _BodyWeightTrend({required this.signal, required this.detail});

  final String signal;
  final String detail;
}

class _PersonalWorkoutDaySummary {
  const _PersonalWorkoutDaySummary({
    required this.date,
    required this.entries,
    required this.logCount,
    required this.exerciseCount,
    required this.mainMetric,
    required this.notesPreview,
  });

  final DateTime date;
  final List<PersonalLogEntry> entries;
  final int logCount;
  final int exerciseCount;
  final String mainMetric;
  final String notesPreview;
}

class _PersonalWeeklySummary {
  const _PersonalWeeklySummary({
    required this.weekStart,
    required this.totalLogs,
    required this.gymSessions,
    required this.bodyWeightLogs,
    required this.healthLogs,
  });

  final DateTime weekStart;
  final int totalLogs;
  final int gymSessions;
  final int bodyWeightLogs;
  final int healthLogs;
}

class _PersonalGymSummary {
  const _PersonalGymSummary({
    required this.exercise,
    required this.sessionCount,
    required this.lastDate,
    required this.latestMetric,
    required this.latestNotes,
  });

  final String exercise;
  final int sessionCount;
  final DateTime lastDate;
  final String latestMetric;
  final String latestNotes;
}
