import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:support_worker_log/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App shell renders Quick Entry', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SupportWorkerLogApp());
    await tester.pumpAndSettle();

    expect(find.text('Quick Entry'), findsWidgets);
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
