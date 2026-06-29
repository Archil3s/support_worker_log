import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:support_worker_log/core/state/app_state.dart';
import 'package:support_worker_log/features/shell/main_shell.dart';

void main() {
  testWidgets(
    'desktop work flow starts on quick entry and follows task order',
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
        find.byKey(const ValueKey('desktop-workflow-strip')),
        findsOneWidget,
      );

      final workflowSteps = <String>[
        'quick',
        'notes',
        'actions',
        'calendar',
        'entries',
        'pay',
      ];

      for (final step in workflowSteps) {
        expect(find.byKey(ValueKey('workflow-step-$step')), findsOneWidget);
      }

      expect(find.byKey(const ValueKey('workflow-previous')), findsNothing);
      expect(find.byKey(const ValueKey('workflow-next')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('workflow-step-notes')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Notes'), findsWidgets);
      expect(find.byKey(const ValueKey('workflow-previous')), findsOneWidget);
      expect(find.byKey(const ValueKey('workflow-next')), findsOneWidget);
    },
  );

  testWidgets('desktop work flow previous and next move between sections', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const ValueKey('workflow-next')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Notes'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('workflow-previous')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Quick Entry'), findsOneWidget);
  });
}
