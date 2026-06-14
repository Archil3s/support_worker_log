import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/features/cleaning/cleaning_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('house roster fits an iPhone 13 viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(body: CleaningScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Roster'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);

    await tester.tap(find.text('Roster'));
    await tester.pumpAndSettle();

    expect(find.text('House roster'), findsOneWidget);
    expect(find.text('Me'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
