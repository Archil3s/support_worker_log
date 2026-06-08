class AppLockService {
  static const _appPassword = 'abf02c38-c929-4326-9c8f-e5b0ff56f777';

  bool verifyPassword(String password) {
    return password.trim() == _appPassword;
  }
}
