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

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.checklist_rtl_outlined),
                  text: 'Next Actions',
                ),
                Tab(icon: Icon(Icons.task_alt_outlined), text: 'Mixed'),
              ],
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

  List<_EntryAction> get _completedActions {
    return const [];
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
    final completedActions = _completedActions;

    return ListView(
      padding: webPagePadding(context),
      children: [
        SectionCard(
          title: 'Next Actions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${openActions.length} open | ${completedActions.length} completed',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Actions come from the Next action(s) section when you finish a visit. Ticking or deleting an action removes it from the saved entry.',
                style: TextStyle(color: Color(0xFF8396C7), height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (openActions.isEmpty && completedActions.isEmpty)
          const SectionCard(
            title: 'No Actions',
            child: EmptyState(
              message:
                  'No next actions yet. Add them in the breakdown when you finish a visit.',
            ),
          )
        else ...[
          SectionCard(
            title: 'Open',
            child: openActions.isEmpty
                ? const EmptyState(message: 'No open actions.')
                : Column(
                    children: [
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
                  ),
          ),
          if (completedActions.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Completed Log',
              child: Column(
                children: [
                  for (final item in completedActions)
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
              ),
            ),
          ],
        ],
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
      child: CheckboxListTile(
        value: action.isCompleted,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF31E981),
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Open note',
              onPressed: () => _openNote(context),
              icon: const Icon(Icons.note_alt_outlined),
            ),
            IconButton(
              tooltip: 'Delete action',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        title: Text(
          action.text,
          style: TextStyle(
            decoration: action.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text('${entry.client} | ${formatDate(entry.date)}'),
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
          title: 'Add Mixed Action',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<GeneralActionScope>(
                segments: const [
                  ButtonSegment<GeneralActionScope>(
                    value: GeneralActionScope.client,
                    icon: Icon(Icons.person_outline),
                    label: Text('Client'),
                  ),
                  ButtonSegment<GeneralActionScope>(
                    value: GeneralActionScope.knowledgeGap,
                    icon: Icon(Icons.school_outlined),
                    label: Text('Knowledge'),
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
                  decoration: const InputDecoration(labelText: 'Client'),
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
                minLines: 3,
                maxLines: 7,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: scope == GeneralActionScope.client
                      ? 'Client action'
                      : 'Knowledge gap / thing to look into',
                  hintText: scope == GeneralActionScope.client
                      ? 'What needs doing for this client?'
                      : 'What do you need to research or clarify?',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.add_task_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _addAction,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Action'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GeneralActionSection(
          title: 'Client Actions',
          emptyMessage: 'No open client actions.',
          actions: clientActions,
          onChanged: _toggleAction,
          onDelete: _deleteAction,
        ),
        const SizedBox(height: 12),
        _GeneralActionSection(
          title: 'Knowledge Gaps',
          emptyMessage: 'No open knowledge gaps.',
          actions: knowledgeActions,
          onChanged: _toggleAction,
          onDelete: _deleteAction,
        ),
        if (completedActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GeneralActionSection(
            title: 'Completed Mixed Actions',
            emptyMessage: 'No completed mixed actions.',
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
      title: title,
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
        : 'Knowledge gap';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: action.isCompleted,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF31E981),
        secondary: IconButton(
          tooltip: 'Delete action',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
        title: Text(
          action.title,
          style: TextStyle(
            decoration: action.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          completedAt == null
              ? subtitle
              : '$subtitle | completed ${_dateTimeText(context, completedAt)}',
        ),
      ),
    );
  }
}
