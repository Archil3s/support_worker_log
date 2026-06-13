import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/personal_log_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import 'massage_guide_html.dart';

class _MassageRoutineStep {
  const _MassageRoutineStep({
    required this.title,
    required this.instruction,
    required this.seconds,
    required this.style,
  });

  final String title;
  final String instruction;
  final int seconds;
  final String style;
}

const _guidedMassageSteps = [
  _MassageRoutineStep(
    title: 'Consent, position, and pressure check',
    instruction:
        'Ask where they feel tight, agree on stop words, support the neck and '
        'knees with pillows, and start with feather-light contact.',
    seconds: 60,
    style: 'Setup',
  ),
  _MassageRoutineStep(
    title: 'Warm hands and broad shoulder glides',
    instruction:
        'Use flat palms over upper back and shoulders. Move slowly, keep '
        'pressure broad, and avoid pressing directly on the spine.',
    seconds: 90,
    style: 'Gentle massage',
  ),
  _MassageRoutineStep(
    title: 'Upper trap pressure hold - left',
    instruction:
        'Find the soft muscle between neck and shoulder. Hold light to medium '
        'pressure, ask for comfort, then release slowly.',
    seconds: 45,
    style: 'Pressure hold',
  ),
  _MassageRoutineStep(
    title: 'Upper trap pressure hold - right',
    instruction:
        'Repeat on the other side. Keep the hold steady, not poking, and stop '
        'if it sends tingles or pain down the arm.',
    seconds: 45,
    style: 'Pressure hold',
  ),
  _MassageRoutineStep(
    title: 'Neck base circles',
    instruction:
        'Use fingertips at the base of the skull beside the spine, not on the '
        'spine. Make tiny slow circles and keep pressure gentle.',
    seconds: 60,
    style: 'Pressure point',
  ),
  _MassageRoutineStep(
    title: 'Shoulder blade edge glide',
    instruction:
        'Use thumbs or knuckles beside the shoulder blade edge. Glide slowly '
        'outward, then soften back to broad palm contact.',
    seconds: 90,
    style: 'Gentle massage',
  ),
  _MassageRoutineStep(
    title: 'Forearm and hand release',
    instruction:
        'Hold the forearm with one hand and use the other thumb in slow lines '
        'toward the wrist. Keep pressure lighter near the wrist.',
    seconds: 90,
    style: 'Gentle massage',
  ),
  _MassageRoutineStep(
    title: 'Palm pressure hold',
    instruction:
        'Press the fleshy centre of the palm gently for a short hold, release, '
        'then repeat. Avoid sharp pressure around joints.',
    seconds: 45,
    style: 'Pressure hold',
  ),
  _MassageRoutineStep(
    title: 'Calf sweep and hold',
    instruction:
        'Use broad palms up the calf muscle, then hold one tight spot lightly. '
        'Skip this if there is swelling, heat, or unexplained calf pain.',
    seconds: 90,
    style: 'Gentle massage',
  ),
  _MassageRoutineStep(
    title: 'Cool-down and feedback',
    instruction:
        'Finish with light full-hand strokes. Ask what felt best, what to skip, '
        'and whether any area feels worse.',
    seconds: 60,
    style: 'Check-in',
  ),
];

const _guidedMassageTotalSeconds = 675;

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;

  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

class MassageScreen extends StatefulWidget {
  const MassageScreen({super.key});

  static const _titlePrefix = 'Massage: ';

  @override
  State<MassageScreen> createState() => _MassageScreenState();

  static bool isMassageEntry(PersonalLogEntry entry) {
    return entry.category == PersonalLogCategory.health &&
        entry.title.startsWith(_titlePrefix);
  }
}

class _MassageScreenState extends State<MassageScreen> {
  Timer? timer;
  int activeStepIndex = 0;
  int remainingSeconds = _guidedMassageSteps.first.seconds;
  bool running = false;
  bool completed = false;

  _MassageRoutineStep get activeStep => _guidedMassageSteps[activeStepIndex];

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _start() {
    timer?.cancel();
    setState(() {
      running = true;
      completed = false;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _pause() {
    timer?.cancel();
    setState(() => running = false);
  }

  void _tick() {
    if (remainingSeconds > 1) {
      setState(() => remainingSeconds--);
      return;
    }

    if (activeStepIndex >= _guidedMassageSteps.length - 1) {
      timer?.cancel();
      setState(() {
        remainingSeconds = 0;
        running = false;
        completed = true;
      });
      return;
    }

    _goToStep(activeStepIndex + 1, keepRunning: true);
  }

  void _goToStep(int index, {bool keepRunning = false}) {
    final safeIndex = index.clamp(0, _guidedMassageSteps.length - 1);

    setState(() {
      activeStepIndex = safeIndex;
      remainingSeconds = _guidedMassageSteps[safeIndex].seconds;
      completed = false;
      running = keepRunning;
    });

    if (keepRunning) {
      _start();
    } else {
      timer?.cancel();
    }
  }

  void _reset() {
    timer?.cancel();
    setState(() {
      activeStepIndex = 0;
      remainingSeconds = _guidedMassageSteps.first.seconds;
      running = false;
      completed = false;
    });
  }

  void _logCompletedSet() {
    final totalMinutes = (_guidedMassageTotalSeconds / 60).round();

    context.read<AppState>().addPersonalLogEntry(
      PersonalLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: PersonalLogCategory.health,
        date: DateTime.now(),
        title: '${MassageScreen._titlePrefix}Guided pressure-point set',
        metric: '$totalMinutes min guided gentle massage + pressure holds',
        notes: [
          'Completed guided countdown flow.',
          for (final step in _guidedMassageSteps)
            '${step.title}: ${_formatDuration(step.seconds)}',
        ].join('\n'),
      ),
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Massage set logged.')));
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        context
            .watch<AppState>()
            .personalLogEntries
            .where(MassageScreen.isMassageEntry)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final latest = entries.isEmpty ? null : entries.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          title: 'Massage',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricPill(label: 'Sessions', value: '${entries.length}'),
                  _MetricPill(
                    label: 'Latest',
                    value: latest == null ? '-' : formatDate(latest.date),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _SafetyBrief(),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _showMassageLogSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Log Partner Massage'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _VisualGuideCard(),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Guided Pressure-Point Set',
          child: _GuidedMassageTimer(
            step: activeStep,
            stepIndex: activeStepIndex,
            stepCount: _guidedMassageSteps.length,
            remainingSeconds: remainingSeconds,
            totalStepSeconds: activeStep.seconds,
            running: running,
            completed: completed,
            onStart: _start,
            onPause: _pause,
            onNext: activeStepIndex >= _guidedMassageSteps.length - 1
                ? null
                : () => _goToStep(activeStepIndex + 1),
            onBack: activeStepIndex == 0
                ? null
                : () => _goToStep(activeStepIndex - 1),
            onReset: _reset,
            onLogCompleted: _logCompletedSet,
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Massage Logs',
          child: entries.isEmpty
              ? const EmptyState(message: 'No massage logs yet.')
              : Column(
                  children: [
                    for (final entry in entries) _MassageLogTile(entry: entry),
                  ],
                ),
        ),
      ],
    );
  }
}

class _VisualGuideCard extends StatelessWidget {
  const _VisualGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF34405F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SectionAccent(),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Visual guide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            MassageGuideHtml(),
          ],
        ),
      ),
    );
  }
}

class _SectionAccent extends StatelessWidget {
  const _SectionAccent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF4F8DF7),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SafetyBrief extends StatelessWidget {
  const _SafetyBrief();

  @override
  Widget build(BuildContext context) {
    return const _InfoPanel(
      icon: Icons.health_and_safety_outlined,
      title: 'Start with consent and light pressure',
      body:
          'Ask what feels tight, agree on stop words, and keep checking in. '
          'Stop for sharp pain, numbness, tingling, dizziness, fever, open '
          'skin, new swelling, or suspected injury.',
    );
  }
}

class _GuidedMassageTimer extends StatelessWidget {
  const _GuidedMassageTimer({
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.remainingSeconds,
    required this.totalStepSeconds,
    required this.running,
    required this.completed,
    required this.onStart,
    required this.onPause,
    required this.onNext,
    required this.onBack,
    required this.onReset,
    required this.onLogCompleted,
  });

  final _MassageRoutineStep step;
  final int stepIndex;
  final int stepCount;
  final int remainingSeconds;
  final int totalStepSeconds;
  final bool running;
  final bool completed;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback onReset;
  final VoidCallback onLogCompleted;

  @override
  Widget build(BuildContext context) {
    final progress = totalStepSeconds == 0
        ? 0.0
        : 1 - (remainingSeconds / totalStepSeconds);
    final totalMinutes = (_guidedMassageTotalSeconds / 60).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoPanel(
          icon: Icons.timer_outlined,
          title: '$totalMinutes minute gentle massage + pressure hold mix',
          body:
              'Use slow warm hands first, then light steady holds. Avoid the '
              'spine, front of neck, throat, bruises, varicose veins, and any '
              'spot that gives sharp pain, numbness, tingling, or dizziness.',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF34405F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Step ${stepIndex + 1} of $stepCount',
                      style: const TextStyle(
                        color: Color(0xFF8396C7),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _RoutineStylePill(label: step.style),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                completed ? 'Set complete' : step.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                completed
                    ? 'Check in, offer water, and write down what helped.'
                    : step.instruction,
                style: const TextStyle(
                  color: Color(0xFFCDD7F0),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  completed ? 'Done' : _formatDuration(remainingSeconds),
                  style: const TextStyle(
                    color: Color(0xFF31E981),
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: completed ? 1 : progress.clamp(0, 1),
                  minHeight: 10,
                  backgroundColor: const Color(0xFF20283B),
                  color: const Color(0xFF31E981),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.skip_previous_rounded),
                    label: const Text('Back'),
                  ),
                  FilledButton.icon(
                    onPressed: completed
                        ? onReset
                        : running
                        ? onPause
                        : onStart,
                    icon: Icon(
                      completed
                          ? Icons.replay_rounded
                          : running
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      completed
                          ? 'Restart'
                          : running
                          ? 'Pause'
                          : 'Start',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Next'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              if (completed) ...[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: onLogCompleted,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Log completed set'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _RoutineStepList(activeIndex: stepIndex),
      ],
    );
  }
}

class _RoutineStylePill extends StatelessWidget {
  const _RoutineStylePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF13294D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF4F8DF7)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RoutineStepList extends StatelessWidget {
  const _RoutineStepList({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < _guidedMassageSteps.length; index++)
          _RoutineStepTile(
            step: _guidedMassageSteps[index],
            index: index,
            active: index == activeIndex,
          ),
      ],
    );
  }
}

class _RoutineStepTile extends StatelessWidget {
  const _RoutineStepTile({
    required this.step,
    required this.index,
    required this.active,
  });

  final _MassageRoutineStep step;
  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF13294D) : const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? const Color(0xFF4F8DF7) : const Color(0xFF34405F),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: active
                ? const Color(0xFF31E981)
                : const Color(0xFF20283B),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDuration(step.seconds)} | ${step.style}',
                  style: const TextStyle(
                    color: Color(0xFF8396C7),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102A1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF31E981)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF31E981)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFFD7FFE9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8396C7),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MassageLogTile extends StatelessWidget {
  const _MassageLogTile({required this.entry});

  final PersonalLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final title = entry.title.replaceFirst(MassageScreen._titlePrefix, '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.spa_outlined, color: Color(0xFF4F8DF7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Partner massage session' : title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(entry.date),
                  style: const TextStyle(
                    color: Color(0xFF8396C7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.metric.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(entry.metric),
                ],
                if (entry.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.notes,
                    style: const TextStyle(color: Color(0xFFCDD7F0)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showMassageLogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const _MassageLogSheet(),
  );
}

class _MassageLogSheet extends StatefulWidget {
  const _MassageLogSheet();

  @override
  State<_MassageLogSheet> createState() => _MassageLogSheetState();
}

class _MassageLogSheetState extends State<_MassageLogSheet> {
  final focusController = TextEditingController();
  final comfortController = TextEditingController();
  final partnerFeedbackController = TextEditingController();
  final nextSessionController = TextEditingController();
  DateTime date = DateTime.now();

  @override
  void dispose() {
    focusController.dispose();
    comfortController.dispose();
    partnerFeedbackController.dispose();
    nextSessionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;
    setState(() => date = picked);
  }

  void _save() {
    final focus = focusController.text.trim();
    final comfort = comfortController.text.trim();
    final feedback = partnerFeedbackController.text.trim();
    final nextSession = nextSessionController.text.trim();

    if (focus.isEmpty && comfort.isEmpty && feedback.isEmpty) return;

    context.read<AppState>().addPersonalLogEntry(
      PersonalLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: PersonalLogCategory.health,
        date: date,
        title:
            '${MassageScreen._titlePrefix}${focus.isEmpty ? 'Partner session' : focus}',
        metric: comfort.isEmpty ? '' : 'Comfort: $comfort',
        notes: [
          if (feedback.isNotEmpty) 'Partner feedback: $feedback',
          if (nextSession.isNotEmpty) 'Next session: $nextSession',
        ].join('\n\n'),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Partner Massage Log',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(formatDate(date)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: focusController,
              decoration: const InputDecoration(
                labelText: 'Focus areas',
                hintText: 'Neck, shoulders, back, legs, feet',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: comfortController,
              decoration: const InputDecoration(
                labelText: 'Comfort / pressure',
                hintText: 'Light felt best, avoid left trap next time',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: partnerFeedbackController,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Partner feedback',
                hintText: 'What relaxed them, what was sore, what to skip',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nextSessionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Next session plan',
                hintText: 'Repeat shoulders, add calves, use more pillows',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Massage Log'),
            ),
          ],
        ),
      ),
    );
  }
}
