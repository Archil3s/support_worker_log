import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static const _appPassword = 'abf02c38-c929-4326-9c8f-e5b0ff56f777';
  static const _failedAttemptsKey = 'app_lock_failed_attempts_v1';
  static const _lockedUntilKey = 'app_lock_locked_until_v1';
  static const _unlockValidUntilKey = 'app_lock_unlock_valid_until_v1';
  static const _allowedFailedAttempts = 2;
  static const _lockoutDuration = Duration(minutes: 5);
  static const _unlockDuration = Duration(hours: 24);

  bool verifyPassword(String password) {
    return password.trim() == _appPassword;
  }

  Future<DateTime?> lockedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_lockedUntilKey);
    if (value == null) return null;

    final until = _dateTimeFromStoredEpoch(value);
    if (until.isAfter(DateTime.now())) return until;

    await clearLockout();
    return null;
  }

  Future<bool> hasRememberedUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_unlockValidUntilKey);
    if (value == null) return false;

    final until = _dateTimeFromStoredEpoch(value);
    if (until.isAfter(DateTime.now())) return true;

    await clearRememberedUnlock();
    return false;
  }

  Future<void> rememberUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(_unlockDuration);
    await prefs.setInt(_unlockValidUntilKey, until.microsecondsSinceEpoch);
  }

  Future<DateTime?> recordFailedAttempt() async {
    final activeLockout = await lockedUntil();
    if (activeLockout != null) return activeLockout;

    final prefs = await SharedPreferences.getInstance();
    final failedAttempts = (prefs.getInt(_failedAttemptsKey) ?? 0) + 1;
    if (failedAttempts <= _allowedFailedAttempts) {
      await prefs.setInt(_failedAttemptsKey, failedAttempts);
      return null;
    }

    final until = DateTime.now().add(_lockoutDuration);
    await prefs.setInt(_lockedUntilKey, until.microsecondsSinceEpoch);
    await prefs.remove(_failedAttemptsKey);
    return until;
  }

  Future<void> clearLockout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lockedUntilKey);
  }

  Future<void> clearRememberedUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_unlockValidUntilKey);
  }

  DateTime _dateTimeFromStoredEpoch(int value) {
    if (value > 100000000000000) {
      return DateTime.fromMicrosecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
}
