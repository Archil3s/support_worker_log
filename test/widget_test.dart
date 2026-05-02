import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:support_worker_log/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App shell renders Dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SupportWorkerLogApp());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Current Fortnight'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Log New Entry'), findsOneWidget);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Quick'), findsOneWidget);
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Entries'), findsWidgets);
    expect(find.text('Settings'), findsOneWidget);
  });
}
