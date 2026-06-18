String appendVoiceNoteText({required String existing, required String spoken}) {
  final current = normalizeVoiceTranscript(existing);
  final shouldKeepTrailingBreak = RegExp(r'\n\s*\n\s*$').hasMatch(spoken);
  final next = normalizeVoiceTranscript(spoken);
  if (next.isEmpty) return current;
  final combined = current.isEmpty ? next : '$current\n\n$next';
  return shouldKeepTrailingBreak ? '$combined\n\n' : combined;
}

String appendTrailingVoiceBreak(String value) {
  final current = normalizeVoiceTranscript(value);
  if (current.isEmpty) return '';
  return '$current\n\n';
}

String normalizeVoiceTranscript(String value) {
  return value
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}
