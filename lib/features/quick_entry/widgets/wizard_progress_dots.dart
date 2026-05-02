import 'package:flutter/material.dart';

class WizardProgressDots extends StatelessWidget {
  const WizardProgressDots({
    super.key,
    required this.currentIndex,
    required this.total,
  });

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < total; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == currentIndex ? 22 : 9,
            height: 9,
            decoration: BoxDecoration(
              color: index == currentIndex
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}
