// ignore_for_file: prefer_collection_literals
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/active_visit.dart';
import '../../core/models/entry_type.dart';
import '../../core/models/google_export_account_scope.dart';
import '../../core/models/work_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/google_account_connection_card.dart';
import '../entries/local_support_note_button.dart';

String _cleanHeaderText(String value) {
  return value
      .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E]'), '')
      .replaceAll(RegExp(r'\s+\n'), '\n')
      .replaceAll(RegExp(r'\n\s+'), '\n')
      .trim();
}

String _calendarErrorText(Object error) {
  final text = error.toString().trim();

  if (text.startsWith('Bad state: ')) {
    return text.replaceFirst('Bad state: ', '').trim();
  }

  return text.isEmpty ? 'Google Calendar sync failed.' : text;
}

List<NextActionItem> _nextActionsFromBreakdown(String value) {
  final lines = value.split(RegExp(r'\r?\n'));
  final actions = <NextActionItem>[];
  final now = DateTime.now();
  var inNextActions = false;

  for (final line in lines) {
    final trimmed = line.trim();
    final normalized = trimmed.toLowerCase();

    if (normalized.startsWith('next action')) {
      inNextActions = true;
      continue;
    }

    if (inNextActions &&
        (normalized.startsWith('overall impression') ||
            normalized.startsWith('main topic') ||
            normalized.startsWith('outcome'))) {
      break;
    }

    if (!inNextActions || trimmed.isEmpty) continue;

    final text = trimmed
        .replaceFirst(RegExp(r'^\d+[\.)]\s*'), '')
        .replaceFirst(RegExp(r'^[-*]\s*'), '')
        .trim();

    if (text.isEmpty) continue;

    actions.add(
      NextActionItem(
        id: '${now.microsecondsSinceEpoch}-${actions.length}',
        text: text,
        createdAt: now,
      ),
    );
  }

  return actions;
}

const _mainTopicMaxWords = 200;
const _outcomeMaxWords = 100;
const _impressionMaxWords = 150;
const _supportTagPrefix = 'Tag: ';
const _attendancePrefix = 'Attendance: ';
const _attendanceOptions = [
  'Client',
  'Support worker',
  'Social worker',
  'Social support worker',
  'Whanau / family',
  'Agency worker',
  'Peer support',
  'Supervisor / manager',
  'Other professional',
];
const _supportTagOptions = [
  'Attendance support worker',
  '2-up visit',
  'Worked on goals',
  'Worked on housing diary',
  'Visited house viewings',
  'Potential pet',
  'Rubbish piling up',
  'Home messy',
];
const _blenheimAgencyOptions = [
  'Agency: Police / emergency services',
  'Agency: Fire and Emergency NZ',
  'Agency: Hato Hone St John',
  'Agency: Wairau Hospital / Emergency Department',
  'Agency: Marlborough Urgent Care',
  'Agency: Te Whatu Ora / Nelson Marlborough',
  'Agency: Marlborough PHO / Kimi Hauora Wairau',
  'Agency: Community Mental Health',
  'Agency: Mental Health Crisis Team',
  'Agency: Witherlea House / Adult Mental Health',
  'Agency: CAMHS',
  'Agency: Supporting Families Marlborough',
  'Agency: CARE Marlborough',
  'Agency: GP / medical centre',
  'Agency: Marlborough Sexual Violence Support Centre',
  'Agency: SASH Blenheim',
  "Agency: Marlborough Women's Refuge",
  'Agency: Victim Support',
  'Agency: Oranga Tamariki',
  'Agency: Barnardos Marlborough',
  'Agency: Birthright Marlborough',
  'Agency: Open Home Foundation Marlborough',
  'Agency: Wairau Youth and Family Trust',
  'Agency: Marlborough Youth Trust',
  'Agency: Youthline',
  'Agency: WINZ / MSD Blenheim',
  'Agency: Kainga Ora',
  'Agency: Housing First Blenheim',
  'Agency: Housing provider',
  'Agency: Marlborough District Council',
  'Agency: Te Piki Oranga',
  'Agency: Maataa Waka ki Te Tau Ihu Trust',
  'Agency: Marlborough Pacific Trust',
  'Agency: Marlborough Multicultural Centre',
  'Agency: MFR Voice',
  'Agency: Rainbow Marlborough / rainbow community support',
  'Agency: Salvation Army',
  "Agency: Crossroads / John's Kitchen",
  'Agency: Citizens Advice Bureau Marlborough',
  'Agency: Community Law Marlborough',
  'Agency: Presbyterian Support Marlborough / Family Works',
  'Agency: Access Community Health',
  'Agency: Age Concern Marlborough',
  'Agency: Tautoko Community Trust',
  'Agency: Maternal Wellbeing Marlborough',
  'Agency: ACC sensitive claims counselling',
  'Agency: Counselling service',
  'Agency: School / education',
  'Agency: Probation / Corrections',
  'Agency: Other local agency or service',
];

String _agencyDisplayLabel(String value) {
  return value.replaceFirst('Agency: ', '');
}

String _buildSupportNoteBreakdown({
  required String mainTopic,
  required String outcomes,
  required String nextActions,
  required String impression,
  required String referrals,
  required String safetyConcerns,
}) {
  return [
    'Main topic(s)  (max. 200 words)',
    _cleanSupportNoteSection(mainTopic),
    '',
    'Outcome(s)  (Max. 100 words)',
    _cleanSupportNoteSection(outcomes),
    '',
    'Next action(s)',
    _cleanSupportNoteSection(nextActions),
    '',
    'Overall impression (Max. 150 words)',
    _cleanSupportNoteSection(impression),
    '',
    'Local referral tracking',
    _cleanSupportNoteSection(referrals),
    '',
    'Safety concerns for sexual harm survivors and mental health',
    _cleanSupportNoteSection(safetyConcerns),
  ].join('\n').trim();
}

String _buildTextNoteBreakdown({
  required TextContactDirection direction,
  required String summary,
  required String nextActions,
  required bool replyNeeded,
}) {
  return [
    'Text direction',
    direction.label,
    '',
    'Text contact summary',
    _cleanSupportNoteSection(summary),
    '',
    'Reply needed',
    replyNeeded ? 'Reply or follow-up needed' : 'No full reply needed',
    '',
    'Next action(s)',
    _cleanSupportNoteSection(nextActions),
  ].join('\n').trim();
}

String _cleanSupportNoteSection(String value) {
  return value
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

String _joinLoggingLines(Iterable<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .join('\n');
}

String _initialMainTopicText(Iterable<String> values) {
  final output = <String>[];

  for (final rawValue in values) {
    final value = rawValue.trim();
    if (value.isEmpty) continue;

    if (value.startsWith(_attendancePrefix)) continue;

    if (value.startsWith('Tags: ')) {
      final tags = value
          .replaceFirst('Tags: ', '')
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty);

      for (final tag in tags) {
        output.add('- $tag');
      }

      continue;
    }

    output.add(value);
  }

  final text = output.toSet().join('\n');
  return text.isEmpty ? '' : '$text\n\n';
}

List<String> _buildVisitNotes({
  required Iterable<String> selectedNotes,
  String typedNote = '',
}) {
  final tags = <String>[];
  final attendance = <String>[];
  final agencies = <String>[];
  final topics = <String>[];

  for (final rawNote in selectedNotes) {
    final note = rawNote.trim();
    if (note.isEmpty) continue;

    if (note.startsWith(_supportTagPrefix)) {
      tags.add(note.replaceFirst(_supportTagPrefix, '').trim());
    } else if (note.startsWith(_attendancePrefix)) {
      attendance.add(note.replaceFirst(_attendancePrefix, '').trim());
    } else if (note.startsWith('Agency: ')) {
      agencies.add(note);
    } else {
      topics.add(note);
    }
  }

  final notes = <String>[
    if (attendance.isNotEmpty)
      'Attendance: ${_orderedAttendance(attendance).join(', ')}',
    if (tags.isNotEmpty) 'Tags: ${_orderedTags(tags).join(', ')}',
    if (topics.isNotEmpty) 'Topics covered: ${topics.toSet().join(', ')}',
    ...agencies.toSet(),
    if (typedNote.trim().isNotEmpty) typedNote.trim(),
  ];

  return notes;
}

List<String> _orderedAttendance(Iterable<String> values) {
  final selected = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  final ordered = <String>[
    for (final role in _attendanceOptions)
      if (selected.remove(role)) role,
    ...selected,
  ];

  return ordered;
}

List<String> _orderedTags(Iterable<String> values) {
  final selected = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  final ordered = <String>[
    for (final tag in _supportTagOptions)
      if (selected.remove(tag)) tag,
    ...selected,
  ];

  return ordered;
}

List<String> _rawVisitNotes({
  required Iterable<String> selectedNotes,
  String typedNote = '',
}) {
  final values = [
    ...selectedNotes.map((note) => note.trim()),
    if (typedNote.trim().isNotEmpty) typedNote.trim(),
  ].where((note) => note.isNotEmpty).toSet().toList();

  return values;
}

int _wordCount(String value) {
  return RegExp(r"[A-Za-z0-9]+(?:[-'][A-Za-z0-9]+)?").allMatches(value).length;
}

class QuickEntryScreen extends StatefulWidget {
  const QuickEntryScreen({super.key, this.onCalendar});

  final VoidCallback? onCalendar;

  @override
  State<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _TextNoteCloseOut {
  const _TextNoteCloseOut({
    required this.breakdown,
    required this.importantText,
    required this.textContactDirection,
    required this.textReplyNeeded,
  });

  final String breakdown;
  final bool importantText;
  final TextContactDirection textContactDirection;
  final bool textReplyNeeded;
}

enum _ReferralStatus { discussed, referred, engaged, declined, pending }

class _ReferralSelection {
  const _ReferralSelection({required this.service, required this.status});

  final String service;
  final _ReferralStatus status;
}

class _QuickEntryScreenState extends State<QuickEntryScreen> {
  final startOdometerController = TextEditingController();
  final finishOdometerController = TextEditingController();
  final noteController = TextEditingController();

  String? selectedClient;
  EntryType selectedType = EntryType.homeVisit;
  String? loadedActiveVisitId;
  WorkEntry? recentlySavedEntry;
  late DateTime selectedVisitDate;

  final selectedNotes = <String>{};

  @override
  void initState() {
    super.initState();
    selectedVisitDate = _dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    startOdometerController.dispose();
    finishOdometerController.dispose();
    noteController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _startDateTimeForSelectedDate() {
    final now = DateTime.now();
    final date = _dateOnly(selectedVisitDate);

    return DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  Future<void> _pickVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedVisitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked == null || !mounted) return;

    setState(() => selectedVisitDate = _dateOnly(picked));
  }

  double? _readDouble(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  int _minutesBetween(DateTime start, DateTime finish) {
    var end = finish;

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    final seconds = end.difference(start).inSeconds;
    return math.max(1, (seconds / 60).ceil()).clamp(1, 1440).toInt();
  }

  String _elapsedText(DateTime start, DateTime? finish) {
    final end = finish ?? DateTime.now();
    final duration = end.isAfter(start)
        ? end.difference(start)
        : end.add(const Duration(days: 1)).difference(start);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String _dateTimeText(BuildContext context, DateTime value) {
    final time = TimeOfDay.fromDateTime(value).format(context);
    return '${formatDate(value)} $time';
  }

  void _startVisit(AppState appState) {
    final client = selectedClient;

    if (client == null || client.trim().isEmpty) {
      _snack('Tap a client first.');
      return;
    }

    final notes = _rawVisitNotes(selectedNotes: selectedNotes);
    final startedAt = _startDateTimeForSelectedDate();
    final trackKilometres =
        !appState.isPayeMode && selectedType == EntryType.homeVisit;

    appState.startActiveVisit(
      ActiveVisit(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        client: client,
        type: selectedType,
        startedAt: startedAt,
        odometerStart: trackKilometres
            ? _readDouble(startOdometerController)
            : null,
        notes: notes,
      ),
    );

    setState(() {
      loadedActiveVisitId = null;
      selectedNotes.clear();
      startOdometerController.clear();
      noteController.clear();
    });
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  void _syncActiveVisit(ActiveVisit activeVisit) {
    if (loadedActiveVisitId == activeVisit.id) return;

    loadedActiveVisitId = activeVisit.id;
    selectedNotes
      ..clear()
      ..addAll(activeVisit.notes);
    startOdometerController.text =
        activeVisit.odometerStart?.toStringAsFixed(1) ?? '';
    finishOdometerController.clear();
    noteController.clear();
  }

  void _saveDraftNotes(AppState appState, ActiveVisit activeVisit) {
    final typedNote = noteController.text.trim();

    final notes = _rawVisitNotes(
      selectedNotes: [...activeVisit.notes, ...selectedNotes],
      typedNote: typedNote,
    );

    appState.updateActiveVisit(activeVisit.copyWith(notes: notes));

    setState(() {
      selectedNotes
        ..clear()
        ..addAll(notes);
      noteController.clear();
      loadedActiveVisitId = null;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  void _saveActiveVisitOdometer(AppState appState, ActiveVisit activeVisit) {
    final odometerStart = _readDouble(startOdometerController);

    if (odometerStart == null) {
      _snack('Add the starting odometer first.');
      return;
    }

    appState.updateActiveVisit(
      activeVisit.copyWith(odometerStart: odometerStart),
    );
    _snack('Starting odometer saved.');
  }

  Future<void> _finishVisit(AppState appState, ActiveVisit activeVisit) async {
    final trackKilometres =
        !appState.isPayeMode && activeVisit.type == EntryType.homeVisit;
    final finishOdometer = trackKilometres
        ? _readDouble(finishOdometerController)
        : null;

    if (trackKilometres &&
        activeVisit.odometerStart != null &&
        finishOdometer != null &&
        finishOdometer < activeVisit.odometerStart!) {
      _snack('Finish odometer must be higher than start odometer.');
      return;
    }

    final typedNote = noteController.text.trim();
    final notes = _buildVisitNotes(
      selectedNotes: [...activeVisit.notes, ...selectedNotes],
      typedNote: typedNote,
    );
    final previewMinutes = _minutesBetween(
      activeVisit.startedAt,
      DateTime.now(),
    );
    final kilometres =
        trackKilometres &&
            activeVisit.odometerStart != null &&
            finishOdometer != null
        ? math.max(0.0, finishOdometer - activeVisit.odometerStart!)
        : 0.0;

    final textCloseOut = activeVisit.type == EntryType.textNote
        ? await _promptTextNoteBreakdown(activeVisit: activeVisit, notes: notes)
        : null;
    final supportNoteBreakdown = activeVisit.type == EntryType.textNote
        ? textCloseOut?.breakdown
        : await _promptSupportNoteBreakdown(
            activeVisit: activeVisit,
            notes: notes,
            minutes: previewMinutes,
            kilometres: kilometres,
          );

    if (!mounted || supportNoteBreakdown == null) return;

    final visitMinutes = _minutesBetween(activeVisit.startedAt, DateTime.now());
    final trimmedSupportNoteBreakdown = supportNoteBreakdown.trim();

    final entry = WorkEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      client: activeVisit.client,
      type: activeVisit.type,
      date: DateTime(
        activeVisit.startedAt.year,
        activeVisit.startedAt.month,
        activeVisit.startedAt.day,
      ),
      startTime: TimeOfDay.fromDateTime(activeVisit.startedAt),
      minutes: visitMinutes,
      notes: notes,
      supportNoteBreakdown: trimmedSupportNoteBreakdown,
      nextActions: _nextActionsFromBreakdown(trimmedSupportNoteBreakdown),
      importantText: textCloseOut?.importantText ?? false,
      textContactDirection:
          textCloseOut?.textContactDirection ?? TextContactDirection.received,
      textReplyNeeded: textCloseOut?.textReplyNeeded ?? false,
      odometerStart: trackKilometres ? activeVisit.odometerStart : null,
      odometerEnd: trackKilometres ? finishOdometer : null,
    );

    setState(() {
      recentlySavedEntry = entry;
      loadedActiveVisitId = null;
      selectedNotes.clear();
      finishOdometerController.clear();
      noteController.clear();
    });

    appState.completeActiveVisit(entry);
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  Future<String?> _promptSupportNoteBreakdown({
    required ActiveVisit activeVisit,
    required List<String> notes,
    required int minutes,
    required double kilometres,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _SupportNoteBreakdownSheet(
          activeVisit: activeVisit,
          notes: notes,
          minutes: minutes,
          kilometres: kilometres,
        );
      },
    );
  }

  Future<_TextNoteCloseOut?> _promptTextNoteBreakdown({
    required ActiveVisit activeVisit,
    required List<String> notes,
  }) {
    return showModalBottomSheet<_TextNoteCloseOut>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _TextNoteBreakdownSheet(activeVisit: activeVisit, notes: notes);
      },
    );
  }

  Future<void> _confirmCancelVisit(
    AppState appState,
    ActiveVisit activeVisit,
  ) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel active visit?'),
          content: Text(
            'This will remove the active visit for ${activeVisit.client}. It will not create an entry.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Visit'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel Visit'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldCancel != true) return;

    appState.cancelActiveVisit();

    setState(() {
      loadedActiveVisitId = null;
      selectedNotes.clear();
      finishOdometerController.clear();
      noteController.clear();
    });
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  void _deleteSavedEntry(WorkEntry entry) {
    final appState = context.read<AppState>();
    final removed = appState.deleteEntry(entry);

    if (removed == null) return;

    setState(() {
      recentlySavedEntry = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            appState.restoreEntry(removed);
            if (mounted) {
              setState(() {
                recentlySavedEntry = removed.entry;
              });
            }
          },
        ),
      ),
    );
  }

  void _snack(String message) {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final clients = appState.clients;
    final activeVisit = appState.activeVisit;
    final showKilometres = !appState.isPayeMode;

    if (selectedClient == null && clients.isNotEmpty) {
      selectedClient = clients.first;
    }

    if (recentlySavedEntry != null && activeVisit == null) {
      return _SavedVisitView(
        entry: recentlySavedEntry!,
        onCalendar: widget.onCalendar,
        onEntryUpdated: (entry) {
          setState(() => recentlySavedEntry = entry);
        },
        onDelete: () => _deleteSavedEntry(recentlySavedEntry!),
        onNewVisit: () {
          setState(() {
            recentlySavedEntry = null;
          });
        },
      );
    }

    if (activeVisit != null) {
      _syncActiveVisit(activeVisit);
      return _ActiveVisitView(
        activeVisit: activeVisit,
        selectedNotes: selectedNotes,
        finishOdometerController: finishOdometerController,
        startOdometerController: startOdometerController,
        noteController: noteController,
        elapsedText: _elapsedText(activeVisit.startedAt, null),
        startedAtText: _dateTimeText(context, activeVisit.startedAt),
        showKilometres: showKilometres,
        onNoteToggle: (note, selected) {
          setState(() {
            if (selected) {
              selectedNotes.add(note);
            } else {
              selectedNotes.remove(note);
            }
          });
        },
        onSaveStartOdometer: () =>
            _saveActiveVisitOdometer(appState, activeVisit),
        onSaveDraft: () => _saveDraftNotes(appState, activeVisit),
        onFinish: () => unawaited(_finishVisit(appState, activeVisit)),
        onCancel: () => _confirmCancelVisit(appState, activeVisit),
      );
    }

    return _StartVisitView(
      clients: clients,
      selectedClient: selectedClient,
      selectedType: selectedType,
      selectedNotes: selectedNotes,
      visitDate: selectedVisitDate,
      startOdometerController: startOdometerController,
      showKilometres: showKilometres,
      showAttendance: appState.isPayeMode,
      onClientSelected: (client) {
        setState(() => selectedClient = client);
      },
      onTypeSelected: (type) {
        setState(() {
          selectedType = type;
          if (type != EntryType.homeVisit) {
            startOdometerController.clear();
          }
        });
      },
      onNoteToggle: (note, selected) {
        setState(() {
          if (selected) {
            selectedNotes.add(note);
          } else {
            selectedNotes.remove(note);
          }
        });
      },
      onUseToday: () {
        setState(() => selectedVisitDate = _dateOnly(DateTime.now()));
      },
      onUsePreviousDay: () {
        setState(
          () => selectedVisitDate = _dateOnly(
            selectedVisitDate.subtract(const Duration(days: 1)),
          ),
        );
      },
      onPickDate: _pickVisitDate,
      onStart: () => _startVisit(appState),
    );
  }
}

class _SupportNoteBreakdownSheet extends StatefulWidget {
  const _SupportNoteBreakdownSheet({
    required this.activeVisit,
    required this.notes,
    required this.minutes,
    required this.kilometres,
  });

  final ActiveVisit activeVisit;
  final List<String> notes;
  final int minutes;
  final double kilometres;

  @override
  State<_SupportNoteBreakdownSheet> createState() =>
      _SupportNoteBreakdownSheetState();
}

class _TextNoteBreakdownSheet extends StatefulWidget {
  const _TextNoteBreakdownSheet({
    required this.activeVisit,
    required this.notes,
  });

  final ActiveVisit activeVisit;
  final List<String> notes;

  @override
  State<_TextNoteBreakdownSheet> createState() =>
      _TextNoteBreakdownSheetState();
}

class _TextNoteBreakdownSheetState extends State<_TextNoteBreakdownSheet> {
  final summaryController = TextEditingController();
  final nextActionsController = TextEditingController();

  TextContactDirection textContactDirection = TextContactDirection.received;
  bool replyNeeded = false;
  bool importantText = false;
  int stepIndex = 0;

  @override
  void initState() {
    super.initState();
    summaryController.text = _joinLoggingLines(widget.notes);
  }

  @override
  void dispose() {
    summaryController.dispose();
    nextActionsController.dispose();
    super.dispose();
  }

  void _save() {
    final summary = _cleanSupportNoteSection(summaryController.text);
    final typedNextActions = _cleanSupportNoteSection(
      nextActionsController.text,
    );
    final nextActions = replyNeeded
        ? typedNextActions.isEmpty
              ? 'Reply to ${widget.activeVisit.client}.'
              : typedNextActions
        : '';

    if (summary.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text('Add the text contact summary before saving.'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      return;
    }

    Navigator.of(context).pop(
      _TextNoteCloseOut(
        breakdown: _buildTextNoteBreakdown(
          direction: textContactDirection,
          summary: summary,
          nextActions: nextActions,
          replyNeeded: replyNeeded,
        ),
        importantText: importantText,
        textContactDirection: textContactDirection,
        textReplyNeeded: replyNeeded,
      ),
    );
  }

  void _nextStep() {
    if (stepIndex >= 2) {
      _save();
      return;
    }

    setState(() => stepIndex += 1);
  }

  void _previousStep() {
    if (stepIndex == 0) return;
    setState(() => stepIndex -= 1);
  }

  Widget _stepBody() {
    switch (stepIndex) {
      case 0:
        return _PromptStep(
          title: 'Text Details',
          subtitle: 'Set direction and flags before writing the summary.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Panel(
                title: 'Text facts',
                child: Column(
                  children: [
                    _InfoRow(label: 'Client', value: widget.activeVisit.client),
                    _InfoRow(
                      label: 'Type',
                      value: widget.activeVisit.type.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<TextContactDirection>(
                segments: const [
                  ButtonSegment<TextContactDirection>(
                    value: TextContactDirection.received,
                    icon: Icon(Icons.call_received_outlined),
                    label: Text('Received'),
                  ),
                  ButtonSegment<TextContactDirection>(
                    value: TextContactDirection.sent,
                    icon: Icon(Icons.call_made_outlined),
                    label: Text('Sent'),
                  ),
                  ButtonSegment<TextContactDirection>(
                    value: TextContactDirection.exchange,
                    icon: Icon(Icons.sync_alt_outlined),
                    label: Text('Exchange'),
                  ),
                ],
                selected: {textContactDirection},
                onSelectionChanged: (values) {
                  setState(() => textContactDirection = values.first);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: importantText,
                onChanged: (value) => setState(() => importantText = value),
                title: const Text(
                  'Important text',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Important texts are marked in invoice text summaries.',
                  style: TextStyle(color: Color(0xFF8396C7)),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: replyNeeded,
                onChanged: (value) => setState(() => replyNeeded = value),
                title: const Text(
                  'Reply needed',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        );
      case 1:
        return _PromptStep(
          title: 'Message Summary',
          subtitle: 'Write the short record that will appear in the log.',
          child: _SupportNoteField(
            controller: summaryController,
            label: 'What was texted',
            hint: 'Short factual summary only.',
            helper: 'Keep this useful for a living communication log.',
            wordCount: _wordCount(summaryController.text),
            autofocus: true,
            expanded: true,
            onChanged: (_) => setState(() {}),
          ),
        );
      default:
        return _PromptStep(
          title: 'Reply / Follow-up',
          subtitle: replyNeeded
              ? 'Add the action that should stay open.'
              : 'No reply is needed for this text.',
          child: replyNeeded
              ? _SupportNoteField(
                  controller: nextActionsController,
                  label: 'Reply or follow-up',
                  hint: 'One action per line.',
                  helper: 'These become trackable open actions.',
                  wordCount: _wordCount(nextActionsController.text),
                  autofocus: true,
                  expanded: true,
                  onChanged: (_) => setState(() {}),
                )
              : const _NoActionPanel(message: 'No reply needed.'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PromptHeader(
              title: 'Text Note',
              currentStep: stepIndex,
              stepCount: 3,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: _stepBody())),
            const SizedBox(height: 14),
            _PromptNavButtons(
              isFirst: stepIndex == 0,
              isLast: stepIndex == 2,
              onBack: _previousStep,
              onNext: _nextStep,
              saveLabel: 'Save Text Note',
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportNoteBreakdownSheetState
    extends State<_SupportNoteBreakdownSheet> {
  final mainTopicController = TextEditingController();
  final outcomesController = TextEditingController();
  final nextActionsController = TextEditingController();
  final impressionController = TextEditingController();
  final referralNotesController = TextEditingController();
  final safetyConcernsController = TextEditingController();
  final referrals = <_ReferralSelection>[];

  bool noReferrals = true;
  bool noNextAction = false;
  bool noSafetyConcerns = true;
  int stepIndex = 0;

  @override
  void initState() {
    super.initState();
    mainTopicController.text = _initialMainTopicText(widget.notes);
    mainTopicController.selection = TextSelection.collapsed(
      offset: mainTopicController.text.length,
    );
  }

  @override
  void dispose() {
    mainTopicController.dispose();
    outcomesController.dispose();
    nextActionsController.dispose();
    impressionController.dispose();
    referralNotesController.dispose();
    safetyConcernsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (stepIndex >= 6) {
      _save();
      return;
    }

    setState(() => stepIndex += 1);
  }

  void _previousStep() {
    if (stepIndex == 0) return;
    setState(() => stepIndex -= 1);
  }

  void _save() {
    final mainTopic = _cleanSupportNoteSection(mainTopicController.text);
    final outcomes = _cleanSupportNoteSection(outcomesController.text);
    final impression = _cleanSupportNoteSection(impressionController.text);
    final nextActions = noNextAction
        ? ''
        : _cleanSupportNoteSection(nextActionsController.text);
    final safetyConcerns = noSafetyConcerns
        ? 'No safety concerns noted.'
        : _cleanSupportNoteSection(safetyConcernsController.text);
    final referralSummary = _referralSummary();

    final error = _validationError(
      mainTopic: mainTopic,
      outcomes: outcomes,
      impression: impression,
      referrals: referralSummary,
      safetyConcerns: safetyConcerns,
    );

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      return;
    }

    Navigator.of(context).pop(
      _buildSupportNoteBreakdown(
        mainTopic: mainTopic,
        outcomes: outcomes,
        nextActions: nextActions,
        impression: impression,
        referrals: referralSummary,
        safetyConcerns: safetyConcerns,
      ),
    );
  }

  String? _validationError({
    required String mainTopic,
    required String outcomes,
    required String impression,
    required String referrals,
    required String safetyConcerns,
  }) {
    if (mainTopic.isEmpty) return 'Add the main topic before saving.';
    if (outcomes.isEmpty) return 'Add the outcome before saving.';
    if (impression.isEmpty) return 'Add the overall impression before saving.';
    if (referrals.isEmpty) return 'Complete local referral tracking.';
    if (safetyConcerns.isEmpty) {
      return 'Add safety concerns or mark that none were noted.';
    }

    if (_wordCount(mainTopic) > _mainTopicMaxWords) {
      return 'Main topic is over $_mainTopicMaxWords words.';
    }

    if (_wordCount(outcomes) > _outcomeMaxWords) {
      return 'Outcome is over $_outcomeMaxWords words.';
    }

    if (_wordCount(impression) > _impressionMaxWords) {
      return 'Overall impression is over $_impressionMaxWords words.';
    }

    return null;
  }

  String _referralSummary() {
    if (noReferrals) return 'No referrals discussed or made this visit.';

    final lines = referrals
        .map(
          (item) =>
              '${_agencyDisplayLabel(item.service)}: ${item.status.label}',
        )
        .toList();
    final notes = _cleanSupportNoteSection(referralNotesController.text);

    if (notes.isNotEmpty) {
      lines.add('Referral notes: $notes');
    }

    return lines.join('\n');
  }

  void _toggleReferral(String service, _ReferralStatus status) {
    setState(() {
      final index = referrals.indexWhere(
        (item) => item.service == service && item.status == status,
      );

      if (index == -1) {
        referrals.add(_ReferralSelection(service: service, status: status));
      } else {
        referrals.removeAt(index);
      }

      noReferrals = referrals.isEmpty;
    });
  }

  void _appendLine(TextEditingController controller, String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    final current = controller.text.trim();
    controller.text = current.isEmpty ? cleaned : '$current\n$cleaned';
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    setState(() {});
  }

  Widget _stepBody() {
    switch (stepIndex) {
      case 0:
        return _visitFactsStep();
      case 1:
        return _PromptStep(
          title: 'Main Topic(s)',
          subtitle: 'Capture what support was provided.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.notes.isNotEmpty) ...[
                _Panel(
                  title: 'Logged notes',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final note in widget.notes)
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: Text(note),
                          onPressed: () =>
                              _appendLine(mainTopicController, note),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _SupportNoteField(
                controller: mainTopicController,
                label: 'Main topic(s)',
                hint: 'What support was provided?',
                helper: 'Include the core support themes only.',
                maxWords: _mainTopicMaxWords,
                wordCount: _wordCount(mainTopicController.text),
                autofocus: true,
                expanded: true,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        );
      case 2:
        return _PromptStep(
          title: 'Outcome(s)',
          subtitle: 'Record the concrete result of the interaction.',
          child: _SupportNoteField(
            controller: outcomesController,
            label: 'Outcome(s)',
            hint: 'What changed, improved, or was completed?',
            helper: 'Keep the result specific and factual.',
            maxWords: _outcomeMaxWords,
            wordCount: _wordCount(outcomesController.text),
            autofocus: true,
            expanded: true,
            onChanged: (_) => setState(() {}),
          ),
        );
      case 3:
        return _PromptStep(
          title: 'Next Action(s)',
          subtitle: 'Add follow-up items or mark none needed.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('No next action needed'),
                subtitle: const Text(
                  'Leave follow-up blank when there is nothing to track.',
                ),
                value: noNextAction,
                onChanged: (value) {
                  setState(() {
                    noNextAction = value;
                    if (value) nextActionsController.clear();
                  });
                },
              ),
              const SizedBox(height: 8),
              if (noNextAction)
                const _NoActionPanel(message: 'No next action needed.')
              else
                _SupportNoteField(
                  controller: nextActionsController,
                  label: 'Next action(s)',
                  hint: 'One follow-up per line.',
                  helper: 'These become trackable open actions in Notes.',
                  wordCount: _wordCount(nextActionsController.text),
                  autofocus: true,
                  expanded: true,
                  onChanged: (_) => setState(() {}),
                ),
            ],
          ),
        );
      case 4:
        return _PromptStep(
          title: 'Overall Impression',
          subtitle: 'Add a concise professional impression.',
          child: _SupportNoteField(
            controller: impressionController,
            label: 'Overall impression',
            hint: 'Brief professional impression of the interaction.',
            helper: 'Keep this factual and concise.',
            maxWords: _impressionMaxWords,
            wordCount: _wordCount(impressionController.text),
            autofocus: true,
            expanded: true,
            onChanged: (_) => setState(() {}),
          ),
        );
      case 5:
        return _referralStep();
      default:
        return _safetyStep();
    }
  }

  Widget _visitFactsStep() {
    final startedAt = TimeOfDay.fromDateTime(
      widget.activeVisit.startedAt,
    ).format(context);
    final hours = widget.minutes / 60;

    return _PromptStep(
      title: 'Visit Facts',
      subtitle: 'Check the entry details before writing note sections.',
      child: _Panel(
        title: 'Entry details',
        child: Column(
          children: [
            _InfoRow(label: 'Client', value: widget.activeVisit.client),
            _InfoRow(label: 'Type', value: widget.activeVisit.type.label),
            _InfoRow(label: 'Started', value: startedAt),
            _InfoRow(
              label: 'Length',
              value: '${widget.minutes} min (${hours.toStringAsFixed(2)}h)',
            ),
            if (widget.activeVisit.type == EntryType.homeVisit)
              _InfoRow(
                label: 'KM',
                value: widget.kilometres.toStringAsFixed(1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _referralStep() {
    return _PromptStep(
      title: 'Local Referral Tracking',
      subtitle: 'Track discussion, consent, and follow-up status.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'No referrals discussed or made',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Turn this off to select agencies and referral status.',
              style: TextStyle(color: Color(0xFF8396C7)),
            ),
            value: noReferrals,
            onChanged: (value) {
              setState(() {
                noReferrals = value;
                if (value) {
                  referrals.clear();
                  referralNotesController.clear();
                }
              });
            },
          ),
          if (!noReferrals) ...[
            const SizedBox(height: 8),
            for (final service in _blenheimAgencyOptions) ...[
              _ReferralServicePicker(
                service: service,
                selectedStatuses: referrals
                    .where((item) => item.service == service)
                    .map((item) => item.status)
                    .toSet(),
                onToggle: (status) => _toggleReferral(service, status),
              ),
              if (service != _blenheimAgencyOptions.last)
                const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            _SupportNoteField(
              controller: referralNotesController,
              label: 'Referral notes',
              hint: 'Consent, agency details, follow-up, or why declined.',
              helper: 'Add only what is needed for follow-up.',
              wordCount: _wordCount(referralNotesController.text),
              expanded: true,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _safetyStep() {
    return _PromptStep(
      title: 'Safety Concerns',
      subtitle: 'Complete the safety check before saving.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'No safety concerns noted',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Use this for sexual harm survivor and mental health safety checks.',
              style: TextStyle(color: Color(0xFF8396C7)),
            ),
            value: noSafetyConcerns,
            onChanged: (value) {
              setState(() {
                noSafetyConcerns = value;
                if (value) safetyConcernsController.clear();
              });
            },
          ),
          if (noSafetyConcerns)
            const _NoActionPanel(message: 'No safety concerns noted.')
          else
            _SupportNoteField(
              controller: safetyConcernsController,
              label: 'Safety concerns',
              hint:
                  'Immediate safety, sexual harm, self-harm, risk escalation, or mental health concerns.',
              helper: 'Keep wording factual. Include actions taken.',
              wordCount: _wordCount(safetyConcernsController.text),
              autofocus: true,
              expanded: true,
              onChanged: (_) => setState(() {}),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PromptHeader(
              title: 'Support Note',
              currentStep: stepIndex,
              stepCount: 7,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: _stepBody())),
            const SizedBox(height: 14),
            _PromptNavButtons(
              isFirst: stepIndex == 0,
              isLast: stepIndex == 6,
              onBack: _previousStep,
              onNext: _nextStep,
              saveLabel: 'Save Visit',
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptHeader extends StatelessWidget {
  const _PromptHeader({
    required this.title,
    required this.currentStep,
    required this.stepCount,
    required this.onClose,
  });

  final String title;
  final int currentStep;
  final int stepCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Step ${currentStep + 1} of $stepCount',
                style: const TextStyle(color: Color(0xFF8396C7)),
              ),
            ],
          ),
        ),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
      ],
    );
  }
}

class _PromptStep extends StatelessWidget {
  const _PromptStep({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF8396C7), height: 1.35),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PromptNavButtons extends StatelessWidget {
  const _PromptNavButtons({
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.saveLabel,
  });

  final bool isFirst;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isFirst ? null : onBack,
            icon: const Icon(Icons.arrow_back_outlined),
            label: const Text('Back'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNext,
            icon: Icon(
              isLast ? Icons.save_outlined : Icons.arrow_forward_outlined,
            ),
            label: Text(isLast ? saveLabel : 'Next'),
          ),
        ),
      ],
    );
  }
}

class _NoActionPanel extends StatelessWidget {
  const _NoActionPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27324B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF4ADE80)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportNoteField extends StatelessWidget {
  const _SupportNoteField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.wordCount,
    this.helper,
    this.maxWords,
    this.onChanged,
    this.autofocus = false,
    this.expanded = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;
  final int? maxWords;
  final int wordCount;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final limit = maxWords;
    final isOverLimit = limit != null && wordCount > limit;
    final countText = limit == null ? '$wordCount words' : '$wordCount/$limit';

    return TextField(
      controller: controller,
      autofocus: autofocus,
      minLines: expanded ? 8 : 3,
      maxLines: expanded ? 18 : 7,
      textInputAction: TextInputAction.newline,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        counterText: countText,
        counterStyle: TextStyle(
          color: isOverLimit ? Colors.redAccent : const Color(0xFF8396C7),
          fontWeight: isOverLimit ? FontWeight.w900 : FontWeight.w500,
        ),
        alignLabelWithHint: true,
        prefixIcon: const Icon(Icons.notes_outlined),
      ),
    );
  }
}

class _ReferralServicePicker extends StatelessWidget {
  const _ReferralServicePicker({
    required this.service,
    required this.selectedStatuses,
    required this.onToggle,
  });

  final String service;
  final Set<_ReferralStatus> selectedStatuses;
  final ValueChanged<_ReferralStatus> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27324B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_outlined, color: Color(0xFF4F8DF7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _agencyDisplayLabel(service),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in _ReferralStatus.values)
                FilterChip(
                  label: Text(status.label),
                  selected: selectedStatuses.contains(status),
                  onSelected: (_) => onToggle(status),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _ReferralStatusLabel on _ReferralStatus {
  String get label {
    switch (this) {
      case _ReferralStatus.discussed:
        return 'Discussed';
      case _ReferralStatus.referred:
        return 'Referred';
      case _ReferralStatus.engaged:
        return 'Engaged';
      case _ReferralStatus.declined:
        return 'Declined';
      case _ReferralStatus.pending:
        return 'Pending';
    }
  }
}

class _SavedVisitView extends StatefulWidget {
  const _SavedVisitView({
    required this.entry,
    required this.onEntryUpdated,
    required this.onDelete,
    required this.onNewVisit,
    this.onCalendar,
  });

  final WorkEntry entry;
  final ValueChanged<WorkEntry> onEntryUpdated;
  final VoidCallback onDelete;
  final VoidCallback onNewVisit;
  final VoidCallback? onCalendar;

  @override
  State<_SavedVisitView> createState() => _SavedVisitViewState();
}

class _SavedVisitViewState extends State<_SavedVisitView> {
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
  void didUpdateWidget(covariant _SavedVisitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.googleCalendarEntered !=
            widget.entry.googleCalendarEntered) {
      calendarEntered = widget.entry.googleCalendarEntered;
    }
  }

  Future<void> _exportToGoogleCalendar(BuildContext context) async {
    final appState = context.read<AppState>();

    setState(() {
      calendarBusy = true;
      calendarMessage = 'Opening calendar draft...';
      calendarError = false;
    });

    try {
      await appState.createPrivateGoogleCalendarEvent(widget.entry);

      final updatedEntry = widget.entry.copyWith(googleCalendarEntered: true);
      appState.updateEntry(updatedEntry);
      widget.onEntryUpdated(updatedEntry);

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
    final payeMode = context.watch<AppState>().isPayeMode;
    final entry = widget.entry;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HeroPanel(
          title: 'Visit saved',
          subtitle:
              '${entry.client} - ${entry.type.label} - ${entry.minutes} min',
          icon: Icons.check_circle_outline,
          green: true,
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Saved summary',
          child: Column(
            children: [
              _InfoRow(label: 'Client', value: entry.client),
              _InfoRow(label: 'Type', value: entry.type.label),
              _InfoRow(label: 'Date', value: formatDate(entry.date)),
              _InfoRow(label: 'Minutes', value: '${entry.minutes} min'),
              _InfoRow(label: 'Hours', value: entry.hours.toStringAsFixed(2)),
              if (!payeMode && entry.type == EntryType.homeVisit)
                _InfoRow(
                  label: 'KM',
                  value: entry.kilometres.toStringAsFixed(1),
                ),
              if (!payeMode)
                _InfoRow(
                  label: 'Earned',
                  value: money(entry.earnings(settings)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Calendar status',
          child: Column(
            children: [
              const _CalendarStatusRow(
                icon: Icons.event_note_outlined,
                label: 'App Calendar',
                value: 'Saved',
                color: Color(0xFF31E981),
              ),
              _CalendarStatusRow(
                icon: calendarEntered
                    ? Icons.event_available_outlined
                    : Icons.event_busy_outlined,
                label: 'Google Calendar',
                value: calendarEntered ? 'Logged' : 'Not logged',
                color: calendarEntered
                    ? const Color(0xFF31E981)
                    : const Color(0xFFFFC857),
              ),
            ],
          ),
        ),
        if (entry.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            title: 'Notes saved',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final note in entry.notes) Chip(label: Text(note)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: calendarEntered || calendarBusy
              ? null
              : () => _exportToGoogleCalendar(context),
          icon: Icon(
            calendarEntered
                ? Icons.event_available_outlined
                : Icons.calendar_month_outlined,
          ),
          label: Text(
            calendarEntered
                ? 'Calendar entered'
                : calendarBusy
                ? 'Opening draft'
                : 'Open Calendar draft',
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
              calendarMessage!,
              style: TextStyle(
                color: calendarError
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF31E981),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
        if (widget.onCalendar != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onCalendar,
            icon: const Icon(Icons.calendar_view_week_outlined),
            label: const Text('View in App Calendar'),
          ),
        ],
        const SizedBox(height: 8),
        LocalSupportNoteButton(entry: entry),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete Entry'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF6B6B),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: widget.onNewVisit,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Start New Visit'),
        ),
      ],
    );
  }
}

class _CalendarStatusRow extends StatelessWidget {
  const _CalendarStatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _StartVisitView extends StatelessWidget {
  const _StartVisitView({
    required this.clients,
    required this.selectedClient,
    required this.selectedType,
    required this.selectedNotes,
    required this.visitDate,
    required this.startOdometerController,
    required this.showKilometres,
    required this.showAttendance,
    required this.onClientSelected,
    required this.onTypeSelected,
    required this.onNoteToggle,
    required this.onUseToday,
    required this.onUsePreviousDay,
    required this.onPickDate,
    required this.onStart,
  });

  final List<String> clients;
  final String? selectedClient;
  final EntryType selectedType;
  final Set<String> selectedNotes;
  final DateTime visitDate;
  final TextEditingController startOdometerController;
  final bool showKilometres;
  final bool showAttendance;
  final ValueChanged<String> onClientSelected;
  final ValueChanged<EntryType> onTypeSelected;
  final void Function(String note, bool selected) onNoteToggle;
  final VoidCallback onUseToday;
  final VoidCallback onUsePreviousDay;
  final VoidCallback onPickDate;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final noteOptions = appState.settings.noteOptions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HeroPanel(
          title: 'Start visit',
          subtitle:
              'Tap client, tap support type, choose the visit date, then press Start Now.',
          icon: Icons.play_arrow_rounded,
        ),
        const SizedBox(height: 12),
        GoogleAccountConnectionCard(
          scope: appState.isPayeMode
              ? GoogleExportAccountScope.paye
              : GoogleExportAccountScope.work,
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Visit Date',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoRow(label: 'Selected date', value: formatDate(visitDate)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onUseToday,
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Today'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onUsePreviousDay,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous Day'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: '1. Client',
          child: clients.isEmpty
              ? const Text('Add clients in Settings first.')
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final client in clients)
                      _ChoiceCard(
                        icon: Icons.person_rounded,
                        label: client,
                        selected: selectedClient == client,
                        onTap: () => onClientSelected(client),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: '2. Support Type',
          child: Column(
            children: [
              for (final type in EntryType.values) ...[
                _TypeTile(
                  type: type,
                  selected: selectedType == type,
                  onTap: () => onTypeSelected(type),
                ),
                if (type != EntryType.values.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        if (showKilometres && selectedType == EntryType.homeVisit) ...[
          const SizedBox(height: 12),
          _Panel(
            title: '3. Starting Odometer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: startOdometerController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [_OdometerInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Starting odometer',
                    helperText: 'Optional. Leave blank to start walking.',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You can start the timer now and add the odometer when you get to the car.',
                  style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.directions_walk_outlined),
            label: const Text('Start Timer Without Odometer'),
          ),
        ],
        if (selectedType == EntryType.homeVisit) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Timer'),
          ),
        ] else ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Now'),
          ),
        ],
        const SizedBox(height: 12),
        _VisitContextTabs(
          noteOptions: noteOptions,
          selectedNotes: selectedNotes,
          showAttendance: showAttendance,
          showAgencies: selectedType == EntryType.professionalContact,
          onChanged: onNoteToggle,
        ),
      ],
    );
  }
}

class _ActiveVisitView extends StatelessWidget {
  const _ActiveVisitView({
    required this.activeVisit,
    required this.selectedNotes,
    required this.finishOdometerController,
    required this.startOdometerController,
    required this.noteController,
    required this.elapsedText,
    required this.startedAtText,
    required this.showKilometres,
    required this.onNoteToggle,
    required this.onSaveStartOdometer,
    required this.onSaveDraft,
    required this.onFinish,
    required this.onCancel,
  });

  final ActiveVisit activeVisit;
  final Set<String> selectedNotes;
  final TextEditingController finishOdometerController;
  final TextEditingController startOdometerController;
  final TextEditingController noteController;
  final String elapsedText;
  final String startedAtText;
  final bool showKilometres;
  final void Function(String note, bool selected) onNoteToggle;
  final VoidCallback onSaveStartOdometer;
  final VoidCallback onSaveDraft;
  final VoidCallback onFinish;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final noteOptions = settings.noteOptions;
    final minutes = _previewMinutes(activeVisit.startedAt);
    final gross = (minutes / 60) * settings.hourlyRate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HeroPanel(
          title: 'Active visit running',
          subtitle: _cleanHeaderText(
            '${activeVisit.client}\n${activeVisit.type.label}\nStarted $startedAtText',
          ),
          icon: Icons.timer_outlined,
          green: true,
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Current Progress',
          child: Column(
            children: [
              _InfoRow(label: 'Client', value: activeVisit.client),
              _InfoRow(label: 'Type', value: activeVisit.type.label),
              _InfoRow(label: 'Started', value: startedAtText),
              _InfoRow(label: 'Elapsed so far', value: elapsedText),
              _InfoRow(label: 'Estimated earned', value: money(gross)),
              if (showKilometres && activeVisit.type == EntryType.homeVisit)
                _InfoRow(
                  label: 'Starting odo',
                  value: activeVisit.odometerStart?.toStringAsFixed(1) ?? '-',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (showKilometres &&
            activeVisit.type == EntryType.homeVisit &&
            activeVisit.odometerStart == null)
          _Panel(
            title: 'Starting Odometer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: startOdometerController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [_OdometerInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Starting odometer',
                    helperText:
                        'Optional. Add it when you get to the car if needed.',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onSaveStartOdometer,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Starting Odometer'),
                ),
              ],
            ),
          ),
        if (showKilometres &&
            activeVisit.type == EntryType.homeVisit &&
            activeVisit.odometerStart == null)
          const SizedBox(height: 12),
        if (showKilometres && activeVisit.type == EntryType.homeVisit)
          _Panel(
            title: 'Finish Odometer',
            child: TextField(
              controller: finishOdometerController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [_OdometerInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Finishing odometer',
                helperText: 'Fill this in when the client visit is done',
              ),
            ),
          ),
        if (showKilometres && activeVisit.type == EntryType.homeVisit)
          const SizedBox(height: 12),
        _VisitContextTabs(
          noteOptions: noteOptions,
          selectedNotes: selectedNotes,
          showAttendance: context.watch<AppState>().isPayeMode,
          showAgencies: activeVisit.type == EntryType.professionalContact,
          onChanged: onNoteToggle,
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Optional extra note',
                  hintText: 'Brief detail if the topics do not cover it',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onSaveDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Draft Notes'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onFinish,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Finish Now & Save Entry'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Cancel Active Visit'),
        ),
      ],
    );
  }

  int _previewMinutes(DateTime startedAt) {
    final seconds = DateTime.now().difference(startedAt).inSeconds;
    if (seconds <= 0) return 0;
    return (seconds / 60).ceil().clamp(1, 1440).toInt();
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.green = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final color = green ? const Color(0xFF31E981) : const Color(0xFF4F8DF7);
    final bg = green ? const Color(0xFF0B301D) : const Color(0xFF13294D);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: green ? const Color(0xFF128A45) : const Color(0xFF34405F),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFFD8E2FF), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF13294D) : const Color(0xFF20283B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 150,
          height: 104,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4F8DF7)
                  : const Color(0xFF34405F),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF4F8DF7) : Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final EntryType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF13294D) : const Color(0xFF20283B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4F8DF7)
                  : const Color(0xFF34405F),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                type.icon,
                color: selected ? const Color(0xFF4F8DF7) : Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: Color(0xFF31E981)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteChips extends StatelessWidget {
  const _NoteChips({
    required this.notes,
    required this.selectedNotes,
    required this.onChanged,
  });

  final List<String> notes;
  final Set<String> selectedNotes;
  final void Function(String note, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Text(
        'Add reusable topics in Settings.',
        style: TextStyle(color: Color(0xFF8396C7)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final note in notes)
          FilterChip(
            label: Text(note),
            selected: selectedNotes.contains(note),
            showCheckmark: false,
            onSelected: (selected) => onChanged(note, selected),
          ),
      ],
    );
  }
}

class _VisitContextTabs extends StatelessWidget {
  const _VisitContextTabs({
    required this.noteOptions,
    required this.selectedNotes,
    required this.showAgencies,
    required this.showAttendance,
    required this.onChanged,
    this.footer,
  });

  final List<String> noteOptions;
  final Set<String> selectedNotes;
  final bool showAgencies;
  final bool showAttendance;
  final void Function(String note, bool selected) onChanged;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tabCount = showAgencies ? 2 : 1;

    return _Panel(
      title: 'Visit Context',
      child: DefaultTabController(
        length: tabCount,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showAttendance) ...[
              _AttendanceChips(
                selectedNotes: selectedNotes,
                onChanged: onChanged,
              ),
              const SizedBox(height: 12),
            ],
            _SupportTagChips(
              selectedNotes: selectedNotes,
              onChanged: onChanged,
            ),
            const SizedBox(height: 12),
            TabBar(
              tabs: [
                const Tab(
                  icon: Icon(Icons.topic_outlined),
                  text: 'Topics Covered',
                ),
                if (showAgencies)
                  const Tab(
                    icon: Icon(Icons.business_outlined),
                    text: 'Agencies',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: showAgencies ? 250 : 190,
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    child: _NoteChips(
                      notes: noteOptions,
                      selectedNotes: selectedNotes,
                      onChanged: onChanged,
                    ),
                  ),
                  if (showAgencies)
                    SingleChildScrollView(
                      child: _AgencyChips(
                        selectedNotes: selectedNotes,
                        onChanged: onChanged,
                      ),
                    ),
                ],
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}

class _AttendanceChips extends StatelessWidget {
  const _AttendanceChips({
    required this.selectedNotes,
    required this.onChanged,
  });

  final Set<String> selectedNotes;
  final void Function(String note, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Attendance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in _attendanceOptions)
              FilterChip(
                avatar: const Icon(Icons.group_outlined, size: 18),
                label: Text(role),
                selected: selectedNotes.contains('$_attendancePrefix$role'),
                showCheckmark: false,
                onSelected: (selected) {
                  onChanged('$_attendancePrefix$role', selected);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _SupportTagChips extends StatelessWidget {
  const _SupportTagChips({
    required this.selectedNotes,
    required this.onChanged,
  });

  final Set<String> selectedNotes;
  final void Function(String note, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Support tags',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in _supportTagOptions)
              FilterChip(
                avatar: const Icon(Icons.sell_outlined, size: 18),
                label: Text(tag),
                selected: selectedNotes.contains('$_supportTagPrefix$tag'),
                showCheckmark: false,
                onSelected: (selected) {
                  onChanged('$_supportTagPrefix$tag', selected);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _AgencyChips extends StatelessWidget {
  const _AgencyChips({required this.selectedNotes, required this.onChanged});

  final Set<String> selectedNotes;
  final void Function(String note, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final agency in _blenheimAgencyOptions)
          FilterChip(
            avatar: const Icon(Icons.business_outlined, size: 18),
            label: Text(_agencyDisplayLabel(agency)),
            selected: selectedNotes.contains(agency),
            showCheckmark: false,
            onSelected: (selected) => onChanged(agency, selected),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27324B)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF8396C7)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OdometerInputFormatter extends TextInputFormatter {
  const _OdometerInputFormatter();

  static final RegExp _validPattern = RegExp(r'^\d*\.?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) return newValue;
    if (!_validPattern.hasMatch(text)) return oldValue;

    final dotCount = '.'.allMatches(text).length;
    if (dotCount > 1) return oldValue;

    return newValue;
  }
}
