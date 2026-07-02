import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_mode.dart';
import '../../core/models/google_export_account_scope.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/notes_storage_gate.dart';
import '../../shared/widgets/web_spacing.dart';
import '../admin_review/admin_review_screen.dart';
import '../calendar/calendar_screen.dart';
import '../charts/charts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../drive/drive_screen.dart';
import '../entries/entries_screen.dart';
import '../notes/actions_screen.dart';
import '../notes/notes_screen.dart';
import '../pay_period/pay_period_screen.dart';
import '../quick_entry/quick_entry_screen.dart';
import '../settings/settings_screen.dart';
import '../tax/tax_screen.dart';
import 'mode_screen_loader.dart';
import 'more_screen.dart';

enum _Section {
  quick,
  notes,
  actions,
  calendar,
  admin,
  charts,
  more,
  home,
  entries,
  pay,
  tax,
  drive,
  settings,
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  _Section section = _Section.quick;

  int get navIndex {
    switch (section) {
      case _Section.quick:
        return 0;
      case _Section.notes:
        return 1;
      case _Section.calendar:
        return 2;
      case _Section.actions:
        return 3;
      case _Section.admin:
      case _Section.charts:
        return 4;
      case _Section.more:
      case _Section.home:
      case _Section.entries:
      case _Section.pay:
      case _Section.tax:
      case _Section.drive:
      case _Section.settings:
        return 4;
    }
  }

  String get title {
    switch (section) {
      case _Section.quick:
        return 'Quick Entry';
      case _Section.notes:
        return 'Notes';
      case _Section.actions:
        return 'Actions';
      case _Section.calendar:
        return 'Calendar';
      case _Section.admin:
        return 'Admin Review';
      case _Section.charts:
        return 'Charts';
      case _Section.home:
        return 'Dashboard';
      case _Section.entries:
        return 'Entries';
      case _Section.pay:
        return 'Pay Period';
      case _Section.more:
        return 'More';
      case _Section.tax:
        return 'Tax';
      case _Section.drive:
        return 'Google Drive';
      case _Section.settings:
        return 'Settings';
    }
  }

  String _title(AppMode mode) {
    if (mode == AppMode.personal) return 'Personal Mode';
    if (mode == AppMode.massage) return 'Massage';
    if (mode == AppMode.mood) return 'Mood Tracker';
    if (mode == AppMode.cleaning) return 'House Cleaning';
    if (mode == AppMode.grocery) return 'Grocery Prices';
    if (mode == AppMode.casework) return 'Casework';
    if (mode == AppMode.paye) return 'PAYE job - $title';

    return title;
  }

  IconData _modeIcon(AppMode mode) {
    switch (mode) {
      case AppMode.personal:
        return Icons.person_outline_rounded;
      case AppMode.massage:
        return Icons.spa_outlined;
      case AppMode.mood:
        return Icons.monitor_heart_outlined;
      case AppMode.cleaning:
        return Icons.cleaning_services_outlined;
      case AppMode.grocery:
        return Icons.local_grocery_store_outlined;
      case AppMode.casework:
        return Icons.home_work_outlined;
      case AppMode.paye:
        return Icons.business_center_outlined;
      case AppMode.work:
        return Icons.work_outline_rounded;
    }
  }

  GoogleExportAccountScope _driveScope(AppMode mode) {
    return switch (mode) {
      AppMode.personal ||
      AppMode.massage ||
      AppMode.mood ||
      AppMode.cleaning ||
      AppMode.grocery => GoogleExportAccountScope.personal,
      AppMode.paye => GoogleExportAccountScope.paye,
      AppMode.work || AppMode.casework => GoogleExportAccountScope.work,
    };
  }

  void _go(_Section next) {
    if (section == next) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => section = next);
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        _go(_Section.quick);
        break;
      case 1:
        _go(_Section.notes);
        break;
      case 2:
        _go(_Section.calendar);
        break;
      case 3:
        _go(_Section.actions);
        break;
      case 4:
        _go(_Section.more);
        break;
    }
  }

  void _onRailTap(int index, AppMode mode) {
    final sections = _railSections(mode);
    if (index < 0 || index >= sections.length) return;
    _go(sections[index]);
  }

  List<_Section> _railSections(AppMode mode) {
    return [
      _Section.quick,
      _Section.notes,
      _Section.actions,
      _Section.calendar,
      _Section.entries,
      if (mode != AppMode.paye) _Section.pay,
      _Section.drive,
      _Section.more,
    ];
  }

  int _railIndex(AppMode mode) {
    final sections = _railSections(mode);
    final index = sections.indexOf(section);
    if (index != -1) return index;
    return sections.indexOf(_Section.more);
  }

  Widget _screen(AppMode appMode) {
    switch (section) {
      case _Section.quick:
        return QuickEntryScreen(onCalendar: () => _go(_Section.calendar));
      case _Section.notes:
        return const NotesScreen();
      case _Section.actions:
        return const ActionsScreen();
      case _Section.calendar:
        return const CalendarScreen();
      case _Section.admin:
        return AdminReviewScreen(
          onEntries: () => _go(_Section.entries),
          onCalendar: () => _go(_Section.calendar),
          onDrive: () => _go(_Section.drive),
          onQuickEntry: () => _go(_Section.quick),
        );
      case _Section.charts:
        return const ChartsScreen();
      case _Section.home:
        return DashboardScreen(
          onQuickEntry: () => _go(_Section.quick),
          onPayPeriod: () {
            if (appMode != AppMode.paye) _go(_Section.pay);
          },
          onEntries: () => _go(_Section.entries),
          onAdminReview: () => _go(_Section.admin),
        );
      case _Section.entries:
        return const EntriesScreen();
      case _Section.pay:
        return const PayPeriodScreen();
      case _Section.more:
        return MoreScreen(
          onHome: () => _go(_Section.home),
          onAdmin: () => _go(_Section.admin),
          onEntries: () => _go(_Section.entries),
          onPay: () => _go(_Section.pay),
          onTax: () => _go(_Section.tax),
          onCharts: () => _go(_Section.charts),
          onDrive: () => _go(_Section.drive),
          onSettings: () => _go(_Section.settings),
          showMoneyTools: appMode != AppMode.paye,
        );
      case _Section.tax:
        return const TaxScreen();
      case _Section.drive:
        return const DriveScreen();
      case _Section.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.select<AppState, AppMode>((state) => state.appMode);
    final appState = context.read<AppState>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final tightWeb = useTightWebSpacing(context);
        final maxContentWidth = wide ? (tightWeb ? 1180.0 : 980.0) : 430.0;
        final personalMode = appMode == AppMode.personal;
        final massageMode = appMode == AppMode.massage;
        final moodMode = appMode == AppMode.mood;
        final cleaningMode = appMode == AppMode.cleaning;
        final groceryMode = appMode == AppMode.grocery;
        final caseworkMode = appMode == AppMode.casework;
        final standaloneMode =
            personalMode ||
            massageMode ||
            moodMode ||
            cleaningMode ||
            groceryMode ||
            caseworkMode;
        final contentWidth = caseworkMode && wide
            ? 1680.0
            : groceryMode && wide
            ? 1240.0
            : maxContentWidth;
        final showFlowStrip = wide && !standaloneMode;

        return Scaffold(
          appBar: AppBar(
            title: Text(_title(appMode)),
            centerTitle: false,
            toolbarHeight: tightWeb ? 54 : (wide ? 64 : 56),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: tightWeb ? 6 : 8),
                child: PopupMenuButton<AppMode>(
                  tooltip: 'App mode',
                  initialValue: appMode,
                  onSelected: (mode) {
                    appState.setAppMode(mode);
                    if (mode == AppMode.paye &&
                        (section == _Section.pay || section == _Section.tax)) {
                      setState(() => section = _Section.quick);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: AppMode.work,
                      child: ListTile(
                        leading: Icon(Icons.work_outline_rounded),
                        title: Text('Work Mode'),
                      ),
                    ),
                    PopupMenuItem(
                      value: AppMode.personal,
                      child: ListTile(
                        leading: Icon(Icons.person_outline_rounded),
                        title: Text('Personal Mode'),
                      ),
                    ),
                    PopupMenuItem(
                      value: AppMode.massage,
                      child: ListTile(
                        leading: Icon(Icons.spa_outlined),
                        title: Text('Massage'),
                      ),
                    ),
                    PopupMenuItem(
                      value: AppMode.mood,
                      child: ListTile(
                        leading: Icon(Icons.monitor_heart_outlined),
                        title: Text('Mood Tracker'),
                      ),
                    ),
                    PopupMenuItem(
                      value: AppMode.cleaning,
                      child: ListTile(
                        leading: Icon(Icons.cleaning_services_outlined),
                        title: Text('House Cleaning'),
                      ),
                    ),
                    PopupMenuItem(
                      value: AppMode.grocery,
                      child: ListTile(
                        leading: Icon(Icons.local_grocery_store_outlined),
                        title: Text('Grocery Prices'),
                      ),
                    ),
                    PopupMenuItem(
                      value: AppMode.casework,
                      child: ListTile(
                        leading: Icon(Icons.home_work_outlined),
                        title: Text('Casework'),
                      ),
                    ),
                    PopupMenuItem(
                      value: AppMode.paye,
                      child: ListTile(
                        leading: Icon(Icons.business_center_outlined),
                        title: Text('PAYE job'),
                      ),
                    ),
                  ],
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: tightWeb ? 10 : 12,
                      vertical: tightWeb ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151B29),
                      borderRadius: BorderRadius.circular(tightWeb ? 12 : 16),
                      border: Border.all(color: const Color(0xFF34405F)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _modeIcon(appMode),
                          size: tightWeb ? 18 : 20,
                          color: const Color(0xFF4F8DF7),
                        ),
                        SizedBox(width: tightWeb ? 6 : 8),
                        Text(
                          appMode.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (wide && !standaloneMode)
                  _SideRail(
                    sections: _railSections(appMode),
                    selectedIndex: _railIndex(appMode),
                    onTap: (index) => _onRailTap(index, appMode),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Column(
                        children: [
                          if (showFlowStrip)
                            _WorkflowStrip(
                              key: const ValueKey('desktop-workflow-strip'),
                              selected: section,
                              onSelected: _go,
                              showPay: appMode != AppMode.paye,
                            ),
                          Expanded(
                            child: NotesStorageGate(
                              scope: _driveScope(appMode),
                              child: RepaintBoundary(
                                child: standaloneMode
                                    ? ModeScreenLoader(
                                        key: ValueKey(appMode),
                                        mode: appMode,
                                      )
                                    : _screen(appMode),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide || standaloneMode
              ? null
              : _KeyboardAwareBottomNav(
                  selectedIndex: navIndex,
                  onTap: _onNavTap,
                ),
        );
      },
    );
  }
}

class _WorkflowStrip extends StatelessWidget {
  const _WorkflowStrip({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.showPay,
  });

  final _Section selected;
  final ValueChanged<_Section> onSelected;
  final bool showPay;

  List<_Section> get sections {
    return [
      _Section.quick,
      _Section.notes,
      _Section.actions,
      _Section.calendar,
      _Section.entries,
      if (showPay) _Section.pay,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tight = useTightWebSpacing(context);
    final items = sections;
    final selectedIndex = items.indexOf(selected);
    final previous = selectedIndex > 0 ? items[selectedIndex - 1] : null;
    final next = selectedIndex >= 0 && selectedIndex < items.length - 1
        ? items[selectedIndex + 1]
        : null;
    final stepWidgets = <Widget>[];

    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      stepWidgets.add(
        Expanded(
          child: _WorkflowStep(
            section: item,
            selected: selected == item,
            completed: selectedIndex > index,
            onTap: () => onSelected(item),
          ),
        ),
      );

      if (index < items.length - 1) {
        stepWidgets.add(
          _WorkflowConnector(active: selectedIndex > index, compact: tight),
        );
      }
    }

    return Container(
      height: tight ? 50 : 58,
      margin: EdgeInsets.fromLTRB(8, tight ? 4 : 8, 8, tight ? 6 : 8),
      padding: EdgeInsets.all(tight ? 4 : 6),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(tight ? 14 : 18),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Row(
        children: [
          if (previous != null) ...[
            _WorkflowJumpButton(
              key: const ValueKey('workflow-previous'),
              section: previous,
              forward: false,
              onTap: () => onSelected(previous),
            ),
            SizedBox(width: tight ? 4 : 6),
          ],
          Expanded(child: Row(children: stepWidgets)),
          if (next != null) ...[
            SizedBox(width: tight ? 4 : 6),
            _WorkflowJumpButton(
              key: const ValueKey('workflow-next'),
              section: next,
              forward: true,
              onTap: () => onSelected(next),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkflowJumpButton extends StatelessWidget {
  const _WorkflowJumpButton({
    super.key,
    required this.section,
    required this.forward,
    required this.onTap,
  });

  final _Section section;
  final bool forward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tight = useTightWebSpacing(context);
    final label = _workflowLabel(section);

    return Tooltip(
      message: '${forward ? 'Next' : 'Back'}: ${_workflowTooltip(section)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(tight ? 10 : 12),
        onTap: onTap,
        child: Container(
          width: tight ? 96 : 124,
          height: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: tight ? 8 : 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1422),
            borderRadius: BorderRadius.circular(tight ? 10 : 12),
            border: Border.all(color: const Color(0xFF34405F)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!forward) ...[
                Icon(
                  Icons.chevron_left_rounded,
                  color: const Color(0xFFB8C7F3),
                  size: tight ? 18 : 20,
                ),
                SizedBox(width: tight ? 2 : 4),
              ],
              Flexible(
                child: Text(
                  forward ? 'Next $label' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFE7EEFF),
                    fontSize: tight ? 11 : 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (forward) ...[
                SizedBox(width: tight ? 2 : 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFFB8C7F3),
                  size: tight ? 18 : 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowConnector extends StatelessWidget {
  const _WorkflowConnector({required this.active, required this.compact});

  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: compact ? 10 : 14,
      height: 2,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4F8DF7) : const Color(0xFF34405F),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.section,
    required this.selected,
    required this.completed,
    required this.onTap,
  });

  final _Section section;
  final bool selected;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tight = useTightWebSpacing(context);

    return Tooltip(
      message: _workflowTooltip(section),
      child: InkWell(
        key: ValueKey('workflow-step-${section.name}'),
        borderRadius: BorderRadius.circular(tight ? 10 : 13),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.symmetric(horizontal: tight ? 8 : 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF13294D) : Colors.transparent,
            borderRadius: BorderRadius.circular(tight ? 10 : 13),
            border: Border.all(
              color: selected ? const Color(0xFF4F8DF7) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _workflowIcon(section, selected),
                color: selected || completed
                    ? const Color(0xFF4F8DF7)
                    : const Color(0xFF8396C7),
                size: tight ? 18 : 20,
              ),
              SizedBox(width: tight ? 6 : 8),
              Flexible(
                child: Text(
                  _workflowLabel(section),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFB8C7F3),
                    fontSize: tight ? 12 : 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyboardAwareBottomNav extends StatelessWidget {
  const _KeyboardAwareBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardBottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: _FastBottomNav(selectedIndex: selectedIndex, onTap: onTap),
        ),
      ),
    );
  }
}

IconData _workflowIcon(_Section section, bool selected) {
  switch (section) {
    case _Section.quick:
      return selected ? Icons.bolt_rounded : Icons.bolt_outlined;
    case _Section.notes:
      return selected ? Icons.note_alt_rounded : Icons.note_alt_outlined;
    case _Section.actions:
      return selected
          ? Icons.checklist_rtl_rounded
          : Icons.checklist_rtl_outlined;
    case _Section.calendar:
      return selected
          ? Icons.calendar_month_rounded
          : Icons.calendar_month_outlined;
    case _Section.entries:
      return selected ? Icons.list_alt_rounded : Icons.list_alt_outlined;
    case _Section.pay:
      return selected
          ? Icons.receipt_long_rounded
          : Icons.receipt_long_outlined;
    case _Section.admin:
    case _Section.charts:
    case _Section.more:
    case _Section.home:
    case _Section.tax:
    case _Section.drive:
    case _Section.settings:
      return selected ? Icons.more_horiz_rounded : Icons.more_horiz_outlined;
  }
}

String _workflowLabel(_Section section) {
  switch (section) {
    case _Section.quick:
      return 'Start';
    case _Section.notes:
      return 'Notes';
    case _Section.actions:
      return 'Actions';
    case _Section.calendar:
      return 'Calendar';
    case _Section.entries:
      return 'Entries';
    case _Section.pay:
      return 'Pay';
    case _Section.admin:
    case _Section.charts:
    case _Section.more:
    case _Section.home:
    case _Section.tax:
    case _Section.drive:
    case _Section.settings:
      return 'More';
  }
}

String _workflowTooltip(_Section section) {
  switch (section) {
    case _Section.quick:
      return 'Quick Entry';
    case _Section.notes:
      return 'Notes';
    case _Section.actions:
      return 'Actions';
    case _Section.calendar:
      return 'Calendar';
    case _Section.entries:
      return 'Entries';
    case _Section.pay:
      return 'Pay Period';
    case _Section.admin:
      return 'Admin Review';
    case _Section.charts:
      return 'Charts';
    case _Section.more:
      return 'More';
    case _Section.home:
      return 'Dashboard';
    case _Section.tax:
      return 'Tax';
    case _Section.drive:
      return 'Google Drive';
    case _Section.settings:
      return 'Settings';
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.sections,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_Section> sections;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tight = useTightWebSpacing(context);

    return Container(
      width: tight ? 82 : 94,
      margin: EdgeInsets.fromLTRB(tight ? 8 : 12, tight ? 6 : 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(tight ? 14 : 18),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        selectedIndex: selectedIndex,
        onDestinationSelected: onTap,
        minWidth: tight ? 82 : 94,
        labelType: NavigationRailLabelType.all,
        groupAlignment: tight ? -0.94 : -0.88,
        selectedIconTheme: const IconThemeData(color: Color(0xFF4F8DF7)),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF8396C7)),
        selectedLabelTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Color(0xFF8396C7),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        destinations: [
          for (final section in sections) _railDestination(section),
        ],
      ),
    );
  }

  NavigationRailDestination _railDestination(_Section section) {
    switch (section) {
      case _Section.actions:
        return const NavigationRailDestination(
          icon: Icon(Icons.checklist_rtl_outlined),
          selectedIcon: Icon(Icons.checklist_rtl_rounded),
          label: Text('Actions'),
        );
      case _Section.quick:
        return const NavigationRailDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt_rounded),
          label: Text('Quick'),
        );
      case _Section.notes:
        return const NavigationRailDestination(
          icon: Icon(Icons.note_alt_outlined),
          selectedIcon: Icon(Icons.note_alt_rounded),
          label: Text('Notes'),
        );
      case _Section.calendar:
        return const NavigationRailDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: Text('Calendar'),
        );
      case _Section.entries:
        return const NavigationRailDestination(
          icon: Icon(Icons.list_alt_outlined),
          selectedIcon: Icon(Icons.list_alt_rounded),
          label: Text('Entries'),
        );
      case _Section.pay:
        return const NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: Text('Pay'),
        );
      case _Section.drive:
        return const NavigationRailDestination(
          icon: Icon(Icons.add_to_drive_outlined),
          selectedIcon: Icon(Icons.add_to_drive),
          label: Text('Drive'),
        );
      case _Section.admin:
      case _Section.more:
      case _Section.home:
      case _Section.charts:
      case _Section.tax:
      case _Section.settings:
        return const NavigationRailDestination(
          icon: Icon(Icons.more_horiz_outlined),
          selectedIcon: Icon(Icons.more_horiz_rounded),
          label: Text('More'),
        );
    }
  }
}

class _FastBottomNav extends StatelessWidget {
  const _FastBottomNav({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: Row(
        children: [
          _FastNavItem(
            index: 0,
            selectedIndex: selectedIndex,
            icon: Icons.bolt_outlined,
            selectedIcon: Icons.bolt_rounded,
            label: 'Quick',
            onTap: onTap,
          ),
          _FastNavItem(
            index: 1,
            selectedIndex: selectedIndex,
            icon: Icons.note_alt_outlined,
            selectedIcon: Icons.note_alt_rounded,
            label: 'Notes',
            onTap: onTap,
          ),
          _FastNavItem(
            index: 2,
            selectedIndex: selectedIndex,
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month_rounded,
            label: 'Calendar',
            onTap: onTap,
          ),
          _FastNavItem(
            index: 3,
            selectedIndex: selectedIndex,
            icon: Icons.checklist_rtl_outlined,
            selectedIcon: Icons.checklist_rtl_rounded,
            label: 'Actions',
            onTap: onTap,
          ),
          _FastNavItem(
            index: 4,
            selectedIndex: selectedIndex,
            icon: Icons.more_horiz_outlined,
            selectedIcon: Icons.more_horiz_rounded,
            label: 'More',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _FastNavItem extends StatelessWidget {
  const _FastNavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF13294D) : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                color: selected
                    ? const Color(0xFF4F8DF7)
                    : const Color(0xFF8396C7),
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF8396C7),
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
