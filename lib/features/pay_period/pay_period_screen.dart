import 'package:flutter/material.dart';

import '../../shared/widgets/feature_placeholder.dart';

class PayPeriodScreen extends StatelessWidget {
  const PayPeriodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.calendar_month,
      title: 'Pay Period',
      description: 'Fortnightly totals and weekly breakdowns.',
      bullets: [
        'Pay period selector',
        'Hours and earnings totals',
        'Kilometre totals',
        'Tap date to pre-fill a new entry',
      ],
    );
  }
}
