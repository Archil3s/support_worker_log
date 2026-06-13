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
}
