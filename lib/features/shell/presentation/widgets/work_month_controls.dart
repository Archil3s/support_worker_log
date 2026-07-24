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

        if (constraints.maxWidth < 620) {
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
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1527),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF294A7C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'BROWSE MONTHS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFAFC6F5),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              _MonthButton(
                key: const ValueKey('work-month-previous'),
                label: 'Previous',
                icon: Icons.chevron_left_rounded,
                onPressed: onPrevious,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
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
              ),
              _MonthButton(
                key: const ValueKey('work-month-next'),
                label: 'Next',
                icon: Icons.chevron_right_rounded,
                iconAfterLabel: true,
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconAfterLabel = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool iconAfterLabel;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 18);
    final labelWidget = Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
    );

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD8E6FF),
        disabledForegroundColor: const Color(0xFF6D7D98),
        side: const BorderSide(color: Color(0xFF355C9A)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(88, 36),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: iconAfterLabel
            ? [labelWidget, const SizedBox(width: 2), iconWidget]
            : [iconWidget, const SizedBox(width: 2), labelWidget],
      ),
    );
  }
}
