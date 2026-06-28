import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/shared/widgets/support_note_breakdown_text.dart';

void main() {
  testWidgets('preview collapses repeated blank lines only', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SupportNoteBreakdownText(
            text: 'Main topic(s)\nCalled client.\n\n\nOutcome(s)\nDone.',
          ),
        ),
      ),
    );

    final selectableText = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );

    expect(
      selectableText.textSpan?.toPlainText(),
      'Main topic(s)\nCalled client.\n\nOutcome(s)\nDone.',
    );
  });
}
