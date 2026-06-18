import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/utils/voice_note_text.dart';

void main() {
  test('appendVoiceNoteText keeps silence paragraph breaks', () {
    final result = appendVoiceNoteText(
      existing: 'First thought',
      spoken: 'Second thought\n\nThird thought',
    );

    expect(result, 'First thought\n\nSecond thought\n\nThird thought');
  });

  test('appendVoiceNoteText keeps trailing auto-stop paragraph break', () {
    final result = appendVoiceNoteText(
      existing: 'First thought',
      spoken: 'Second thought\n\n',
    );

    expect(result, 'First thought\n\nSecond thought\n\n');
  });

  test('appendTrailingVoiceBreak adds one blank paragraph then stops', () {
    expect(
      appendTrailingVoiceBreak('  First thought  \n\n\n'),
      'First thought\n\n',
    );
  });

  test('normalizeVoiceTranscript trims excess spacing', () {
    expect(
      normalizeVoiceTranscript('  First   line  \n\n\n  Second line  '),
      'First line\n\nSecond line',
    );
  });
}
