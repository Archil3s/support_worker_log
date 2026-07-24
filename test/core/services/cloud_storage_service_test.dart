import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/services/cloud_storage_service.dart';

void main() {
  test('app lock session window is 24 hours', () {
    expect(
      CloudStorageService.sessionMaxAgeForTesting,
      const Duration(hours: 24),
    );
  });

  test('Google web login starts a redirect without opening a popup', () async {
    final auth = _RedirectFirebaseAuth();
    final service = CloudStorageService(auth: auth);

    await service.startGoogleSignInRedirect();

    expect(auth.redirectCalls, 1);
    expect(auth.popupCalls, 0);
  });
}

class _RedirectFirebaseAuth implements FirebaseAuth {
  int redirectCalls = 0;
  int popupCalls = 0;

  @override
  Future<void> signInWithRedirect(AuthProvider provider) async {
    redirectCalls++;
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) {
    popupCalls++;
    throw StateError('Popup login should not be used.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
