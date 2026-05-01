import 'package:flutter/material.dart';

import 'stat_card.dart';

class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.cards});

  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: cards);
  }
}
