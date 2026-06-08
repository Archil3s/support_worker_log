import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/work_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/stat_grid.dart';

class AdminReviewScreen extends StatelessWidget {
  const AdminReviewScreen({
    super.key,
    required this.onEntries,
    required this.onCalendar,
    required this.onDrive,
    required this.onQuickEntry,
  });

  final VoidCallback onEntries;
  final VoidCallback onCalendar;
  final VoidCallback onDrive;
  final VoidCallback onQuickEntry;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final review = AdminReviewSnapshot.fromEntries(appState.entries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        StatGrid(
          cards: [
            StatCard(title: 'Replies', value: '${review.replyNeeded.length}'),
            StatCard(title: 'Calendar', value: '${review.calendarGaps.length}'),
            StatCard(title: 'Notes', value: '${review.missingNotes.length}'),
            StatCard(title: 'Actions', value: '${review.openActions.length}'),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Finish Admin',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onQuickEntry,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Entry'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: onEntries,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Edit Entries'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _syncDrive(context),
                icon: const Icon(Icons.cloud_sync_outlined),
                label: const Text('Sync Drive'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onDrive,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open Drive'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          title: 'Texts Needing Reply',
          emptyMessage: 'No text replies waiting.',
          entries: review.replyNeeded,
          actionsBuilder: (entry) => [
            _EntryAction(
              icon: Icons.check_circle_outline,
              label: 'Mark reply done',
              onPressed: () => _markReplyDone(context, entry),
            ),
            _EntryAction(
              icon: Icons.edit_note_outlined,
              label: 'Edit',
              onPressed: onEntries,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          title: 'Needs Calendar',
          emptyMessage: 'All saved entries are marked in calendar.',
          entries: review.calendarGaps,
          actionsBuilder: (entry) => [
            _EntryAction(
              icon: Icons.calendar_month_outlined,
              label: 'Create event',
              onPressed: () => _createCalendarEvent(context, entry),
            ),
            _EntryAction(
              icon: Icons.calendar_view_week_outlined,
              label: 'Calendar',
              onPressed: onCalendar,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          title: 'Missing Note Detail',
          emptyMessage: 'All entries have note detail.',
          entries: review.missingNotes,
          actionsBuilder: (entry) => [
            _EntryAction(
              icon: Icons.edit_note_outlined,
              label: 'Open entries',
              onPressed: onEntries,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          title: 'Open Next Actions',
          emptyMessage: 'No open next actions.',
          entries: review.openActions,
          actionsBuilder: (entry) => [
            _EntryAction(
              icon: Icons.done_all_outlined,
              label: 'Mark done',
              onPressed: () => _completeOpenActions(context, entry),
            ),
            _EntryAction(
              icon: Icons.edit_note_outlined,
              label: 'Edit',
              onPressed: onEntries,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          title: 'Important Texts',
          emptyMessage: 'No important texts in the last 7 days.',
          entries: review.recentImportantTexts,
          actionsBuilder: (entry) => [
            _EntryAction(
              icon: Icons.edit_note_outlined,
              label: 'Review',
              onPressed: onEntries,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _syncDrive(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    try {
      await context.read<AppState>().syncNow();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Drive sync queued.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Drive sync failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _createCalendarEvent(
    BuildContext context,
    WorkEntry entry,
  ) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    try {
      await appState.createPrivateGoogleCalendarEvent(entry);
      appState.updateEntry(entry.copyWith(googleCalendarEntered: true));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Calendar draft opened. Review and save it.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Calendar failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _markReplyDone(BuildContext context, WorkEntry entry) {
    final updatedActions = entry.nextActions.map((action) {
      if (action.isCompleted) return action;
      return action.copyWith(completedAt: DateTime.now());
    }).toList();

    context.read<AppState>().updateEntry(
      entry.copyWith(textReplyNeeded: false, nextActions: updatedActions),
    );
  }

  void _completeOpenActions(BuildContext context, WorkEntry entry) {
    final updatedActions = entry.nextActions.map((action) {
      if (action.isCompleted) return action;
      return action.copyWith(completedAt: DateTime.now());
    }).toList();

    context.read<AppState>().updateEntry(
      entry.copyWith(
        nextActions: updatedActions,
        textReplyNeeded: entry.type == EntryType.textNote
            ? false
            : entry.textReplyNeeded,
      ),
    );
  }
}

class AdminReviewSnapshot {
  const AdminReviewSnapshot({
    required this.replyNeeded,
    required this.calendarGaps,
    required this.missingNotes,
    required this.openActions,
    required this.recentImportantTexts,
  });

  final List<WorkEntry> replyNeeded;
  final List<WorkEntry> calendarGaps;
  final List<WorkEntry> missingNotes;
  final List<WorkEntry> openActions;
  final List<WorkEntry> recentImportantTexts;

  factory AdminReviewSnapshot.fromEntries(List<WorkEntry> entries) {
    final sorted = entries.toList()..sort(_newestFirst);
    final recentStart = DateTime.now().subtract(const Duration(days: 7));

    return AdminReviewSnapshot(
      replyNeeded: sorted
          .where((entry) => entry.type == EntryType.textNote)
          .where((entry) => entry.textReplyNeeded)
          .toList(),
      calendarGaps: sorted
          .where((entry) => !entry.googleCalendarEntered)
          .toList(),
      missingNotes: sorted
          .where((entry) => entry.supportNoteBreakdown.trim().isEmpty)
          .toList(),
      openActions: sorted
          .where(
            (entry) => entry.nextActions.any((action) => !action.isCompleted),
          )
          .toList(),
      recentImportantTexts: sorted
          .where((entry) => entry.type == EntryType.textNote)
          .where((entry) => entry.importantText)
          .where((entry) => !entry.date.isBefore(_dateOnly(recentStart)))
          .toList(),
    );
  }

  static int _newestFirst(WorkEntry a, WorkEntry b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;

    final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
    final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
    return bMinutes.compareTo(aMinutes);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.emptyMessage,
    required this.entries,
    required this.actionsBuilder,
  });

  final String title;
  final String emptyMessage;
  final List<WorkEntry> entries;
  final List<_EntryAction> Function(WorkEntry entry) actionsBuilder;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: entries.isEmpty
          ? EmptyState(message: emptyMessage)
          : Column(
              children: [
                for (final entry in entries.take(5)) ...[
                  _AdminEntryTile(entry: entry, actions: actionsBuilder(entry)),
                  if (entry != entries.take(5).last)
                    const Divider(height: 18, color: Color(0xFF34405F)),
                ],
                if (entries.length > 5) ...[
                  const SizedBox(height: 10),
                  Text(
                    '+${entries.length - 5} more',
                    style: const TextStyle(
                      color: Color(0xFF8396C7),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _AdminEntryTile extends StatelessWidget {
  const _AdminEntryTile({required this.entry, required this.actions});

  final WorkEntry entry;
  final List<_EntryAction> actions;

  @override
  Widget build(BuildContext context) {
    final openActions = entry.nextActions
        .where((action) => !action.isCompleted)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF13294D),
              foregroundColor: const Color(0xFF4F8DF7),
              child: Icon(entry.type.icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.client,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.type.label} | ${formatDate(entry.date)} | ${formatTime(entry.startTime)}',
                    style: const TextStyle(color: Color(0xFF8396C7)),
                  ),
                  if (entry.type == EntryType.textNote) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${entry.textContactDirection.label} | '
                      '${entry.importantText ? 'Important' : 'Not important'} | '
                      '${entry.textReplyNeeded ? 'Reply needed' : 'No reply needed'}',
                      style: const TextStyle(color: Color(0xFFD8E2FF)),
                    ),
                  ],
                  if (openActions > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$openActions open action${openActions == 1 ? '' : 's'}',
                      style: const TextStyle(color: Color(0xFFFFD166)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in actions)
              OutlinedButton.icon(
                onPressed: action.onPressed,
                icon: Icon(action.icon, size: 18),
                label: Text(action.label),
              ),
          ],
        ),
      ],
    );
  }
}

class _EntryAction {
  const _EntryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}
