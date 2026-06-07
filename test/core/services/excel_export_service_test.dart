import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/models/app_settings.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/personal_log_entry.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/core/services/excel_export_service.dart';

void main() {
  test('live work workbook uses short phone friendly note bullets', () {
    final now = DateTime(2026, 6, 7);
    final result = const ExcelExportService().buildLiveWorkDriveWorkbook(
      entries: [
        WorkEntry(
          id: 'entry-1',
          client: 'AB',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 7),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const [
            'First long note sentence that should be clipped for phone views.',
            'Second note',
            'Third note',
            'Fourth note should not be included',
          ],
          supportNoteBreakdown:
              'Support note breakdown should not appear after three bullets.',
          nextActions: [
            NextActionItem(
              id: 'action-1',
              text: 'Follow up with a very long provider action tomorrow',
              createdAt: now,
            ),
            NextActionItem(
              id: 'action-2',
              text: 'Completed safety plan update',
              createdAt: now,
              completedAt: now.add(const Duration(hours: 2)),
            ),
          ],
        ),
      ],
      settings: const AppSettings(),
    );

    final text = _workbookText(result);

    expect(text, contains('- First long note sentence that'));
    expect(text, contains('\n- Second note'));
    expect(text, isNot(contains('- Third note')));
    expect(text, isNot(contains('Fourth note should not be included')));
    expect(text, isNot(contains("Instance of 'num'")));
    expect(text, contains('Next Actions'));
    expect(text, contains('Not updated'));
    expect(text, contains('Completed'));
  });

  test('next actions workbook includes completed and not updated statuses', () {
    final now = DateTime(2026, 6, 7);
    final result = const ExcelExportService().buildNextActionsWorkbook(
      fileName: 'PAYE Next Actions - Live.xlsx',
      title: 'PAYE Next Actions',
      entries: [
        WorkEntry(
          id: 'entry-1',
          client: 'Jane',
          type: EntryType.phoneCall,
          date: now,
          startTime: const TimeOfDay(hour: 11, minute: 0),
          minutes: 30,
          notes: const [],
          nextActions: [
            NextActionItem(id: 'action-1', text: 'Send plan', createdAt: now),
            NextActionItem(
              id: 'action-2',
              text: 'Confirm appointment',
              createdAt: now,
              completedAt: now.add(const Duration(days: 1)),
            ),
          ],
        ),
      ],
    );

    final text = _workbookText(result);

    expect(result.fileName, 'PAYE Next Actions - Live.xlsx');
    expect(text, contains('PAYE Next Actions'));
    expect(text, contains('Send plan'));
    expect(text, contains('Not updated'));
    expect(text, contains('Confirm appointment'));
    expect(text, contains('Completed'));
  });

  test('live personal workbook uses short phone friendly note bullets', () {
    final result = const ExcelExportService().buildLivePersonalDriveWorkbook(
      entries: [
        PersonalLogEntry(
          id: 'personal-1',
          category: PersonalLogCategory.gym,
          date: DateTime(2026, 6, 7),
          title: 'Bench press',
          metric: '80 kg x 5',
          notes:
              'Warmup felt good; top set moved well; stop before shoulder pain',
        ),
        PersonalLogEntry(
          id: 'personal-2',
          category: PersonalLogCategory.gym,
          date: DateTime(2026, 6, 8),
          title: 'Pull: Row',
          metric: '60 kg x 8',
          notes: 'Back tight. Good control. More reps next time.',
        ),
      ],
    );

    final excel = Excel.decodeBytes(result.bytes);
    final text = _workbookText(result);

    expect(text, contains('- Warmup felt good'));
    expect(text, contains('- top set moved well'));
    expect(text, isNot(contains('stop before shoulder pain')));
    expect(
      excel.sheets.keys,
      containsAll(['Workout Days', 'Gym 2026-06-07', 'Gym 2026-06-08']),
    );
    expect(text, contains('Personal Logs'));
  });
}

String _workbookText(ExcelWorkbookResult result) {
  final excel = Excel.decodeBytes(result.bytes);

  return excel.sheets.values
      .expand((sheet) => sheet.rows)
      .expand((row) => row)
      .map((cell) => cell?.value.toString() ?? '')
      .join('\n');
}
