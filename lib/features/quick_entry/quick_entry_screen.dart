import 'package:flutter/material.dart';

import '../../shared/widgets/feature_placeholder.dart';

class QuickEntryScreen extends StatelessWidget {
  const QuickEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.flash_on,
      title: 'Quick Entry',
      description: 'Wizard flow for quickly logging support work.',
      bullets: [
        'Client selection',
        'Entry type selection',
        'Date and time with Now button',
        'Notes chips and live earnings preview',
      ],
    );
  }
}
