import 'package:flutter/material.dart';

class WorkMonthControls extends StatelessWidget {
  const WorkMonthControls({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onCopy,
    required this.canGoNext,
    super.key,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCopy;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final navigator = _MonthNavigator(
          label: label,
          onPrevious: onPrevious,
          onNext: canGoNext ? onNext : null,
        );
        final copyButton = OutlinedButton.icon(
          key: const ValueKey('work-month-copy-totals'),
          onPressed: onCopy,
          icon: const Icon(Icons.copy_all_rounded, size: 18),
          label: const Text('Copy totals'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFD8E6FF),
            side: const BorderSide(color: Color(0xFF355C9A)),
            minimumSize: const Size(136, 42),
          ),
        );

        if (constraints.maxWidth < 390) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [navigator, const SizedBox(height: 8), copyButton],
          );
        }

        return Row(
          children: [
            Expanded(child: navigator),
            const SizedBox(width: 8),
            copyButton,
          ],
        );
      },
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1527),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF294A7C)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('work-month-previous'),
            onPressed: onPrevious,
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left_rounded),
            color: const Color(0xFF8CB8FF),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('work-month-next'),
            onPressed: onNext,
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right_rounded),
            color: const Color(0xFF8CB8FF),
            disabledColor: const Color(0xFF44546E),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
