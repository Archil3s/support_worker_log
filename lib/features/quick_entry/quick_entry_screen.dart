import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/work_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/review_row.dart';
import '../../shared/widgets/section_card.dart';

class QuickEntryScreen extends StatefulWidget {
  const QuickEntryScreen({super.key});

  @override
  State<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _QuickEntryScreenState extends State<QuickEntryScreen> {
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

  static const extraMinutesByChip = {
    'Cancelled': 5,
    'No Show': 5,
    'Late Cancel': 5,
    'Follow-up Needed': 5,
  };

  String? selectedClient;
  EntryType selectedType = EntryType.homeVisit;
  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = TimeOfDay.now();
  int baseMinutes = 60;
  int textCount = 1;
  final selectedNotes = <String>{};

  final odometerStartController = TextEditingController();
  final odometerEndController = TextEditingController();

  @override
  void dispose() {
    odometerStartController.dispose();
    odometerEndController.dispose();
    super.dispose();
  }

  int get extraMinutes {
    var total = 0;
    for (final note in selectedNotes) {
      total += extraMinutesByChip[note] ?? 0;
    }
    return total;
  }

  int get totalMinutes {
    final base = selectedType == EntryType.textNote ? textCount : baseMinutes;
    return base + extraMinutes;
  }

  double? parseOdometer(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
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

  void saveEntry() {
    final appState = context.read<AppState>();
    final client = selectedClient;

    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add or select a client first')),
      );
      return;
    }

    final entry = WorkEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      client: client,
      type: selectedType,
      date: selectedDate,
      startTime: startTime,
      minutes: totalMinutes,
      notes: selectedNotes.toList()..sort(),
      odometerStart: parseOdometer(odometerStartController),
      odometerEnd: parseOdometer(odometerEndController),
    );

    appState.addEntry(entry);

    setState(() {
      selectedDate = DateTime.now();
      startTime = TimeOfDay.now();
      baseMinutes = 60;
      textCount = 1;
      selectedNotes.clear();
      odometerStartController.clear();
      odometerEndController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry saved')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final clients = appState.clients;

    if (clients.isNotEmpty && !clients.contains(selectedClient)) {
      selectedClient = clients.first;
    }

    final previewEarnings = (totalMinutes / 60) * appState.settings.hourlyRate;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Client',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: clients.isEmpty ? null : selectedClient,
              isExpanded: true,
              items: [
                for (final client in clients)
                  DropdownMenuItem(value: client, child: Text(client)),
              ],
              onChanged: (value) => setState(() => selectedClient = value),
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
                    });
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Date & Time',
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
              : 'Duration',
          child: _CounterRow(
            label: selectedType == EntryType.textNote
                ? '$textCount text${textCount == 1 ? '' : 's'}'
                : '$baseMinutes minutes',
            helper: selectedType == EntryType.textNote
                ? 'Each text = 1 minute'
                : 'Base logged time before note-chip additions',
            value: selectedType == EntryType.textNote ? textCount : baseMinutes,
            minValue: selectedType == EntryType.textNote ? 1 : 5,
            step: selectedType == EntryType.textNote ? 1 : 5,
            onChanged: (value) {
              setState(() {
                if (selectedType == EntryType.textNote) {
                  textCount = value;
                } else {
                  baseMinutes = value;
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
              ReviewRow(label: 'Total minutes', value: '$totalMinutes min'),
              ReviewRow(label: 'Extra minutes', value: '+$extraMinutes min'),
              ReviewRow(
                label: 'Earnings preview',
                value: money(previewEarnings),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saveEntry,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Entry'),
                ),
              ),
            ],
          ),
        ),
      ],
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
