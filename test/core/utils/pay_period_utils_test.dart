import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/utils/pay_period_utils.dart';

void main() {
  test('fortnightForDate uses calendar days across daylight saving', () {
    final range = fortnightForDate(
      DateTime(2026, 5, 30),
      anchorDate: DateTime(2025, 11, 29),
    );

    expect(range.start, DateTime(2026, 5, 30));
    expect(range.end, DateTime(2026, 6, 12));
  });
}
