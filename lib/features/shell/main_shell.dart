import 'package:flutter/material.dart';

import '../charts/charts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../entries/entries_screen.dart';
import '../pay_period/pay_period_screen.dart';
import '../quick_entry/quick_entry_screen.dart';
import '../settings/settings_screen.dart';
import '../tax/tax_screen.dart';

enum _Section { quick, entries, pay, home, more, tax, charts, settings }

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
      case _Section.entries:
        return 1;
      case _Section.pay:
        return 2;
      case _Section.home:
        return 3;
      case _Section.more:
      case _Section.tax:
      case _Section.charts:
      case _Section.settings:
        return 4;
    }
  }

  String get title {
    switch (section) {
      case _Section.quick:
        return 'Quick Entry';
      case _Section.entries:
        return 'Entries';
      case _Section.pay:
        return 'Pay Period';
      case _Section.home:
        return 'Dashboard';
      case _Section.more:
        return 'More';
      case _Section.tax:
        return 'Tax';
      case _Section.charts:
        return 'Charts';
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
        _go(_Section.entries);
        break;
      case 2:
        _go(_Section.pay);
        break;
      case 3:
        _go(_Section.home);
        break;
      case 4:
        _go(_Section.more);
        break;
    }
  }

  Widget _screen() {
    switch (section) {
      case _Section.quick:
        return const QuickEntryScreen();
      case _Section.entries:
        return const EntriesScreen();
      case _Section.pay:
        return const PayPeriodScreen();
      case _Section.home:
        return DashboardScreen(
          onQuickEntry: () => _go(_Section.quick),
          onPayPeriod: () => _go(_Section.pay),
          onEntries: () => _go(_Section.entries),
        );
      case _Section.more:
        return _MoreScreen(
          onTax: () => _go(_Section.tax),
          onCharts: () => _go(_Section.charts),
          onSettings: () => _go(_Section.settings),
        );
      case _Section.tax:
        return const TaxScreen();
      case _Section.charts:
        return const ChartsScreen();
      case _Section.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: false, toolbarHeight: 56),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: RepaintBoundary(child: _screen()),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: _FastBottomNav(selectedIndex: navIndex, onTap: _onNavTap),
        ),
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
            icon: Icons.list_alt_outlined,
            selectedIcon: Icons.list_alt_rounded,
            label: 'Entries',
            onTap: onTap,
          ),
          _FastNavItem(
            index: 2,
            selectedIndex: selectedIndex,
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month_rounded,
            label: 'Pay',
            onTap: onTap,
          ),
          _FastNavItem(
            index: 3,
            selectedIndex: selectedIndex,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Home',
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
    required this.onTax,
    required this.onCharts,
    required this.onSettings,
  });

  final VoidCallback onTax;
  final VoidCallback onCharts;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _MoreTile(
          icon: Icons.receipt_long_outlined,
          title: 'Tax',
          subtitle: 'GST, ACC, KiwiSaver, and net estimate',
          onTap: onTax,
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.bar_chart_outlined,
          title: 'Charts',
          subtitle: 'Hours, earnings, KM, and support trends',
          onTap: onCharts,
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Clients, rates, notes, goals, and app data',
          onTap: onSettings,
        ),
      ],
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
