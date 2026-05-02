import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/entry_type.dart';
import '../../core/models/quick_entry_draft.dart';
import '../../core/models/work_entry.dart';
import '../../core/services/draft_service.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/review_row.dart';
import '../../shared/widgets/section_card.dart';
import 'widgets/wizard_nav_buttons.dart';
import 'widgets/wizard_progress_dots.dart';

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

  final DraftService _draftService = DraftService();
  final PageController _pageController = PageController();

  String? selectedClient;
  EntryType selectedType = EntryType.homeVisit;
  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = TimeOfDay.now();
  int baseMinutes = 60;
  int textCount = 1;
  int currentStepIndex = 0;
  bool draftLoaded = false;
  bool showSuccess = false;

  final selectedNotes = <String>{};
  final odometerStartController = TextEditingController();
  final odometerEndController = TextEditingController();

  @override
  void initState() {
    super.initState();

    odometerStartController.addListener(_saveDraftIfLoaded);
    odometerEndController.addListener(_saveDraftIfLoaded);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadDraft());
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    odometerStartController.dispose();
    odometerEndController.dispose();
    super.dispose();
  }

  List<_WizardStep> get steps {
    return [
      const _WizardStep(
        title: 'Client',
        description: 'Choose who this entry is for.',
      ),
      const _WizardStep(
        title: 'Entry Type',
        description: 'Select the kind of work completed.',
      ),
      const _WizardStep(
        title: 'Date & Time',
        description: 'Set the work date and start time.',
      ),
      _WizardStep(
        title: selectedType == EntryType.textNote ? 'Text Counter' : 'Duration',
        description: selectedType == EntryType.textNote
            ? 'Each text counts as one minute.'
            : 'Set the base logged time.',
      ),
      if (selectedType == EntryType.homeVisit)
        const _WizardStep(
          title: 'Odometer',
          description: 'Record start and finish odometer values.',
        ),
      const _WizardStep(
        title: 'Notes',
        description: 'Tap chips to describe the support provided.',
      ),
      const _WizardStep(
        title: 'Review',
        description: 'Check the entry before saving.',
      ),
    ];
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

  Future<void> _loadDraft() async {
    final clients = context.read<AppState>().clients;
    final draft = await _draftService.loadQuickEntryDraft();

    if (!mounted) return;

    setState(() {
      if (draft == null) {
        selectedClient = clients.isEmpty ? null : clients.first;
        draftLoaded = true;
        return;
      }

      selectedClient = clients.contains(draft.selectedClient)
          ? draft.selectedClient
          : clients.isEmpty
          ? null
          : clients.first;

      selectedType = draft.selectedType;
      selectedDate = draft.selectedDate;
      startTime = draft.startTime;
      baseMinutes = draft.baseMinutes;
      textCount = draft.textCount;

      selectedNotes
        ..clear()
        ..addAll(draft.selectedNotes);

      odometerStartController.text = draft.odometerStart;
      odometerEndController.text = draft.odometerEnd;

      draftLoaded = true;
    });
  }

  QuickEntryDraft _currentDraft() {
    return QuickEntryDraft(
      selectedClient: selectedClient,
      selectedType: selectedType,
      selectedDate: selectedDate,
      startTime: startTime,
      baseMinutes: baseMinutes,
      textCount: textCount,
      selectedNotes: selectedNotes.toList()..sort(),
      odometerStart: odometerStartController.text,
      odometerEnd: odometerEndController.text,
    );
  }

  void _saveDraftIfLoaded() {
    if (!draftLoaded) return;
    unawaited(_draftService.saveQuickEntryDraft(_currentDraft()));
  }

  void _updateDraftState(VoidCallback change) {
    setState(change);

    if (currentStepIndex >= steps.length) {
      currentStepIndex = steps.length - 1;
    }

    _saveDraftIfLoaded();
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
      _updateDraftState(() => selectedDate = picked);
    }
  }

  Future<void> pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );

    if (picked != null) {
      _updateDraftState(() => startTime = picked);
    }
  }

  void goToStep(int index) {
    final boundedIndex = index.clamp(0, steps.length - 1);

    setState(() => currentStepIndex = boundedIndex);

    _pageController.animateToPage(
      boundedIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void goNext() {
    if (currentStepIndex < steps.length - 1) {
      goToStep(currentStepIndex + 1);
    }
  }

  void goBack() {
    if (currentStepIndex > 0) {
      goToStep(currentStepIndex - 1);
    }
  }

  Future<void> saveEntry() async {
    final appState = context.read<AppState>();
    final client = selectedClient;

    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add or select a client first')),
      );
      goToStep(0);
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
      odometerStart: selectedType == EntryType.homeVisit
          ? parseOdometer(odometerStartController)
          : null,
      odometerEnd: selectedType == EntryType.homeVisit
          ? parseOdometer(odometerEndController)
          : null,
    );

    appState.addEntry(entry);
    await _draftService.clearQuickEntryDraft();

    if (!mounted) return;

    setState(() {
      showSuccess = true;
      selectedDate = DateTime.now();
      startTime = TimeOfDay.now();
      baseMinutes = 60;
      textCount = 1;
      selectedNotes.clear();
      odometerStartController.clear();
      odometerEndController.clear();
    });
  }

  void startAnotherEntry() {
    setState(() {
      showSuccess = false;
      currentStepIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients) return;
      _pageController.jumpToPage(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final clients = appState.clients;
    final activeClient = clients.contains(selectedClient)
        ? selectedClient
        : clients.isEmpty
        ? null
        : clients.first;

    if (activeClient != selectedClient && draftLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateDraftState(() => selectedClient = activeClient);
      });
    }

    if (!draftLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (showSuccess) {
      return _SuccessView(onNewEntry: startAnotherEntry);
    }

    final previewEarnings = (totalMinutes / 60) * appState.settings.hourlyRate;
    final currentStep = steps[currentStepIndex];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SectionCard(
            title: currentStep.title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(currentStep.description),
                const SizedBox(height: 12),
                WizardProgressDots(
                  currentIndex: currentStepIndex,
                  total: steps.length,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniPreview(
                        label: 'Minutes',
                        value: '$totalMinutes',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniPreview(
                        label: 'Preview',
                        value: money(previewEarnings),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: steps.length,
            onPageChanged: (index) {
              setState(() => currentStepIndex = index);
            },
            itemBuilder: (context, index) {
              return _StepScaffold(
                child: _buildStep(
                  index: index,
                  clients: clients,
                  activeClient: activeClient,
                  previewEarnings: previewEarnings,
                ),
                nav: WizardNavButtons(
                  canGoBack: currentStepIndex > 0,
                  isLastStep: currentStepIndex == steps.length - 1,
                  onBack: goBack,
                  onNext: goNext,
                  onSave: saveEntry,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStep({
    required int index,
    required List<String> clients,
    required String? activeClient,
    required double previewEarnings,
  }) {
    final step = steps[index].title;

    switch (step) {
      case 'Client':
        return _clientStep(clients: clients, activeClient: activeClient);
      case 'Entry Type':
        return _entryTypeStep();
      case 'Date & Time':
        return _dateTimeStep();
      case 'Duration':
      case 'Text Counter':
        return _durationStep();
      case 'Odometer':
        return _odometerStep();
      case 'Notes':
        return _notesStep();
      case 'Review':
        return _reviewStep(previewEarnings: previewEarnings);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _clientStep({
    required List<String> clients,
    required String? activeClient,
  }) {
    return SectionCard(
      title: 'Client',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: activeClient,
              isExpanded: true,
              items: [
                for (final client in clients)
                  DropdownMenuItem(value: client, child: Text(client)),
              ],
              onChanged: (value) {
                _updateDraftState(() => selectedClient = value);
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Manage clients from Settings. Last selected client is kept in the draft.',
          ),
        ],
      ),
    );
  }

  Widget _entryTypeStep() {
    return SectionCard(
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
                _updateDraftState(() {
                  selectedType = type;
                  if (type == EntryType.textNote) {
                    textCount = textCount <= 0 ? 1 : textCount;
                  } else {
                    baseMinutes = baseMinutes < 5 ? 5 : baseMinutes;
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _dateTimeStep() {
    return SectionCard(
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
                _updateDraftState(() {
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
    );
  }

  Widget _durationStep() {
    return SectionCard(
      title: selectedType == EntryType.textNote ? 'Text Counter' : 'Duration',
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
          _updateDraftState(() {
            if (selectedType == EntryType.textNote) {
              textCount = value;
            } else {
              baseMinutes = value;
            }
          });
        },
      ),
    );
  }

  Widget _odometerStep() {
    return SectionCard(
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
    );
  }

  Widget _notesStep() {
    return SectionCard(
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
                _updateDraftState(() {
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
    );
  }

  Widget _reviewStep({required double previewEarnings}) {
    return SectionCard(
      title: 'Review & Save',
      child: Column(
        children: [
          ReviewRow(label: 'Client', value: selectedClient ?? '-'),
          ReviewRow(label: 'Type', value: selectedType.label),
          ReviewRow(label: 'Date', value: formatDate(selectedDate)),
          ReviewRow(label: 'Start', value: formatTime(startTime)),
          ReviewRow(label: 'Total minutes', value: '$totalMinutes min'),
          ReviewRow(label: 'Extra minutes', value: '+$extraMinutes min'),
          ReviewRow(label: 'Earnings preview', value: money(previewEarnings)),
          if (selectedType == EntryType.homeVisit)
            ReviewRow(
              label: 'Odometer',
              value:
                  '${odometerStartController.text.trim().isEmpty ? '-' : odometerStartController.text.trim()} → ${odometerEndController.text.trim().isEmpty ? '-' : odometerEndController.text.trim()}',
            ),
          if (selectedNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final note in selectedNotes.toList()..sort())
                    Chip(label: Text(note)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WizardStep {
  const _WizardStep({required this.title, required this.description});

  final String title;
  final String description;
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.child, required this.nav});

  final Widget child;
  final Widget nav;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [child, const SizedBox(height: 16), nav],
    );
  }
}

class _MiniPreview extends StatelessWidget {
  const _MiniPreview({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onNewEntry});

  final VoidCallback onNewEntry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Entry Saved',
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, size: 72),
              const SizedBox(height: 16),
              Text(
                'Your support work entry has been saved.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNewEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Log Another Entry'),
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
