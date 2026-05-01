import 'package:flutter_test/flutter_test.dart';

import 'package:support_worker_log/app.dart';

void main() {
  testWidgets('App shell renders Quick Entry', (tester) async {
    await tester.pumpWidget(const SupportWorkerLogApp());

    expect(find.text('Quick Entry'), findsWidgets);
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
