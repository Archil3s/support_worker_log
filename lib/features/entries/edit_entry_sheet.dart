// ignore_for_file: prefer_collection_literals
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/work_entry.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/billing_rules.dart';
import '../../shared/widgets/review_row.dart';
import '../../shared/widgets/section_card.dart';

class EditEntrySheet extends StatefulWidget {
  const EditEntrySheet({
    super.key,
    required this.entry,
    required this.clients,
    required this.onSave,
  });

  final WorkEntry entry;
  final List<String> clients;
  final ValueChanged<WorkEntry> onSave;

  @override
  State<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<EditEntrySheet> {
  static const noteOptions = [
    'Wellbeing',
    'Safety Plan',
    'Distress Support',
    'Daily Living',
    'Appointment',
    'Transport',
    'Advocacy',
    'Crisis',
    'Trauma Support',
    'Boundaries',
    'Family/Tamariki',
    'Community',
    'Prof. Contact',
    'No Contact',
    'Cancelled',
    'No Show',
    'Rescheduled',
    'Client Rescheduled',
    'Late Cancel',
    'Cut Short',
    'Follow-up Needed',
  ];

  late String selectedClient;
  late EntryType selectedType;
  late DateTime selectedDate;
  late TimeOfDay startTime;
  late int minutes;
  late bool importantText;

  late final TextEditingController odometerStartController;
  late final TextEditingController odometerEndController;
  late final TextEditingController customNoteController;

  final selectedNotes = <String>{};

  @override
  void initState() {
    super.initState();

    selectedClient = widget.clients.contains(widget.entry.client)
        ? widget.entry.client
        : widget.clients.isEmpty
        ? widget.entry.client
        : widget.clients.first;

    selectedType = widget.entry.type;
    selectedDate = widget.entry.date;
    startTime = widget.entry.startTime;
    minutes = widget.entry.minutes <= 0 ? 5 : widget.entry.minutes;
    importantText = widget.entry.importantText;

    final knownNotes = noteOptions.toSet();
    final customNotes = <String>[];

    for (final note in widget.entry.notes) {
      if (knownNotes.contains(note)) {
        selectedNotes.add(note);
      } else if (note.trim().isNotEmpty) {
        customNotes.add(note.trim());
      }
    }

    odometerStartController = TextEditingController(
      text: _numberText(widget.entry.odometerStart),
    );
    odometerEndController = TextEditingController(
      text: _numberText(widget.entry.odometerEnd),
    );
    customNoteController = TextEditingController(text: customNotes.join('\n'));
  }

  @override
  void dispose() {
    odometerStartController.dispose();
    odometerEndController.dispose();
    customNoteController.dispose();
    super.dispose();
  }

  String _numberText(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  double? _parseOdometer(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  int get savedMinutes => minutes.clamp(1, 1440);

  BillingTimeBreakdown get previewBreakdown {
    return calculateBillableTime(
      type: selectedType,
      baseMinutes: savedMinutes,
      notes: buildNotes(),
    );
  }

  double get previewHours => previewBreakdown.billableHours;

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (!mounted || picked == null) return;
    setState(() => selectedDate = picked);
  }

  Future<void> pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );

    if (!mounted || picked == null) return;
    setState(() => startTime = picked);
  }

  void setDuration(int value) {
    setState(() => minutes = value.clamp(1, 1440));
  }

  void adjustDuration(int delta) {
    setDuration(minutes + delta);
  }

  List<String> buildNotes() {
    final customNotes = customNoteController.text
        .split('\n')
        .map((note) => note.trim())
        .where((note) => note.isNotEmpty);

    final notes = [...selectedNotes, ...customNotes].toSet().toList()..sort();

    return notes;
  }

  void save() {
    final odometerStart = selectedType == EntryType.homeVisit
        ? _parseOdometer(odometerStartController)
        : null;
    final odometerEnd = selectedType == EntryType.homeVisit
        ? _parseOdometer(odometerEndController)
        : null;

    if (selectedType == EntryType.homeVisit &&
        odometerStart != null &&
        odometerEnd != null &&
        odometerEnd < odometerStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Finish odometer must be higher than start.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    final updatedEntry = WorkEntry(
      id: widget.entry.id,
      client: selectedClient,
      type: selectedType,
      date: selectedDate,
      startTime: startTime,
      minutes: savedMinutes,
      notes: buildNotes(),
      supportNoteBreakdown: widget.entry.supportNoteBreakdown,
      nextActions: widget.entry.nextActions,
      googleCalendarEntered: widget.entry.googleCalendarEntered,
      importantText: selectedType == EntryType.textNote && importantText,
      odometerStart: odometerStart,
      odometerEnd: odometerEnd,
    );

    widget.onSave(updatedEntry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final safeClients = widget.clients.isEmpty
        ? <String>[selectedClient]
        : widget.clients;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.94,
        minChildSize: 0.55,
        maxChildSize: 0.98,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SheetHeader(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: 12),
              _QuickFixPanel(
                onToday: () {
                  setState(() => selectedDate = DateTime.now());
                },
                onNow: () {
                  setState(() => startTime = TimeOfDay.now());
                },
                onClearOdo: () {
                  setState(() {
                    odometerStartController.clear();
                    odometerEndController.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Client',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final client in safeClients)
                      ChoiceChip(
                        label: Text(client),
                        selected: selectedClient == client,
                        onSelected: (_) {
                          setState(() => selectedClient = client);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Entry Type',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in EntryType.values)
                      ChoiceChip(
                        avatar: Icon(type.icon, size: 18),
                        label: Text(type.label),
                        selected: selectedType == type,
                        onSelected: (_) {
                          setState(() => selectedType = type);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Date & Start Time',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: const Icon(Icons.today_outlined),
                      label: Text(formatDate(selectedDate)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: pickStartTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(formatTime(startTime)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Duration',
                child: _DurationEditor(
                  minutes: savedMinutes,
                  onSet: setDuration,
                  onAdjust: adjustDuration,
                ),
              ),
              if (selectedType == EntryType.homeVisit) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Odometer',
                  child: Column(
                    children: [
                      TextField(
                        controller: odometerStartController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: const [_DecimalInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Start odometer',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: odometerEndController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: const [_DecimalInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Finish odometer',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (selectedType == EntryType.textNote) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Text Importance',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: importantText,
                    onChanged: (value) {
                      setState(() => importantText = value);
                    },
                    title: const Text(
                      'Important text',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'Important texts are marked in invoice text summaries.',
                      style: TextStyle(color: Color(0xFF8396C7)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SectionCard(
                title: 'Notes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final note in noteOptions)
                          FilterChip(
                            label: Text(note),
                            selected: selectedNotes.contains(note),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  selectedNotes.add(note);
                                } else {
                                  selectedNotes.remove(note);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customNoteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Extra note',
                        hintText: 'One note per line',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Review Changes',
                child: Column(
                  children: [
                    ReviewRow(label: 'Client', value: selectedClient),
                    ReviewRow(label: 'Type', value: selectedType.label),
                    ReviewRow(label: 'Date', value: formatDate(selectedDate)),
                    ReviewRow(label: 'Start', value: formatTime(startTime)),
                    ReviewRow(label: 'Duration', value: '$savedMinutes min'),
                    ReviewRow(
                      label: 'Hours',
                      value: previewHours.toStringAsFixed(2),
                    ),
                    if (selectedType == EntryType.homeVisit)
                      ReviewRow(
                        label: 'Odometer',
                        value:
                            '${odometerStartController.text.trim().isEmpty ? '-' : odometerStartController.text.trim()} -> ${odometerEndController.text.trim().isEmpty ? '-' : odometerEndController.text.trim()}',
                      ),
                    if (selectedType == EntryType.textNote)
                      ReviewRow(
                        label: 'Importance',
                        value: importantText ? 'Important' : 'Normal',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Fix Entry',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
      ],
    );
  }
}

class _QuickFixPanel extends StatelessWidget {
  const _QuickFixPanel({
    required this.onToday,
    required this.onNow,
    required this.onClearOdo,
  });

  final VoidCallback onToday;
  final VoidCallback onNow;
  final VoidCallback onClearOdo;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick Fixes',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: onToday,
            icon: const Icon(Icons.today_outlined),
            label: const Text('Set Date Today'),
          ),
          FilledButton.tonalIcon(
            onPressed: onNow,
            icon: const Icon(Icons.schedule_outlined),
            label: const Text('Set Time Now'),
          ),
          OutlinedButton.icon(
            onPressed: onClearOdo,
            icon: const Icon(Icons.clear),
            label: const Text('Clear Odo'),
          ),
        ],
      ),
    );
  }
}

class _DurationEditor extends StatelessWidget {
  const _DurationEditor({
    required this.minutes,
    required this.onSet,
    required this.onAdjust,
  });

  final int minutes;
  final ValueChanged<int> onSet;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    const presets = [15, 30, 45, 60, 90, 120];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$minutes minutes (${(minutes / 60).toStringAsFixed(2)}h)',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in presets)
              ChoiceChip(
                label: Text('$preset min'),
                selected: minutes == preset,
                onSelected: (_) => onSet(preset),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onAdjust(-15),
                child: const Text('-15'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => onAdjust(-5),
                child: const Text('-5'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => onAdjust(5),
                child: const Text('+5'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => onAdjust(15),
                child: const Text('+15'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DecimalInputFormatter extends TextInputFormatter {
  const _DecimalInputFormatter();

  static final RegExp _validPattern = RegExp(r'^\d*\.?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) return newValue;
    if (!_validPattern.hasMatch(text)) return oldValue;
    if ('.'.allMatches(text).length > 1) return oldValue;

    return newValue;
  }
}
