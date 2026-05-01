import 'package:flutter/material.dart';

import '../../shared/widgets/feature_placeholder.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.settings,
      title: 'Settings',
      description: 'App configuration and data tools.',
      bullets: [
        'Hourly rate',
        'Fuel rate',
        'Client manager',
        'Export, import, print, and clear data',
      ],
    );
  }
}
