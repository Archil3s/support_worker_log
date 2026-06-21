import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    required this.onHome,
    required this.onAdmin,
    required this.onEntries,
    required this.onPay,
    required this.onTax,
    required this.onCharts,
    required this.onDrive,
    required this.onSettings,
    required this.showMoneyTools,
    super.key,
  });

  final VoidCallback onHome;
  final VoidCallback onAdmin;
  final VoidCallback onEntries;
  final VoidCallback onPay;
  final VoidCallback onTax;
  final VoidCallback onCharts;
  final VoidCallback onDrive;
  final VoidCallback onSettings;
  final bool showMoneyTools;

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
        if (showMoneyTools) ...[
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
        ],
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
