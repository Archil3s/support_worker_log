import 'package:flutter/material.dart';

class WizardNavButtons extends StatelessWidget {
  const WizardNavButtons({
    super.key,
    required this.canGoBack,
    required this.isLastStep,
    required this.onBack,
    required this.onNext,
    required this.onSave,
  });

  final bool canGoBack;
  final bool isLastStep;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canGoBack ? onBack : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Back'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: isLastStep ? onSave : onNext,
            icon: Icon(isLastStep ? Icons.save_outlined : Icons.chevron_right),
            label: Text(isLastStep ? 'Save' : 'Next'),
          ),
        ),
      ],
    );
  }
}
