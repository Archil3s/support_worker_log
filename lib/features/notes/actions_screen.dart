import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/general_action.dart';
import '../../core/models/work_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/web_spacing.dart';
import 'notes_screen.dart';

String _dateTimeText(BuildContext context, DateTime value) {
  final time = TimeOfDay.fromDateTime(value).format(context);
  return '${formatDate(value)} $time';
}

class ActionsScreen extends StatelessWidget {
  const ActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries =
        appState.entries.where((entry) => entry.nextActions.isNotEmpty).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final clients = {
      ...appState.clients,
      ...appState.entries.map((entry) => entry.client),
    }.where((client) => client.trim().isNotEmpty).toList()..sort();
    final visitActionCount = entries.fold<int>(
      0,
      (count, entry) =>
          count +
          entry.nextActions.where((action) => !action.isCompleted).length,
    );
    final otherOpenCount = appState.generalActions
        .where((action) => !action.isCompleted)
        .length;
    final completedCount = appState.generalActions
        .where((action) => action.isCompleted)
        .length;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: webPagePadding(context).copyWith(bottom: 0),
            child: _ActionsHeader(
              visitActionCount: visitActionCount,
              otherOpenCount: otherOpenCount,
              completedCount: completedCount,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF151D2D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C3852)),
              ),
              child: const TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Color(0xFF253A61),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                tabs: [
                  Tab(
                    icon: Icon(Icons.follow_the_signs_outlined),
                    text: 'Visit actions',
                  ),
                  Tab(
                    icon: Icon(Icons.add_task_outlined),
                    text: 'Other actions',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _NextActionsTab(entries: entries),
                _GeneralActionsTab(
                  clients: clients,
                  actions: appState.generalActions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsHeader extends StatelessWidget {
  const _ActionsHeader({
    required this.visitActionCount,
    required this.otherOpenCount,
    required this.completedCount,
  });

  final int visitActionCount;
  final int otherOpenCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172A4D), Color(0xFF101827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2E4C7E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _ActionsHeaderIcon(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actions workspace',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Keep visit follow-ups and other tasks in one place.',
                      style: TextStyle(color: Color(0xFFA9B9DD), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionCountBadge(
                label: 'Visit',
                value: visitActionCount,
                color: const Color(0xFFFFC857),
              ),
              _ActionCountBadge(
                label: 'Other open',
                value: otherOpenCount,
                color: const Color(0xFF8EA7FF),
              ),
              _ActionCountBadge(
                label: 'Completed',
                value: completedCount,
                color: const Color(0xFF31E981),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionsHeaderIcon extends StatelessWidget {
  const _ActionsHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF4F8DF7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Icon(Icons.checklist_rtl, color: Colors.white),
    );
  }
}

class _ActionCountBadge extends StatelessWidget {
  const _ActionCountBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NextActionsTab extends StatelessWidget {
  const _NextActionsTab({required this.entries});

  final List<WorkEntry> entries;

  List<_EntryAction> get _openActions {
    final actions = <_EntryAction>[];

    for (final entry in entries) {
      for (final action in entry.nextActions) {
        if (!action.isCompleted) {
          actions.add(_EntryAction(entry: entry, action: action));
        }
      }
    }

    return actions;
  }

  void _deleteAction({
    required BuildContext context,
    required WorkEntry entry,
    required NextActionItem action,
  }) {
    context.read<AppState>().deleteNextAction(entry: entry, action: action);
  }

  @override
  Widget build(BuildContext context) {
    final openActions = _openActions;

    return ListView(
      padding: webPagePadding(context),
      children: [
        SectionCard(
          title: 'Visit follow-ups',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${openActions.length} open',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'These follow-ups come from saved visit notes. Marking one done removes it from the open list and the visit entry.',
                style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (openActions.isEmpty)
          const SectionCard(
            title: 'All caught up',
            child: EmptyState(
              message:
                  'No visit follow-ups are open. Add one while finishing a visit note.',
            ),
          )
        else
          for (final item in openActions)
            _NextActionTile(
              entry: item.entry,
              action: item.action,
              onChanged: (_) => _deleteAction(
                context: context,
                entry: item.entry,
                action: item.action,
              ),
              onDelete: () => _deleteAction(
                context: context,
                entry: item.entry,
                action: item.action,
              ),
            ),
      ],
    );
  }
}

class _EntryAction {
  const _EntryAction({required this.entry, required this.action});

  final WorkEntry entry;
  final NextActionItem action;
}

class _NextActionTile extends StatelessWidget {
  const _NextActionTile({
    required this.entry,
    required this.action,
    required this.onChanged,
    required this.onDelete,
  });

  final WorkEntry entry;
  final NextActionItem action;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  Future<void> _openNote(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntryNoteSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
        child: Row(
          children: [
            Checkbox(
              value: action.isCompleted,
              onChanged: (value) => onChanged(value ?? false),
              activeColor: const Color(0xFF31E981),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.text,
                    style: TextStyle(
                      decoration: action.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _ActionMetaPill(
                        icon: Icons.person_outline,
                        label: entry.client,
                      ),
                      _ActionMetaPill(
                        icon: Icons.event_outlined,
                        label: formatDate(entry.date),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Open note',
              onPressed: () => _openNote(context),
              icon: const Icon(Icons.note_alt_outlined),
            ),
            IconButton(
              tooltip: 'Delete action',
              onPressed: onDelete,
              color: const Color(0xFFFF6B6B),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionMetaPill extends StatelessWidget {
  const _ActionMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF8EA7FF)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB8C4E2),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralActionsTab extends StatefulWidget {
  const _GeneralActionsTab({required this.clients, required this.actions});

  final List<String> clients;
  final List<GeneralActionItem> actions;

  @override
  State<_GeneralActionsTab> createState() => _GeneralActionsTabState();
}

class _GeneralActionsTabState extends State<_GeneralActionsTab> {
  final actionController = TextEditingController();

  GeneralActionScope scope = GeneralActionScope.client;
  String? selectedClient;

  @override
  void initState() {
    super.initState();
    selectedClient = widget.clients.isEmpty ? null : widget.clients.first;
  }

  @override
  void didUpdateWidget(covariant _GeneralActionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (selectedClient != null && widget.clients.contains(selectedClient)) {
      return;
    }

    selectedClient = widget.clients.isEmpty ? null : widget.clients.first;
  }

  @override
  void dispose() {
    actionController.dispose();
    super.dispose();
  }

  List<GeneralActionItem> get _openActions {
    return widget.actions.where((action) => !action.isCompleted).toList();
  }

  List<GeneralActionItem> get _completedActions {
    return widget.actions.where((action) => action.isCompleted).toList();
  }

  void _addAction() {
    final title = actionController.text.trim();
    if (title.isEmpty) return;

    final client = scope == GeneralActionScope.client
        ? selectedClient ??
              (widget.clients.isEmpty ? null : widget.clients.first)
        : null;

    if (scope == GeneralActionScope.client &&
        (client == null || client.trim().isEmpty)) {
      return;
    }

    context.read<AppState>().addGeneralAction(
      GeneralActionItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        scope: scope,
        client: client,
        createdAt: DateTime.now(),
      ),
    );

    actionController.clear();
  }

  void _toggleAction(GeneralActionItem action, bool completed) {
    context.read<AppState>().updateGeneralAction(
      action.copyWith(
        completedAt: completed ? DateTime.now() : null,
        clearCompletedAt: !completed,
      ),
    );
  }

  void _deleteAction(GeneralActionItem action) {
    context.read<AppState>().deleteGeneralAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final openActions = _openActions;
    final completedActions = _completedActions;
    final clientActions = openActions
        .where((action) => action.scope == GeneralActionScope.client)
        .toList();
    final knowledgeActions = openActions
        .where((action) => action.scope == GeneralActionScope.knowledgeGap)
        .toList();

    return ListView(
      padding: webPagePadding(context),
      children: [
        SectionCard(
          title: 'Add an action',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Keep standalone tasks here when they are not tied to a visit note.',
                style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
              ),
              const SizedBox(height: 12),
              SegmentedButton<GeneralActionScope>(
                segments: const [
                  ButtonSegment<GeneralActionScope>(
                    value: GeneralActionScope.client,
                    icon: Icon(Icons.person_outline),
                    label: Text('Person'),
                  ),
                  ButtonSegment<GeneralActionScope>(
                    value: GeneralActionScope.knowledgeGap,
                    icon: Icon(Icons.school_outlined),
                    label: Text('Research'),
                  ),
                ],
                selected: {scope},
                onSelectionChanged: (values) {
                  setState(() => scope = values.first);
                },
              ),
              if (scope == GeneralActionScope.client) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedClient,
                  decoration: const InputDecoration(
                    labelText: 'Person',
                    prefixIcon: Icon(Icons.person_search_outlined),
                  ),
                  items: [
                    for (final client in widget.clients)
                      DropdownMenuItem<String>(
                        value: client,
                        child: Text(client, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => selectedClient = value),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: actionController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: scope == GeneralActionScope.client
                      ? 'What needs doing?'
                      : 'What needs researching?',
                  hintText: scope == GeneralActionScope.client
                      ? 'Enter a follow-up for this person'
                      : 'What do you need to research or clarify?',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.add_task_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _addAction,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add to open actions'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GeneralActionSection(
          title: 'For people',
          emptyMessage: 'No open actions for people.',
          actions: clientActions,
          onChanged: _toggleAction,
          onDelete: _deleteAction,
        ),
        const SizedBox(height: 12),
        _GeneralActionSection(
          title: 'Research & learning',
          emptyMessage: 'No open research actions.',
          actions: knowledgeActions,
          onChanged: _toggleAction,
          onDelete: _deleteAction,
        ),
        if (completedActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GeneralActionSection(
            title: 'Completed',
            emptyMessage: 'No completed actions.',
            actions: completedActions,
            onChanged: _toggleAction,
            onDelete: _deleteAction,
          ),
        ],
      ],
    );
  }
}

class _GeneralActionSection extends StatelessWidget {
  const _GeneralActionSection({
    required this.title,
    required this.emptyMessage,
    required this.actions,
    required this.onChanged,
    required this.onDelete,
  });

  final String title;
  final String emptyMessage;
  final List<GeneralActionItem> actions;
  final void Function(GeneralActionItem action, bool completed) onChanged;
  final ValueChanged<GeneralActionItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '$title (${actions.length})',
      child: actions.isEmpty
          ? EmptyState(message: emptyMessage)
          : Column(
              children: [
                for (final action in actions)
                  _GeneralActionTile(
                    action: action,
                    onChanged: (completed) => onChanged(action, completed),
                    onDelete: () => onDelete(action),
                  ),
              ],
            ),
    );
  }
}

class _GeneralActionTile extends StatelessWidget {
  const _GeneralActionTile({
    required this.action,
    required this.onChanged,
    required this.onDelete,
  });

  final GeneralActionItem action;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final completedAt = action.completedAt;
    final subtitle = action.scope == GeneralActionScope.client
        ? action.client ?? 'Client action'
        : 'Research';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
        child: Row(
          children: [
            Checkbox(
              value: action.isCompleted,
              onChanged: (value) => onChanged(value ?? false),
              activeColor: const Color(0xFF31E981),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: TextStyle(
                      decoration: action.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _ActionMetaPill(
                        icon: action.scope == GeneralActionScope.client
                            ? Icons.person_outline
                            : Icons.school_outlined,
                        label: subtitle,
                      ),
                      if (completedAt != null)
                        _ActionMetaPill(
                          icon: Icons.task_alt_outlined,
                          label: 'Done ${_dateTimeText(context, completedAt)}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete action',
              onPressed: onDelete,
              color: const Color(0xFFFF6B6B),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
