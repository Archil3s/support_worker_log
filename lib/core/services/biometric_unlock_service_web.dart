import 'dart:js_interop';

@JS('supportWorkerLogBiometricAvailable')
external JSPromise<JSBoolean> _biometricAvailable();

@JS('supportWorkerLogBiometricEnrolled')
external JSPromise<JSBoolean> _biometricEnrolled();

@JS('supportWorkerLogEnrollBiometric')
external JSPromise<JSBoolean> _enrollBiometric();

@JS('supportWorkerLogAuthenticateBiometric')
external JSPromise<JSBoolean> _authenticateBiometric();

class BiometricUnlockService {
  Future<bool> isAvailable() => _readResult(_biometricAvailable());

  Future<bool> isEnrolled() => _readResult(_biometricEnrolled());

  Future<bool> enroll() => _readResult(_enrollBiometric());

  Future<bool> authenticate() => _readResult(_authenticateBiometric());

  Future<bool> _readResult(JSPromise<JSBoolean> operation) async {
    try {
      final result = await operation.toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }
}
