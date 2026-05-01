import 'package:flutter/material.dart';

import '../../shared/widgets/feature_placeholder.dart';

class ChartsScreen extends StatelessWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.bar_chart,
      title: 'Charts',
      description: 'Stats overview for work activity.',
      bullets: [
        'Total entries',
        'Total hours and earnings',
        'Total kilometres',
        'Best day and average per visit',
      ],
    );
  }
}
