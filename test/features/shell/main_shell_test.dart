import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/models/app_mode.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/models/work_entry.dart';
import 'package:support_worker_log/core/state/app_state.dart';
import 'package:support_worker_log/features/shell/main_shell.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('desktop Work shell shows monthly statistics and guided flow', (
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
    appState.addEntry(
      WorkEntry(
        id: 'month-entry',
        client: 'Test client',
        type: EntryType.homeVisit,
        date: DateTime.now(),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        minutes: 120,
        notes: const [],
        nextActions: [
          NextActionItem(
            id: 'month-action',
            text: 'Follow up',
            createdAt: DateTime.now(),
          ),
        ],
        odometerStart: 100,
        odometerEnd: 110,
      ),
    );
    final now = DateTime.now();
    appState.addEntry(
      WorkEntry(
        id: 'previous-month-text',
        client: 'Previous client',
        type: EntryType.textNote,
        date: DateTime(now.year, now.month - 1, 15),
        startTime: const TimeOfDay(hour: 10, minute: 0),
        minutes: 20,
        notes: const [],
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const MaterialApp(home: MainShell()),
      ),
    );

    expect(find.text('Work'), findsWidgets);
    expect(
      find.byKey(const ValueKey('work-monthly-overview-panel')),
      findsOneWidget,
    );
    expect(find.text('BROWSE MONTHS'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-work-status-bar')), findsNothing);
    expect(find.byKey(const ValueKey('desktop-workflow-strip')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-month-stat-entries')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-month-stat-hours')),
        matching: find.text('2.50h'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-month-stat-earned')),
        matching: find.text(r'$107.50'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-month-stat-kilometres')),
        matching: find.text('10.0km'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-contact-type-homeVisit')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-contact-type-textNote')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-contact-type-professionalContact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-contact-type-phoneCall')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-contact-type-videoCall')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-contact-type-emailClient')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-contact-type-emailProfessional')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-contact-type-adminEducationResources')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-month-copy-totals')),
      findsOneWidget,
    );
    expect(find.text('1 to finish'), findsOneWidget);
    expect(find.text('1 open'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('work-month-previous')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-month-stat-entries')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-contact-type-homeVisit')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-contact-type-textNote')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.tap(find.byKey(const ValueKey('work-month-copy-totals')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(copiedText, contains('Work totals -'));
    expect(copiedText, contains('Texts: 1'));
    expect(find.textContaining('totals copied'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('work-month-next')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('work-flow-notes')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Notes'), findsWidgets);
    expect(
      find.byKey(const ValueKey('desktop-work-status-bar')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('work-status-actions')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Actions'), findsWidgets);
  });

  testWidgets('mobile Work flow shows overview and keeps action order', (
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

    expect(find.text('Work'), findsWidgets);
    expect(
      find.byKey(const ValueKey('work-monthly-overview-panel')),
      findsOneWidget,
    );
    expect(find.text('BROWSE MONTHS'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    final browseMonthsRect = tester.getRect(find.text('BROWSE MONTHS'));
    expect(browseMonthsRect.top, greaterThanOrEqualTo(0));
    expect(browseMonthsRect.bottom, lessThanOrEqualTo(800));
    expect(find.byKey(const ValueKey('desktop-work-status-bar')), findsNothing);
    final entriesRect = tester.getRect(
      find.byKey(const ValueKey('work-month-stat-entries')),
    );
    final hoursRect = tester.getRect(
      find.byKey(const ValueKey('work-month-stat-hours')),
    );
    final earnedRect = tester.getRect(
      find.byKey(const ValueKey('work-month-stat-earned')),
    );
    expect(entriesRect.top, hoursRect.top);
    expect(earnedRect.top, greaterThan(entriesRect.top));

    final actionsPosition = tester.getCenter(find.text('Actions').last);
    final calendarPosition = tester.getCenter(find.text('Calendar'));
    expect(actionsPosition.dx, lessThan(calendarPosition.dx));
  });

  testWidgets('PAYE navigation and screen remain unchanged', (tester) async {
    final appState = AppState(warmGoogleAccounts: false)
      ..setAppMode(AppMode.paye);
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

    expect(find.text('PAYE job - Quick Entry'), findsOneWidget);
    expect(find.text('Quick'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('work-monthly-overview-panel')),
      findsNothing,
    );
  });
}
