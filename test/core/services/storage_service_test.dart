import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:support_worker_log/core/models/app_mode.dart';
import 'package:support_worker_log/core/models/app_settings.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/general_action.dart';
import 'package:support_worker_log/core/models/invoice_status.dart';
import 'package:support_worker_log/core/models/personal_log_entry.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/core/services/google_drive_service.dart';
import 'package:support_worker_log/core/services/local_support_note_service.dart';
import 'package:support_worker_log/core/services/storage_service.dart';

void main() {
  test('persists invoice status baselines', () {
    const data = StoredAppData(
      settings: AppSettings(),
      clients: ['AB'],
      entries: [],
      invoiceStatuses: {'2026-06-01_2026-06-14': InvoiceStatus.submitted},
      invoiceBaselineTotals: {'2026-06-01_2026-06-14': 125.75},
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(
      restored.invoiceStatuses['2026-06-01_2026-06-14'],
      InvoiceStatus.submitted,
    );
    expect(restored.invoiceBaselineTotals['2026-06-01_2026-06-14'], 125.75);
  });

  test('persists mixed general actions', () {
    final createdAt = DateTime(2026, 6, 2, 9);
    final completedAt = DateTime(2026, 6, 2, 10);
    final data = StoredAppData(
      settings: const AppSettings(),
      clients: const ['AB'],
      entries: const [],
      generalActions: [
        GeneralActionItem(
          id: 'action-1',
          title: 'Check consent wording',
          scope: GeneralActionScope.knowledgeGap,
          createdAt: createdAt,
          completedAt: completedAt,
        ),
        GeneralActionItem(
          id: 'action-2',
          title: 'Call GP',
          scope: GeneralActionScope.client,
          client: 'AB',
          createdAt: createdAt,
        ),
      ],
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(restored.generalActions, hasLength(2));
    expect(
      restored.generalActions.first.scope,
      GeneralActionScope.knowledgeGap,
    );
    expect(restored.generalActions.first.completedAt, completedAt);
    expect(restored.generalActions.last.client, 'AB');
  });

  test('persists app mode and personal logs separately from work entries', () {
    final data = StoredAppData(
      settings: const AppSettings(),
      clients: const ['AB'],
      entries: const [],
      appMode: AppMode.personal,
      personalLogEntries: [
        PersonalLogEntry(
          id: 'personal-1',
          category: PersonalLogCategory.gym,
          date: DateTime(2026, 6, 4, 7),
          title: 'Leg day',
          metric: 'Squat 3x5 at 80kg',
          notes: 'Good depth and stable knees.',
        ),
      ],
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(restored.appMode, AppMode.personal);
    expect(restored.entries, isEmpty);
    expect(restored.personalLogEntries, hasLength(1));
    expect(
      restored.personalLogEntries.single.category,
      PersonalLogCategory.gym,
    );
    expect(restored.personalLogEntries.single.metric, 'Squat 3x5 at 80kg');
  });

  test('persists PAYE logs separately from invoice work entries', () {
    final data = StoredAppData(
      settings: const AppSettings(),
      clients: const ['AB'],
      payeClients: const ['PAYE job'],
      entries: [
        WorkEntry(
          id: 'work-1',
          client: 'AB',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 7),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const ['Invoice work'],
        ),
      ],
      payeEntries: [
        WorkEntry(
          id: 'paye-1',
          client: 'PAYE job',
          type: EntryType.professionalContact,
          date: DateTime(2026, 6, 8),
          startTime: const TimeOfDay(hour: 8, minute: 30),
          minutes: 0,
          notes: const ['Blank shift note'],
        ),
      ],
      appMode: AppMode.paye,
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(restored.clients, ['AB']);
    expect(restored.payeClients, ['PAYE job']);
    expect(restored.entries, hasLength(1));
    expect(restored.entries.single.client, 'AB');
    expect(restored.payeEntries, hasLength(1));
    expect(restored.payeEntries.single.client, 'PAYE job');
    expect(restored.payeEntries.single.minutes, 0);
    expect(restored.appMode, AppMode.paye);
  });

  test('persists support note metadata for Firebase sync', () {
    const data = StoredAppData(
      settings: AppSettings(),
      clients: ['Brad Roberts'],
      entries: [],
      supportNoteMetas: {
        'entry-1': EntrySupportNoteMeta(
          entryId: 'entry-1',
          initials: 'Brad Roberts',
          status: EntrySupportNoteStatus.submitted,
          fileName: 'Brad Roberts/2026-06-26_Brad Roberts_submitted.docx',
          noteText: 'Submitted support note text.',
        ),
      },
      driveSupportNoteMetas: {
        'entry-1': EntryDriveSupportNoteMeta(
          entryId: 'entry-1',
          initials: 'Brad Roberts',
          status: EntrySupportNoteStatus.submitted,
          fileId: 'drive-file-1',
          fileName: 'Brad Roberts | 26/06/2026 | Submitted',
          noteText: 'Submitted support note text.',
          parentFolderId: 'drive-folder-1',
          webViewLink: 'https://docs.google.com/document/d/drive-file-1/edit',
          googleAccountEmail: 'brad@example.com',
        ),
      },
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(
      restored.supportNoteMetas['entry-1']?.status,
      EntrySupportNoteStatus.submitted,
    );
    expect(restored.supportNoteMetas['entry-1']?.initials, 'Brad Roberts');
    expect(
      restored.driveSupportNoteMetas['entry-1']?.status,
      EntrySupportNoteStatus.submitted,
    );
    expect(
      restored.driveSupportNoteMetas['entry-1']?.webViewLink,
      'https://docs.google.com/document/d/drive-file-1/edit',
    );
  });

  test('persists deleted entry ids for cloud merge tombstones', () {
    const data = StoredAppData(
      settings: AppSettings(),
      clients: ['Brad Roberts'],
      entries: [],
      payeEntries: [],
      deletedEntryIds: {'entry-1'},
      deletedPayeEntryIds: {'paye-entry-1'},
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(restored.deletedEntryIds, {'entry-1'});
    expect(restored.deletedPayeEntryIds, {'paye-entry-1'});
  });

  test('legacy data derives PAYE people only from PAYE entries', () {
    final restored = StoredAppData.fromJson({
      'settings': const AppSettings().toJson(),
      'clients': ['Contractor A', 'Contractor B'],
      'entries': [
        WorkEntry(
          id: 'work-1',
          client: 'Contractor A',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 7),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          minutes: 60,
          notes: const [],
        ).toJson(),
      ],
      'payeEntries': [
        WorkEntry(
          id: 'paye-1',
          client: 'PAYE person',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 8),
          startTime: const TimeOfDay(hour: 8, minute: 30),
          minutes: 0,
          notes: const [],
        ).toJson(),
      ],
      'appMode': AppMode.paye.name,
    });

    expect(restored.clients, ['Contractor A', 'Contractor B']);
    expect(restored.payeClients, ['PAYE person']);
  });

  test('explicit empty PAYE people list stays empty', () {
    final restored = StoredAppData.fromJson({
      'settings': const AppSettings().toJson(),
      'clients': ['Contractor A'],
      'payeClients': <String>[],
      'entries': <Map<String, dynamic>>[],
      'payeEntries': [
        WorkEntry(
          id: 'paye-1',
          client: 'Old PAYE person',
          type: EntryType.homeVisit,
          date: DateTime(2026, 6, 8),
          startTime: const TimeOfDay(hour: 8, minute: 30),
          minutes: 0,
          notes: const [],
        ).toJson(),
      ],
      'appMode': AppMode.paye.name,
    });

    expect(restored.clients, ['Contractor A']);
    expect(restored.payeClients, isEmpty);
  });

  test('persists massage app mode', () {
    const data = StoredAppData(
      settings: AppSettings(),
      clients: ['AB'],
      entries: [],
      appMode: AppMode.massage,
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(restored.appMode, AppMode.massage);
  });

  test('persists mood and testosterone app mode', () {
    const data = StoredAppData(
      settings: AppSettings(),
      clients: ['AB'],
      entries: [],
      appMode: AppMode.mood,
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(restored.appMode, AppMode.mood);
  });

  test('persists grocery app mode', () {
    const data = StoredAppData(
      settings: AppSettings(),
      clients: ['AB'],
      entries: [],
      appMode: AppMode.grocery,
    );

    final restored = StoredAppData.fromJson(data.toJson());

    expect(restored.appMode, AppMode.grocery);
  });
}
