String appendVoiceNoteText({required String existing, required String spoken}) {
  final current = normalizeVoiceTranscript(existing);
  final next = normalizeVoiceTranscript(spoken);
  if (next.isEmpty) return current;
  if (current.isEmpty) return next;
  return '$current\n\n$next';
}

String normalizeVoiceTranscript(String value) {
  return value
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}
