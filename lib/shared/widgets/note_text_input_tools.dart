import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/speech_to_text_service.dart';

class NoteTextInputTools extends StatefulWidget {
  const NoteTextInputTools({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;

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
