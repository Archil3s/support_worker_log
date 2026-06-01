import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/features/admin_review/admin_review_screen.dart';

void main() {
  test('snapshot groups admin review work queues', () {
    final entries = [
      WorkEntry(
        id: 'reply',
        client: 'AB',
        type: EntryType.textNote,
        date: DateTime.now(),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 5,
        notes: const [],
        importantText: true,
        textReplyNeeded: true,
        nextActions: [
          NextActionItem(
            id: 'action-1',
            text: 'Reply to AB',
            createdAt: DateTime.now(),
          ),
        ],
      ),
      WorkEntry(
        id: 'missing',
        client: 'CD',
        type: EntryType.homeVisit,
        date: DateTime.now(),
        startTime: const TimeOfDay(hour: 10, minute: 0),
        minutes: 30,
        notes: const [],
        googleCalendarEntered: true,
      ),
      WorkEntry(
        id: 'done',
        client: 'EF',
        type: EntryType.phoneCall,
        date: DateTime.now(),
        startTime: const TimeOfDay(hour: 11, minute: 0),
        minutes: 15,
        notes: const [],
        supportNoteBreakdown: 'Outcome(s)\nDone.',
        googleCalendarEntered: true,
      ),
    ];

    final snapshot = AdminReviewSnapshot.fromEntries(entries);

    expect(snapshot.replyNeeded.map((entry) => entry.id), ['reply']);
    expect(snapshot.calendarGaps.map((entry) => entry.id), ['reply']);
    expect(snapshot.missingNotes.map((entry) => entry.id), [
      'missing',
      'reply',
    ]);
    expect(snapshot.openActions.map((entry) => entry.id), ['reply']);
    expect(snapshot.recentImportantTexts.map((entry) => entry.id), ['reply']);
  });
}
