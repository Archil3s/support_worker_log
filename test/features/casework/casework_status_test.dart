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
      final completedButton = find.byKey(
        const ValueKey('casework-walkIn-completed'),
      );
      for (
        var index = 0;
        index < 8 && completedButton.evaluate().isEmpty;
        index++
      ) {
        await tester.drag(list, const Offset(0, -350));
        await tester.pumpAndSettle();
      }
      await Scrollable.ensureVisible(
        tester.element(completedButton.at(0)),
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

    expect(
      find.byTooltip('Mark Main Issue/s in progress'),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.byTooltip('Clear Main Issue/s completed'),
      findsAtLeastNWidgets(1),
    );

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('casework_code_profiles_v1')!)
            as Map<String, dynamic>;
    final profiles = stored['profiles'] as Map<String, dynamic>;
    final caseData =
        (profiles['CASE-001'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;

    expect(caseData['updatedFocuses'], isNot(contains('walkIn')));
    expect(caseData['completedFocuses'], contains('walkIn'));
    expect(
      caseData['updatedAtByFocus'] as Map<String, dynamic>,
      isNot(contains('walkIn')),
    );
    expect(
      caseData['completedAtByFocus'] as Map<String, dynamic>,
      contains('walkIn'),
    );
    expect(
      find.byKey(const ValueKey('casework-walkIn-date-stamp')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpCasework();

    expect(
      find.byTooltip('Mark Main Issue/s in progress'),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.byTooltip('Clear Main Issue/s completed'),
      findsAtLeastNWidgets(1),
    );
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

    const sections = {
      'walkIn': 'Main Issue/s',
      'situation': 'Person Situation',
      'safety': 'Needs / situation',
      'documents': 'Evidence checklist',
      'msd': 'Emergency Housing',
      'housing': 'Social Housing Rating',
      'accommodation': 'Accommodation Options',
      'rentals': 'Rental search',
      'groceries': 'Grocery price check',
      'jobs': 'Work search',
      'probation': 'Probation / Bail Address',
      'referrals': 'Quick filters',
      'contacts': 'Contact record',
      'followUp': 'Follow-up plan',
      'file': 'Live Note Output',
    };

    for (final entry in sections.entries) {
      await tester.tap(find.byKey(ValueKey('casework-tab-${entry.key}')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('casework-${entry.key}-updated')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('casework-${entry.key}-completed')),
        findsOneWidget,
      );
      expect(find.byTooltip('Mark ${entry.value} in progress'), findsOneWidget);
      expect(find.byTooltip('Mark ${entry.value} completed'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Overflow while showing ${entry.key}',
      );
    }

    await tester.tap(find.byKey(const ValueKey('casework-tab-situation')));
    await tester.pumpAndSettle();
    final situationCompleted = find.byKey(
      const ValueKey('casework-situation-completed'),
    );
    await Scrollable.ensureVisible(
      tester.element(situationCompleted),
      alignment: 0.35,
    );
    await tester.pumpAndSettle();
    await tester.tap(situationCompleted);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mark Person Situation in progress'), findsOneWidget);
    expect(find.byTooltip('Clear Person Situation completed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('casework-situation-date-stamp')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('casework-tab-walkIn')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mark Main Issue/s completed'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('casework_code_profiles_v1')!)
            as Map<String, dynamic>;
    final profiles = stored['profiles'] as Map<String, dynamic>;
    final caseData =
        (profiles['CASE-001'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;

    expect(caseData['updatedFocuses'], isNot(contains('situation')));
    expect(caseData['completedFocuses'], contains('situation'));
    expect(caseData['completedFocuses'], isNot(contains('walkIn')));
    expect(
      caseData['completedAtByFocus'] as Map<String, dynamic>,
      contains('situation'),
    );

    await tester.tap(find.byKey(const ValueKey('casework-tab-contacts')));
    await tester.pumpAndSettle();
    expect(find.text('MSD / Work and Income contacted'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('casework-tab-followUp')));
    await tester.pumpAndSettle();
    expect(find.text('Next client check-in confirmed'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('casework-tab-file')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Progress / Completed Status'),
      findsAtLeastNWidgets(1),
    );
    expect(find.textContaining('Casework Checklist'), findsNothing);
    expect(find.textContaining('Next Actions'), findsNothing);
    expect(find.textContaining('Still To Check'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grocery price checks import and persist per case', (
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

    await tester.tap(find.byKey(const ValueKey('casework-tab-groceries')));
    await tester.pumpAndSettle();

    final importField = find.byWidgetPredicate((widget) {
      if (widget is! TextField) return false;
      return widget.decoration?.hintText?.contains('product, brand') ?? false;
    });
    expect(importField, findsOneWidget);

    await tester.enterText(
      importField,
      'Anchor Blue Milk 2L\n'
      'Woolworths Blenheim\n'
      '\$5.49\n'
      '\$2.75/L\n'
      'https://www.woolworths.co.nz/shop/productdetails/123',
    );
    await tester.pumpAndSettle();

    final extractButton = find.widgetWithText(FilledButton, 'Extract price');
    await Scrollable.ensureVisible(
      tester.element(extractButton),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(extractButton);
    await tester.pumpAndSettle();

    expect(find.text('Anchor Blue Milk 2L'), findsOneWidget);
    expect(find.text('Woolworths Blenheim'), findsWidgets);
    expect(find.text('Milk'), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('casework_code_profiles_v1')!)
            as Map<String, dynamic>;
    final profiles = stored['profiles'] as Map<String, dynamic>;
    final caseData =
        (profiles['CASE-001'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final groceryLeads = caseData['groceryLeads'] as List<dynamic>;
    final savedLead = groceryLeads.single as Map<String, dynamic>;

    expect(savedLead['product'], 'Anchor Blue Milk 2L');
    expect(savedLead['store'], 'Woolworths Blenheim');
    expect(savedLead['price'], '\$5.49');
    expect(savedLead['unitPrice'], '\$2.75/L');
    expect(savedLead['category'], 'Milk');
    expect(tester.takeException(), isNull);
  });

  testWidgets('main issue selections show checkbox state and stamp progress', (
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

    expect(find.text('Main Issue/s'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsWidgets);

    await tester.tap(find.text('No safe place tonight').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_box_rounded), findsWidgets);
    await tester.tap(
      find.byTooltip('Set No safe place tonight in progress').first,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byTooltip('Set No safe place tonight completed').first,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Progress / Completed Status'),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.textContaining('Walk-in: No safe place tonight | Completed'),
      findsAtLeastNWidgets(1),
    );
    expect(find.textContaining('Casework Checklist'), findsNothing);
    expect(find.textContaining('Still To Check'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('casework_code_profiles_v1')!)
            as Map<String, dynamic>;
    final profiles = stored['profiles'] as Map<String, dynamic>;
    final caseData =
        (profiles['CASE-001'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;

    expect(caseData['presentingNeeds'], contains('No safe place tonight'));
    expect(caseData['updatedFocuses'], isNot(contains('walkIn')));
    expect(caseData['completedFocuses'], isNot(contains('walkIn')));
    expect(
      caseData['itemCompletedAt'] as Map<String, dynamic>,
      contains('walkIn::No safe place tonight'),
    );
    expect(
      caseData['itemInProgressAt'] as Map<String, dynamic>,
      isNot(contains('walkIn::No safe place tonight')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('situation scope checkbox selections persist', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(body: CaseworkScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('casework-tab-situation')));
    await tester.pumpAndSettle();

    expect(find.text('Housing Position'), findsOneWidget);
    expect(find.text('Main Trigger'), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);

    const selectedScope = 'Can stay one night only';
    final selectedScopeFinder = find.text(selectedScope);
    await Scrollable.ensureVisible(
      tester.element(selectedScopeFinder),
      alignment: 0.4,
    );
    await tester.pumpAndSettle();
    await tester.tap(selectedScopeFinder);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('casework_code_profiles_v1')!)
            as Map<String, dynamic>;
    final profiles = stored['profiles'] as Map<String, dynamic>;
    final caseData =
        (profiles['CASE-001'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;

    expect(caseData['situationUnderstanding'], contains(selectedScope));
    expect(caseData['updatedFocuses'], isNot(contains('situation')));
    expect(find.text('Set: 1'), findsAtLeastNWidgets(1));
    expect(
      tester.takeException(),
      isNull,
      reason: 'Overflow after selecting situation scope',
    );
  });

  testWidgets('outcome fields and phrase chips feed the live note', (
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

    final requestedField = find.byKey(
      const ValueKey('casework-outcome-walkIn-requested'),
    );
    await Scrollable.ensureVisible(
      tester.element(requestedField),
      alignment: 0.45,
    );
    await tester.pumpAndSettle();
    await tester.enterText(requestedField, 'Emergency housing assessment');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('casework-outcome-walkIn-outcome')),
      'Assessment booked',
    );
    await tester.pumpAndSettle();
    final phraseChip = find.byKey(
      const ValueKey('casework-phrase-Worker supported with'),
    );
    await Scrollable.ensureVisible(tester.element(phraseChip), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(phraseChip);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Section Outcomes / Next Steps'),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.textContaining('Walk-in | Requested: Emergency housing assessment'),
      findsAtLeastNWidgets(1),
    );
    expect(find.textContaining('Outcome: Assessment booked'), findsWidgets);
    expect(find.textContaining('Worker supported with'), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('casework_code_profiles_v1')!)
            as Map<String, dynamic>;
    final profiles = stored['profiles'] as Map<String, dynamic>;
    final caseData =
        (profiles['CASE-001'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final outcomes = caseData['sectionOutcomes'] as Map<String, dynamic>;

    expect(outcomes['walkIn::requested'], 'Emergency housing assessment');
    expect(outcomes['walkIn::outcome'], 'Assessment booked');
    expect(caseData['additionalContext'], contains('Worker supported with'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('msd language guide shows avoid and use instead wording', (
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

    final msdTab = find.byKey(const ValueKey('casework-tab-msd'));
    await tester.tap(msdTab);
    await tester.pumpAndSettle();

    expect(find.text('What MSD needs to grant EH'), findsOneWidget);
    expect(
      find.text('EH grant requirements to cover with MSD'),
      findsOneWidget,
    );
    expect(find.text('Required item'), findsWidgets);
    expect(find.text('How to explain'), findsWidgets);
    expect(find.text('Do not say'), findsWidgets);
    expect(
      find.text(
        'Immediate need: no safe place tonight or for the next few nights.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'State where the person slept last night, where they can safely sleep tonight, and what risk exists if EH is not granted today.',
      ),
      findsOneWidget,
    );

    await Scrollable.ensureVisible(
      tester.element(find.text('MSD language to avoid')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();

    expect(find.text('MSD language to avoid'), findsOneWidget);
    expect(find.text('Avoid'), findsWidgets);
    expect(find.text('Use instead'), findsWidgets);
    expect(find.text('Client refuses emergency housing.'), findsOneWidget);
    expect(
      find.text(
        'Client has said the option is not safe or suitable because...',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('social support assessment feeds matching services', (
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

    await tester.tap(find.byKey(const ValueKey('casework-tab-safety')));
    await tester.pumpAndSettle();

    expect(find.text('Essentials + Access'), findsOneWidget);
    expect(find.text('Health + Wellbeing'), findsOneWidget);
    expect(find.text('Whanau + Relationships'), findsOneWidget);
    expect(find.text('Money + Legal + Learning'), findsOneWidget);
    expect(find.text('Culture + Community'), findsOneWidget);
    expect(find.text('Housing + Daily Living'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'Overflow in support assessment',
    );

    final mentalHealth = find.text('Mental health or counselling support');
    await Scrollable.ensureVisible(
      tester.element(mentalHealth),
      alignment: 0.4,
    );
    await tester.pumpAndSettle();
    await tester.tap(mentalHealth);
    await tester.pumpAndSettle();

    expect(find.text('Needs selected: 1'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'Overflow after selecting a support need',
    );

    final findServices = find.widgetWithText(
      FilledButton,
      'Find matching services',
    );
    await Scrollable.ensureVisible(
      tester.element(findServices),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(findServices);
    await tester.pumpAndSettle();

    expect(find.text('Programmes + Referrals'), findsOneWidget);
    expect(find.textContaining('services shown'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'Overflow in matching services',
    );

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('casework_code_profiles_v1')!)
            as Map<String, dynamic>;
    final profiles = stored['profiles'] as Map<String, dynamic>;
    final caseData =
        (profiles['CASE-001'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;

    expect(
      caseData['supportNeeds'],
      contains('Mental health or counselling support'),
    );
    expect(
      caseData['referralFilters'],
      contains('Mental health or counselling support'),
    );
  });
}
