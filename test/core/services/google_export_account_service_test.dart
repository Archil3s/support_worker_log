import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:support_worker_log/core/models/google_export_account_scope.dart';
import 'package:support_worker_log/core/services/google_export_account_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'reconnect restores a valid Drive token without a Firebase popup',
    () async {
      final expiresAt = DateTime.now().add(const Duration(minutes: 20));
      SharedPreferences.setMockInitialValues({
        'preferred_google_export_account_work_v1': 'worker@example.com',
        'google_export_access_token_work_v1': 'cached-drive-token',
        'google_export_access_token_expiry_work_v1':
            expiresAt.millisecondsSinceEpoch,
        'google_export_access_token_email_work_v1': 'worker@example.com',
      });
      final auth = _FakeFirebaseAuth(
        currentUser: _FakeUser(email: 'worker@example.com'),
      );
      final service = GoogleExportAccountService(auth: auth);

      await service.warmUp(scope: GoogleExportAccountScope.work);
      final connection = await service.connect(
        scope: GoogleExportAccountScope.work,
      );

      expect(connection.accessToken, 'cached-drive-token');
      expect(connection.email, 'worker@example.com');
      expect(service.isConnected(GoogleExportAccountScope.work), true);
      expect(auth.popupCalls, 0);
    },
  );

  test('expired cached Drive tokens are removed during warm up', () async {
    final expiresAt = DateTime.now().subtract(const Duration(minutes: 1));
    SharedPreferences.setMockInitialValues({
      'google_export_access_token_work_v1': 'expired-drive-token',
      'google_export_access_token_expiry_work_v1':
          expiresAt.millisecondsSinceEpoch,
      'google_export_access_token_email_work_v1': 'worker@example.com',
    });
    final auth = _FakeFirebaseAuth(
      currentUser: _FakeUser(email: 'worker@example.com'),
    );
    final service = GoogleExportAccountService(auth: auth);

    await service.warmUp(scope: GoogleExportAccountScope.work);

    final prefs = await SharedPreferences.getInstance();
    expect(service.isConnected(GoogleExportAccountScope.work), false);
    expect(prefs.getString('google_export_access_token_work_v1'), isNull);
    expect(prefs.getInt('google_export_access_token_expiry_work_v1'), isNull);
    expect(auth.popupCalls, 0);
  });
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth({required this.currentUser});

  @override
  final User? currentUser;

  int popupCalls = 0;

  @override
  Future<void> setPersistence(Persistence persistence) async {}

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    popupCalls++;
    throw StateError('Firebase popup should not open.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser({required this.email});

  @override
  final String? email;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
