import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/features/casework/casework_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('casework status icons persist per case on iPhone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pumpCasework() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const Scaffold(body: CaseworkScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('casework-compact-list')).at(0);
      for (var index = 0; index < 3; index++) {
        await tester.drag(list, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      final completedButton = find
          .byKey(const ValueKey('casework-walkIn-completed'))
          .at(0);
      await Scrollable.ensureVisible(
        tester.element(completedButton),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
    }

    await pumpCasework();

    final updatedButton = find
        .byKey(const ValueKey('casework-walkIn-updated'))
        .at(0);
    final completedButton = find
        .byKey(const ValueKey('casework-walkIn-completed'))
        .at(0);
    expect(updatedButton, findsOneWidget);
    expect(completedButton, findsOneWidget);

    await tester.tap(completedButton);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clear Walk-in updated'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('Clear Walk-in completed'), findsAtLeastNWidgets(1));

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('casework_code_profiles_v1')!)
            as Map<String, dynamic>;
    final profiles = stored['profiles'] as Map<String, dynamic>;
    final caseData =
        (profiles['CASE-001'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;

    expect(caseData['updatedFocuses'], contains('walkIn'));
    expect(caseData['completedFocuses'], contains('walkIn'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpCasework();

    expect(find.byTooltip('Clear Walk-in updated'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('Clear Walk-in completed'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every desktop section has independent status controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(body: CaseworkScreen()),
      ),
    );
    await tester.pumpAndSettle();

    const sections = [
      'walkIn',
      'situation',
      'safety',
      'documents',
      'msd',
      'housing',
      'accommodation',
      'probation',
      'referrals',
      'file',
    ];

    for (final section in sections) {
      expect(find.byKey(ValueKey('casework-$section-updated')), findsOneWidget);
      expect(
        find.byKey(ValueKey('casework-$section-completed')),
        findsOneWidget,
      );
    }

    await tester.tap(
      find.byKey(const ValueKey('casework-situation-completed')),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clear Situation updated'), findsOneWidget);
    expect(find.byTooltip('Clear Situation completed'), findsOneWidget);
    expect(find.byTooltip('Mark Walk-in completed'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('casework_code_profiles_v1')!)
            as Map<String, dynamic>;
    final profiles = stored['profiles'] as Map<String, dynamic>;
    final caseData =
        (profiles['CASE-001'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;

    expect(caseData['updatedFocuses'], contains('situation'));
    expect(caseData['completedFocuses'], contains('situation'));
    expect(caseData['completedFocuses'], isNot(contains('walkIn')));
    expect(tester.takeException(), isNull);
  });
}
