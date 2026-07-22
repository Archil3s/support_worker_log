import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:support_worker_log/core/state/app_state.dart';
import 'package:support_worker_log/features/shell/main_shell.dart';

void main() {
  testWidgets(
    'desktop Work shell shows status shortcuts instead of duplicate workflow',
    (tester) async {
      final appState = AppState(warmGoogleAccounts: false);
      addTearDown(appState.dispose);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const MaterialApp(home: MainShell()),
        ),
      );

      expect(find.text('Quick Entry'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('desktop-work-status-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('desktop-workflow-strip')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('work-status-active')), findsOneWidget);
      expect(find.byKey(const ValueKey('work-status-today')), findsOneWidget);
      expect(find.byKey(const ValueKey('work-status-notes')), findsOneWidget);
      expect(find.byKey(const ValueKey('work-status-actions')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('work-status-notes')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Notes'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('work-status-actions')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Actions'), findsWidgets);
    },
  );

  testWidgets('mobile navigation uses Quick, Notes, Actions, Calendar order', (
    tester,
  ) async {
    final appState = AppState(warmGoogleAccounts: false);
    addTearDown(appState.dispose);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const MaterialApp(home: MainShell()),
      ),
    );

    expect(find.text('Quick Entry'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-work-status-bar')), findsNothing);

    final actionsPosition = tester.getCenter(find.text('Actions'));
    final calendarPosition = tester.getCenter(find.text('Calendar'));
    expect(actionsPosition.dx, lessThan(calendarPosition.dx));
  });
}
