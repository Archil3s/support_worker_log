import 'package:flutter/material.dart';

const _supportNoteHeadings = {
  'attendance',
  'what happened',
  'work/task completed',
  'support given',
  'issue/problem',
  'outcome',
  'next step',
  'anything to follow up',
  'referrals',
  'main topic(s)',
  'outcome(s)',
  'next action(s)',
  'overall impression',
  'local referral tracking',
  'safety concerns',
  'safety concerns for sexual harm survivors and mental health',
};

class SupportNoteBreakdownText extends StatelessWidget {
  const SupportNoteBreakdownText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ?? DefaultTextStyle.of(context).style.copyWith(height: 1.35);

    return SelectableText.rich(
      TextSpan(style: baseStyle, children: _spans(baseStyle)),
    );
  }

  List<TextSpan> _spans(TextStyle baseStyle) {
    final lines = _normalizedLines();
    final spans = <TextSpan>[];

    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final isHeading = _supportNoteHeadings.contains(_normalize(line));
      spans.add(
        TextSpan(
          text: index == lines.length - 1 ? line : '$line\n',
          style: isHeading
              ? baseStyle.copyWith(fontWeight: FontWeight.w900)
              : baseStyle,
        ),
      );
    }

    return spans;
  }

  List<String> _normalizedLines() {
    final rawLines = text.trim().split(RegExp(r'\r?\n'));
    final lines = <String>[];

    for (final line in rawLines) {
      if (line.trim().isEmpty && lines.lastOrNull?.trim().isEmpty == true) {
        continue;
      }

      lines.add(line);
    }

    return lines;
  }

  String _normalize(String value) {
    return value.replaceAll('*', '').replaceAll(':', '').trim().toLowerCase();
  }
}
