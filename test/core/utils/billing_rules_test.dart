import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/models/entry_type.dart';
import 'package:support_worker_log/core/utils/billing_rules.dart';

void main() {
  group('noteAllowanceMinutes', () {
    test('returns no allowance for 30 minutes or less', () {
      expect(noteAllowanceMinutes(0), 0);
      expect(noteAllowanceMinutes(30), 0);
    });

    test('returns 15 minutes above 30 minutes and under 60 minutes', () {
      expect(noteAllowanceMinutes(31), 15);
      expect(noteAllowanceMinutes(59), 15);
    });

    test('returns 30 minutes at 60 minutes and above', () {
      expect(noteAllowanceMinutes(60), 30);
      expect(noteAllowanceMinutes(120), 30);
    });
  });

  test('calculateBillableTime includes note allowance', () {
    final breakdown = calculateBillableTime(
      type: EntryType.homeVisit,
      baseMinutes: 75,
      notes: const [],
    );

    expect(breakdown.baseMinutes, 75);
    expect(breakdown.noteSeconds, 1800);
    expect(breakdown.billableHours, 1.75);
  });
}
