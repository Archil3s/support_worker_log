import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/services/app_lock_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('third wrong app password starts a five minute lockout', () async {
    final service = AppLockService();

    expect(await service.recordFailedAttempt(), isNull);
    expect(await service.recordFailedAttempt(), isNull);

    final lockedUntil = await service.recordFailedAttempt();

    expect(lockedUntil, isNotNull);
    expect(await service.lockedUntil(), lockedUntil);
  });

  test('successful unlock clears failed attempts and lockout state', () async {
    final service = AppLockService();

    await service.recordFailedAttempt();
    await service.clearLockout();

    expect(await service.lockedUntil(), isNull);
    expect(await service.recordFailedAttempt(), isNull);
    expect(await service.recordFailedAttempt(), isNull);
  });

  test('successful local unlock can be remembered and cleared', () async {
    final service = AppLockService();

    expect(await service.hasRememberedUnlock(), isFalse);

    await service.rememberUnlock();

    expect(await service.hasRememberedUnlock(), isTrue);

    await service.clearRememberedUnlock();

    expect(await service.hasRememberedUnlock(), isFalse);
  });

  test('remembered local unlock is valid for one hour', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = AppLockService();

    await service.rememberUnlock();

    final validUntil = DateTime.fromMicrosecondsSinceEpoch(
      prefs.getInt('app_lock_unlock_valid_until_v1')!,
    );
    final remaining = validUntil.difference(DateTime.now());

    expect(remaining, greaterThan(const Duration(minutes: 59)));
    expect(remaining, lessThanOrEqualTo(const Duration(hours: 1)));
  });

  test('remembered local unlock expires after one hour', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = AppLockService();
    final expiredAt = DateTime.now()
        .subtract(const Duration(minutes: 1))
        .microsecondsSinceEpoch;

    await prefs.setInt('app_lock_unlock_valid_until_v1', expiredAt);

    expect(await service.hasRememberedUnlock(), isFalse);
    expect(prefs.getInt('app_lock_unlock_valid_until_v1'), isNull);
  });
}
