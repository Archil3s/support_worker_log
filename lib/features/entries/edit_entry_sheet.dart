import 'package:flutter/material.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/work_entry.dart';
import '../../core/utils/formatters.dart';
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
  late int textCount;

  late final TextEditingController odometerStartController;
  late final TextEditingController odometerEndController;

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
    textCount = widget.entry.minutes <= 0 ? 1 : widget.entry.minutes;

    selectedNotes.addAll(widget.entry.notes);

    odometerStartController = TextEditingController(
      text: _numberText(widget.entry.odometerStart),
    );
    odometerEndController = TextEditingController(
      text: _numberText(widget.entry.odometerEnd),
    );
  }

  @override
  void dispose() {
    odometerStartController.dispose();
    odometerEndController.dispose();
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

  int get savedMinutes {
    return selectedType == EntryType.textNote ? textCount : minutes;
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );

    if (picked != null) {
      setState(() => startTime = picked);
    }
  }

  void save() {
    final updatedEntry = widget.entry.copyWith(
      client: selectedClient,
      type: selectedType,
      date: selectedDate,
      startTime: startTime,
      minutes: savedMinutes,
      notes: selectedNotes.toList()..sort(),
      odometerStart: selectedType == EntryType.homeVisit
          ? _parseOdometer(odometerStartController)
          : null,
      odometerEnd: selectedType == EntryType.homeVisit
          ? _parseOdometer(odometerEndController)
          : null,
    );

    widget.onSave(updatedEntry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit Entry',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Client',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedClient,
                    isExpanded: true,
                    items: [
                      for (final client in widget.clients)
                        DropdownMenuItem(value: client, child: Text(client)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedClient = value);
                    },
                  ),
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
                          setState(() {
                            selectedType = type;
                            if (selectedType == EntryType.textNote) {
                              textCount = savedMinutes <= 0 ? 1 : savedMinutes;
                            } else {
                              minutes = savedMinutes <= 0 ? 5 : savedMinutes;
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Date & Start Time',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickDate,
                            icon: const Icon(Icons.today_outlined),
                            label: Text(formatDate(selectedDate)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickStartTime,
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(formatTime(startTime)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            selectedDate = DateTime.now();
                            startTime = TimeOfDay.now();
                          });
                        },
                        icon: const Icon(Icons.bolt_outlined),
                        label: const Text('Now'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: selectedType == EntryType.textNote
                    ? 'Text Counter'
                    : 'Minutes',
                child: _CounterRow(
                  label: selectedType == EntryType.textNote
                      ? '$textCount text${textCount == 1 ? '' : 's'}'
                      : '$minutes minutes',
                  helper: selectedType == EntryType.textNote
                      ? 'Each text = 1 minute'
                      : 'Total saved entry duration',
                  value: selectedType == EntryType.textNote
                      ? textCount
                      : minutes,
                  minValue: selectedType == EntryType.textNote ? 1 : 5,
                  step: selectedType == EntryType.textNote ? 1 : 5,
                  onChanged: (value) {
                    setState(() {
                      if (selectedType == EntryType.textNote) {
                        textCount = value;
                      } else {
                        minutes = value;
                      }
                    });
                  },
                ),
              ),
              if (selectedType == EntryType.homeVisit) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Odometer',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: odometerStartController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Start',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: odometerEndController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Finish',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SectionCard(
                title: 'Notes Chips',
                child: Wrap(
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
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Review',
                child: Column(
                  children: [
                    ReviewRow(label: 'Client', value: selectedClient),
                    ReviewRow(label: 'Type', value: selectedType.label),
                    ReviewRow(label: 'Date', value: formatDate(selectedDate)),
                    ReviewRow(label: 'Start', value: formatTime(startTime)),
                    ReviewRow(label: 'Minutes', value: '$savedMinutes min'),
                    if (selectedType == EntryType.homeVisit)
                      ReviewRow(
                        label: 'Odometer',
                        value:
                            '${odometerStartController.text.trim().isEmpty ? '-' : odometerStartController.text.trim()} → ${odometerEndController.text.trim().isEmpty ? '-' : odometerEndController.text.trim()}',
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.helper,
    required this.value,
    required this.minValue,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final String helper;
  final int value;
  final int minValue;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            subtitle: Text(helper),
          ),
        ),
        IconButton.filledTonal(
          onPressed: value <= minValue ? null : () => onChanged(value - step),
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$value'),
        ),
        IconButton.filledTonal(
          onPressed: () => onChanged(value + step),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
