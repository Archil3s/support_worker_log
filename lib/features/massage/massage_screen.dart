import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/personal_log_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import 'massage_guide_html.dart';

class MassageScreen extends StatelessWidget {
  const MassageScreen({super.key});

  static const _titlePrefix = 'Massage: ';

  @override
  Widget build(BuildContext context) {
    final entries =
        context
            .watch<AppState>()
            .personalLogEntries
            .where(_isMassageEntry)
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

  static bool _isMassageEntry(PersonalLogEntry entry) {
    return entry.category == PersonalLogCategory.health &&
        entry.title.startsWith(_titlePrefix);
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
