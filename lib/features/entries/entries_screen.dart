import 'package:flutter/material.dart';

import '../../shared/widgets/feature_placeholder.dart';

class EntriesScreen extends StatelessWidget {
  const EntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.list_alt,
      title: 'Entries',
      description: 'Full list of logged entries.',
      bullets: [
        'Edit entry',
        'Delete with undo',
        'Duplicate entry',
        'Copy text summary',
      ],
    );
  }
}
