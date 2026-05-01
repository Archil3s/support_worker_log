import 'package:flutter/material.dart';

import '../charts/charts_screen.dart';
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

  static const pages = [
    ShellPage(
      title: 'Quick Entry',
      label: 'Quick',
      icon: Icons.flash_on_outlined,
      selectedIcon: Icons.flash_on,
      screen: QuickEntryScreen(),
    ),
    ShellPage(
      title: 'Pay Period',
      label: 'Pay',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      screen: PayPeriodScreen(),
    ),
    ShellPage(
      title: 'Entries',
      label: 'Entries',
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt,
      screen: EntriesScreen(),
    ),
    ShellPage(
      title: 'Tax',
      label: 'Tax',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      screen: TaxScreen(),
    ),
    ShellPage(
      title: 'Charts',
      label: 'Charts',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      screen: ChartsScreen(),
    ),
    ShellPage(
      title: 'Settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      screen: SettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = pages[selectedIndex];

    return Scaffold(
      appBar: AppBar(title: Text(page.title), centerTitle: false),
      body: SafeArea(child: page.screen),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
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
