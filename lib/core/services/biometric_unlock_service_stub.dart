class BiometricUnlockService {
  Future<bool> isAvailable() async => false;

  Future<bool> isEnrolled() async => false;

  Future<bool> enroll() async => false;

  Future<bool> authenticate() async => false;
}
