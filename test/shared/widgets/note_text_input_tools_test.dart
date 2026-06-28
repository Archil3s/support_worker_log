import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/shared/widgets/note_text_input_tools.dart';

void main() {
  testWidgets('section chips keep one blank line before the next section', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: 'Main topic(s)\nCalled client.\n\n\n',
    );
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteTextInputTools(
            controller: controller,
            focusNode: focusNode,
            title: 'Support worker note',
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Full screen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Outcome'));
    await tester.pumpAndSettle();

    expect(controller.text, 'Main topic(s)\nCalled client.\n\nOutcome(s)\n');
  });
}
