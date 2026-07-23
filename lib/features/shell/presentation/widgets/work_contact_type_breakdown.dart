import 'package:flutter/material.dart';

import '../../../../core/models/entry_type.dart';
import '../models/work_contact_type_display.dart';

class WorkContactTypeBreakdown extends StatelessWidget {
  const WorkContactTypeBreakdown({required this.entriesByType, super.key});

  final Map<EntryType, int> entriesByType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONTACT TYPE TOTALS',
          style: TextStyle(
            color: Color(0xFFAFC6F5),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var index = 0;
                index < workContactTypeDisplayOrder.length;
                index++
              ) ...[
                _ContactTypeTotal(
                  key: ValueKey(
                    'work-contact-type-'
                    '${workContactTypeDisplayOrder[index].name}',
                  ),
                  type: workContactTypeDisplayOrder[index],
                  count: entriesByType[workContactTypeDisplayOrder[index]] ?? 0,
                ),
                if (index < workContactTypeDisplayOrder.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactTypeTotal extends StatelessWidget {
  const _ContactTypeTotal({required this.type, required this.count, super.key});

  final EntryType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1527).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF294A7C)),
      ),
      child: Row(
        children: [
          Icon(type.icon, size: 18, color: const Color(0xFF8CB8FF)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              workContactTypeDisplayLabel(type),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD8E6FF),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            constraints: const BoxConstraints(minWidth: 25),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF173763),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
