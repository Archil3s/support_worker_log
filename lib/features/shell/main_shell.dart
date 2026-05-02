import 'package:flutter/material.dart';

import '../charts/charts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../entries/entries_screen.dart';
import '../pay_period/pay_period_screen.dart';
import '../quick_entry/quick_entry_screen.dart';
import '../settings/settings_screen.dart';
import '../tax/tax_screen.dart';
import 'shell_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedIndex = 0;

  void _selectTab(int index) {
    setState(() => selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ShellPage(
        title: 'Dashboard',
        label: 'Home',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        screen: DashboardScreen(
          onQuickEntry: () => _selectTab(1),
          onPayPeriod: () => _selectTab(2),
          onEntries: () => _selectTab(3),
        ),
      ),
      const ShellPage(
        title: 'Quick Entry',
        label: 'Quick',
        icon: Icons.flash_on_outlined,
        selectedIcon: Icons.flash_on,
        screen: QuickEntryScreen(),
      ),
      const ShellPage(
        title: 'Pay Period',
        label: 'Pay',
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        screen: PayPeriodScreen(),
      ),
      const ShellPage(
        title: 'Entries',
        label: 'Entries',
        icon: Icons.list_alt_outlined,
        selectedIcon: Icons.list_alt,
        screen: EntriesScreen(),
      ),
      const ShellPage(
        title: 'Tax',
        label: 'Tax',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        screen: TaxScreen(),
      ),
      const ShellPage(
        title: 'Charts',
        label: 'Charts',
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        screen: ChartsScreen(),
      ),
      const ShellPage(
        title: 'Settings',
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        screen: SettingsScreen(),
      ),
    ];

    final page = pages[selectedIndex];

    return Scaffold(
      appBar: AppBar(title: Text(page.title), centerTitle: false),
      body: SafeArea(child: page.screen),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          for (final page in pages)
            NavigationDestination(
              icon: Icon(page.icon),
              selectedIcon: Icon(page.selectedIcon),
              label: page.label,
            ),
        ],
      ),
    );
  }
}
