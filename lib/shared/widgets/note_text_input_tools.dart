import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/speech_to_text_service.dart';

class NoteTextInputTools extends StatefulWidget {
  const NoteTextInputTools({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.title,
    this.onChanged,
    this.showFullscreenButton = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String title;
  final ValueChanged<String>? onChanged;
  final bool showFullscreenButton;

  @override
  State<NoteTextInputTools> createState() => _NoteTextInputToolsState();
}

class _NoteTextInputToolsState extends State<NoteTextInputTools> {
  final SpeechToTextService speechService = SpeechToTextService();
  bool listening = false;

  @override
  void dispose() {
    speechService.stopListening();
    super.dispose();
  }

  Future<void> _paste() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _insertText(text);
  }

  Future<void> _listen() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (listening) {
      speechService.stopListening();
      setState(() => listening = false);
      return;
    }

    setState(() => listening = true);
    final text = await speechService.listenOnce();

    if (!mounted) return;

    setState(() => listening = false);
    if (text == null || text.isEmpty) return;
    _insertText(text);
  }

  void _keyboard() {
    widget.focusNode.requestFocus();
  }

  void _backspace() {
    FocusManager.instance.primaryFocus?.unfocus();
    final value = widget.controller.value;
    final text = value.text;
    if (text.isEmpty) return;

    final selection = value.selection;
    if (selection.isValid && !selection.isCollapsed) {
      _replaceSelection('');
      return;
    }

    final end = selection.isValid ? selection.end : text.length;
    if (end <= 0) return;

    final start = _previousCharacterStart(text, end);
    final next = text.replaceRange(start, end, '');
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start),
    );
    widget.onChanged?.call(next);
  }

  void _clear() {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  Future<void> _openFullscreen() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenNoteEditor(
          controller: widget.controller,
          title: widget.title,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }

  void _insertText(String text) {
    final value = widget.controller.value;
    final current = value.text;
    final selection = value.selection;

    if (selection.isValid) {
      _replaceSelection(_spacedInsertText(current, selection, text));
      return;
    }

    final prefix = current.isEmpty || _endsWithWhitespace(current) ? '' : ' ';
    final next = '$current$prefix$text';
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    widget.onChanged?.call(next);
  }

  void _replaceSelection(String replacement) {
    final value = widget.controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final next = value.text.replaceRange(start, end, replacement);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    widget.onChanged?.call(next);
  }

  String _spacedInsertText(
    String current,
    TextSelection selection,
    String insert,
  ) {
    final before = current.substring(0, selection.start);
    final after = current.substring(selection.end);
    final prefix = before.isEmpty || _endsWithWhitespace(before) ? '' : ' ';
    final suffix = after.isEmpty || _startsWithWhitespace(after) ? '' : ' ';
    return '$prefix$insert$suffix';
  }

  bool _endsWithWhitespace(String value) {
    return RegExp(r'\s$').hasMatch(value);
  }

  bool _startsWithWhitespace(String value) {
    return RegExp(r'^\s').hasMatch(value);
  }

  int _previousCharacterStart(String text, int end) {
    final characters = text.characters.take(end).toList();
    if (characters.isEmpty) return 0;
    return text.characters.take(characters.length - 1).toString().length;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (widget.showFullscreenButton)
          _ToolButton(
            icon: Icons.open_in_full_outlined,
            label: 'Full screen',
            onPressed: _openFullscreen,
          ),
        _ToolButton(
          icon: Icons.keyboard_alt_outlined,
          label: 'Keyboard',
          onPressed: _keyboard,
        ),
        _ToolButton(
          icon: Icons.content_paste_outlined,
          label: 'Paste',
          onPressed: _paste,
        ),
        _ToolButton(
          icon: listening ? Icons.stop_circle_outlined : Icons.mic_outlined,
          label: listening ? 'Stop' : 'Voice',
          selected: listening,
          onPressed: _listen,
        ),
        _ToolButton(
          icon: Icons.backspace_outlined,
          label: 'Backspace',
          onPressed: _backspace,
        ),
        _ToolButton(
          icon: Icons.clear_all_outlined,
          label: 'Clear',
          onPressed: _clear,
        ),
      ],
    );
  }
}

class _FullScreenNoteEditor extends StatefulWidget {
  const _FullScreenNoteEditor({
    required this.controller,
    required this.title,
    this.onChanged,
  });

  final TextEditingController controller;
  final String title;
  final ValueChanged<String>? onChanged;

  @override
  State<_FullScreenNoteEditor> createState() => _FullScreenNoteEditorState();
}

class _FullScreenNoteEditorState extends State<_FullScreenNoteEditor> {
  late final FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    focusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int get _wordCount {
    return RegExp(
      r"[A-Za-z0-9]+(?:[-'][A-Za-z0-9]+)?",
    ).allMatches(widget.controller.text).length;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$_wordCount words',
                    style: const TextStyle(
                      color: Color(0xFF8396C7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: NoteTextInputTools(
                      controller: widget.controller,
                      focusNode: focusNode,
                      title: widget.title,
                      onChanged: widget.onChanged,
                      showFullscreenButton: false,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextField(
                  controller: widget.controller,
                  focusNode: focusNode,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textAlignVertical: TextAlignVertical.top,
                  scrollPadding: EdgeInsets.only(bottom: keyboardBottom + 260),
                  onChanged: widget.onChanged,
                  decoration: InputDecoration(
                    labelText: widget.title,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      visualDensity: VisualDensity.compact,
      tooltip: label,
      isSelected: selected,
      selectedIcon: Icon(icon),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}
