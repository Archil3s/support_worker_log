import 'package:flutter/material.dart';

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
  _Section section = _Section.actions;

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

  void _go(_Section next) {
    if (section == next) return;
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

  void _onRailTap(int index) {
    switch (index) {
      case 0:
        _go(_Section.actions);
        break;
      case 1:
        _go(_Section.quick);
        break;
      case 2:
        _go(_Section.notes);
        break;
      case 3:
        _go(_Section.calendar);
        break;
      case 4:
        _go(_Section.entries);
        break;
      case 5:
        _go(_Section.pay);
        break;
      case 6:
        _go(_Section.drive);
        break;
      case 7:
        _go(_Section.more);
        break;
    }
  }

  int get railIndex {
    switch (section) {
      case _Section.actions:
        return 0;
      case _Section.quick:
        return 1;
      case _Section.notes:
        return 2;
      case _Section.calendar:
        return 3;
      case _Section.entries:
        return 4;
      case _Section.pay:
        return 5;
      case _Section.drive:
        return 6;
      case _Section.admin:
      case _Section.more:
      case _Section.home:
      case _Section.charts:
      case _Section.tax:
      case _Section.settings:
        return 7;
    }
  }

  Widget _screen() {
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
          onPayPeriod: () => _go(_Section.pay),
          onEntries: () => _go(_Section.entries),
          onAdminReview: () => _go(_Section.admin),
        );
      case _Section.entries:
        return const EntriesScreen();
      case _Section.pay:
        return const PayPeriodScreen();
      case _Section.more:
        return _MoreScreen(
          onHome: () => _go(_Section.home),
          onAdmin: () => _go(_Section.admin),
          onEntries: () => _go(_Section.entries),
          onPay: () => _go(_Section.pay),
          onTax: () => _go(_Section.tax),
          onCharts: () => _go(_Section.charts),
          onDrive: () => _go(_Section.drive),
          onSettings: () => _go(_Section.settings),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final maxContentWidth = wide ? 980.0 : 430.0;

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            centerTitle: false,
            toolbarHeight: wide ? 64 : 56,
          ),
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (wide)
                  _SideRail(selectedIndex: railIndex, onTap: _onRailTap),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: RepaintBoundary(child: _screen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: _FastBottomNav(
                      selectedIndex: navIndex,
                      onTap: _onNavTap,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 94,
      margin: const EdgeInsets.fromLTRB(12, 8, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF34405F)),
      ),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        selectedIndex: selectedIndex,
        onDestinationSelected: onTap,
        minWidth: 94,
        labelType: NavigationRailLabelType.all,
        groupAlignment: -0.88,
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
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl_rounded),
            label: Text('Actions'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt_rounded),
            label: Text('Quick'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt_rounded),
            label: Text('Notes'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: Text('Calendar'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: Text('Entries'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: Text('Pay'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.add_to_drive_outlined),
            selectedIcon: Icon(Icons.add_to_drive),
            label: Text('Drive'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: Text('More'),
          ),
        ],
      ),
    );
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

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({
    required this.onHome,
    required this.onAdmin,
    required this.onEntries,
    required this.onPay,
    required this.onTax,
    required this.onCharts,
    required this.onDrive,
    required this.onSettings,
  });

  final VoidCallback onHome;
  final VoidCallback onAdmin;
  final VoidCallback onEntries;
  final VoidCallback onPay;
  final VoidCallback onTax;
  final VoidCallback onCharts;
  final VoidCallback onDrive;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _MoreTile(
          icon: Icons.dashboard_outlined,
          title: 'Dashboard',
          subtitle: 'Home overview, totals, and shortcuts',
          onTap: onHome,
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.fact_check_outlined,
          title: 'Admin Review',
          subtitle: 'Replies, calendar gaps, note detail, and next actions',
          onTap: onAdmin,
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.list_alt_outlined,
          title: 'Entries',
          subtitle: 'Search, import, edit, and export saved visits',
          onTap: onEntries,
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.receipt_long_outlined,
          title: 'Pay Period',
          subtitle: 'Invoices, owed money, PDF build, and breakdowns',
          onTap: onPay,
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Tax',
          subtitle: 'GST, ACC, KiwiSaver, and net estimate',
          onTap: onTax,
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.bar_chart_outlined,
          title: 'Charts',
          subtitle: 'Hours, earnings, calendar completion, and trends',
          onTap: onCharts,
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.add_to_drive_outlined,
          title: 'Google Drive',
          subtitle: 'Connect Drive, create folders, and upload templates',
          onTap: onDrive,
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Clients, rates, notes, goals, and app data',
          onTap: onSettings,
        ),
        const SizedBox(height: 12),
        const _BuildInfoTile(),
      ],
    );
  }
}

class _BuildInfoTile extends StatelessWidget {
  const _BuildInfoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102A1C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF31E981)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_outlined, color: Color(0xFF31E981)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Phone sync build 2026-06-01',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF151B29),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF34405F)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF13294D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF34405F)),
              ),
              child: Icon(icon, color: const Color(0xFF4F8DF7)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8396C7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8396C7)),
          ],
        ),
      ),
    );
  }
}
