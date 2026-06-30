import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/models/app_mode.dart';
import 'package:support_worker_log/core/models/app_settings.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/core/services/local_support_note_service.dart';
import 'package:support_worker_log/core/services/storage_service.dart';
import 'package:support_worker_log/core/state/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PAYE people deletion does not remove Work clients', () async {
    final state = AppState(warmGoogleAccounts: false);
    addTearDown(state.dispose);

    expect(state.addClient('Work client'), isTrue);
    state.setAppMode(AppMode.paye);
    expect(state.addClient('PAYE person'), isTrue);
    expect(state.addClient('PAYE second'), isTrue);

    expect(state.workClients, ['Work client']);
    expect(state.payeClients, ['PAYE person', 'PAYE second']);

    expect(state.removePayeClientFromList('PAYE person'), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(state.workClients, ['Work client']);
    expect(state.payeClients, ['PAYE second']);
  });

  test('clearing PAYE people leaves Work clients alone', () async {
    final state = AppState(warmGoogleAccounts: false);
    addTearDown(state.dispose);

    expect(state.addClient('Work client'), isTrue);
    state.setAppMode(AppMode.paye);
    expect(state.addClient('PAYE person'), isTrue);
    expect(state.addClient('PAYE second'), isTrue);

    expect(state.clearPayeClientList(), 2);
    await Future<void>.delayed(Duration.zero);

    expect(state.workClients, ['Work client']);
    expect(state.payeClients, isEmpty);
  });

  test(
    'load migrates local support note status into synced app data',
    () async {
      final entry = WorkEntry(
        id: 'entry-1',
        client: 'Brad Roberts',
        type: EntryType.professionalContact,
        date: DateTime(2026, 6, 26),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 14,
        notes: const [],
      );
      final storedData = StoredAppData(
        settings: const AppSettings(),
        clients: const ['Brad Roberts'],
        entries: [entry],
      );
      const noteMeta = EntrySupportNoteMeta(
        entryId: 'entry-1',
        initials: 'Brad Roberts',
        status: EntrySupportNoteStatus.submitted,
        fileName: 'Brad Roberts/2026-06-26_Brad Roberts_submitted.docx',
        noteText: 'Submitted note text.',
      );
      SharedPreferences.setMockInitialValues({
        'support_worker_log_data_v1': jsonEncode(storedData.toJson()),
        'entry_local_support_note_entry-1': jsonEncode(noteMeta.toJson()),
      });

      final state = AppState(warmGoogleAccounts: false);
      addTearDown(state.dispose);

      await state.load();

      expect(
        state.supportNoteMetaFor('entry-1')?.status,
        EntrySupportNoteStatus.submitted,
      );
      expect(state.supportNoteMetaFor('entry-1')?.initials, 'Brad Roberts');
    },
  );

  test(
    'load keeps deleted entries hidden but preserves note metadata',
    () async {
      final entry = WorkEntry(
        id: 'entry-1',
        client: 'Brad Roberts',
        type: EntryType.professionalContact,
        date: DateTime(2026, 6, 26),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 14,
        notes: const [],
      );
      const noteMeta = EntrySupportNoteMeta(
        entryId: 'entry-1',
        initials: 'Brad Roberts',
        status: EntrySupportNoteStatus.submitted,
        fileName: 'Brad Roberts/2026-06-26_Brad Roberts_submitted.docx',
        noteText: 'Submitted note text.',
      );
      final storedData = StoredAppData(
        settings: const AppSettings(),
        clients: const ['Brad Roberts'],
        entries: [entry],
        supportNoteMetas: const {'entry-1': noteMeta},
        deletedEntryIds: const {'entry-1'},
      );
      SharedPreferences.setMockInitialValues({
        'support_worker_log_data_v1': jsonEncode(storedData.toJson()),
      });

      final state = AppState(warmGoogleAccounts: false);
      addTearDown(state.dispose);

      await state.load();

      expect(state.entries, isEmpty);
      expect(
        state.supportNoteMetaFor('entry-1')?.status,
        EntrySupportNoteStatus.submitted,
      );
    },
  );

  test('deleteEntry tombstones the row and keeps note metadata', () async {
    final entry = WorkEntry(
      id: 'entry-1',
      client: 'Brad Roberts',
      type: EntryType.professionalContact,
      date: DateTime(2026, 6, 26),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      minutes: 14,
      notes: const [],
    );
    const noteMeta = EntrySupportNoteMeta(
      entryId: 'entry-1',
      initials: 'Brad Roberts',
      status: EntrySupportNoteStatus.submitted,
      fileName: 'Brad Roberts/2026-06-26_Brad Roberts_submitted.docx',
      noteText: 'Submitted note text.',
    );
    final storedData = StoredAppData(
      settings: const AppSettings(),
      clients: const ['Brad Roberts'],
      entries: [entry],
      supportNoteMetas: const {'entry-1': noteMeta},
    );
    SharedPreferences.setMockInitialValues({
      'support_worker_log_data_v1': jsonEncode(storedData.toJson()),
    });

    final state = AppState(warmGoogleAccounts: false);
    addTearDown(state.dispose);

    await state.load();

    final removed = state.deleteEntry(entry);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('support_worker_log_data_v1');
    final restored = StoredAppData.fromJson(
      jsonDecode(saved!) as Map<String, dynamic>,
    );

    expect(removed?.entry.id, 'entry-1');
    expect(state.entries, isEmpty);
    expect(state.supportNoteMetaFor('entry-1')?.status, noteMeta.status);
    expect(restored.deletedEntryIds, {'entry-1'});
    expect(restored.supportNoteMetas['entry-1']?.status, noteMeta.status);
  });
}
