import 'package:flutter/material.dart';

import '../../shared/widgets/feature_placeholder.dart';

class TaxScreen extends StatelessWidget {
  const TaxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.receipt_long,
      title: 'Tax',
      description: 'Pay-period tax and deduction estimate.',
      bullets: [
        'Gross income',
        'ACC levy',
        'Optional KiwiSaver',
        'GST and net take-home estimate',
      ],
    );
  }
}
