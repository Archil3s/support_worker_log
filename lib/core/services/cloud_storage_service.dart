import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'storage_service.dart';

class CloudStorageService {
  CloudStorageService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  String? _googleCalendarAccessToken;
  String? _googleDriveAccessToken;

  User? get currentUser => _auth.currentUser;

  String? get userId => currentUser?.uid;

  String? get email => currentUser?.email;

  String? get googleCalendarAccessToken => _googleCalendarAccessToken;

  String? get googleDriveAccessToken => _googleDriveAccessToken;

  bool get isGoogleBackedUser {
    final user = currentUser;
    if (user == null) return false;

    return user.providerData.any((item) => item.providerId == 'google.com');
  }

  bool get isSignedIn {
    final user = currentUser;
    return user != null && !user.isAnonymous;
  }

  Future<void> signOutAnonymousUserIfNeeded() async {
    final user = currentUser;

    if (user != null && user.isAnonymous) {
      await _auth.signOut();
    }
  }

  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw StateError('Firebase sign-in returned no user.');
    }

    return user;
  }

  Future<User> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw StateError('Firebase registration returned no user.');
    }

    return user;
  }

  Future<User> signInWithGoogle() async {
    final credential = await _signInWithGoogleProvider(
      _googleServicesProvider(),
    );
    final user = credential.user;

    if (user == null) {
      throw StateError('Google sign-in returned no user.');
    }

    _storeGoogleServicesToken(credential);

    return user;
  }

  Future<void> connectGoogleServicesForCurrentUser({
    bool forceRefresh = false,
    bool allowPopup = false,
  }) async {
    if (!isSignedIn) return;
    if (!forceRefresh &&
        _googleCalendarAccessToken != null &&
        _googleDriveAccessToken != null) {
      return;
    }

    if (!allowPopup) {
      throw StateError(
        'Google Drive and Calendar need an active Google access token. Sign in with Continue with Google Sync, or use Connect Drive + Calendar once.',
      );
    }

    late final UserCredential credential;

    try {
      final user = currentUser;
      if (user == null) return;
      final currentUserId = user.uid;
      final provider = _googleServicesProvider(forceConsent: forceRefresh);

      credential = isGoogleBackedUser
          ? await _refreshGoogleBackedCredential(user, provider)
          : await _linkWithGoogleProvider(user, provider);

      if (credential.user?.uid != currentUserId) {
        throw StateError(
          'Google services sign-in used a different account. Choose the same account as the app sign-in.',
        );
      }
    } on FirebaseAuthException catch (error) {
      throw StateError(_authErrorMessage('Google services sign-in', error));
    }

    if (credential.user == null) {
      throw StateError('Google services sign-in returned no user.');
    }

    _storeGoogleServicesToken(credential);
  }

  Future<UserCredential> _signInWithGoogleProvider(
    GoogleAuthProvider provider,
  ) {
    if (kIsWeb) return _auth.signInWithPopup(provider);
    return _auth.signInWithProvider(provider);
  }

  Future<UserCredential> _linkWithGoogleProvider(
    User user,
    GoogleAuthProvider provider,
  ) {
    if (kIsWeb) return user.linkWithPopup(provider);
    return user.linkWithProvider(provider);
  }

  Future<UserCredential> _refreshGoogleBackedCredential(
    User user,
    GoogleAuthProvider provider,
  ) {
    if (kIsWeb) return _auth.signInWithPopup(provider);
    return user.reauthenticateWithProvider(provider);
  }

  Future<String> requireGoogleCalendarAccessToken() async {
    final current = _googleCalendarAccessToken;

    if (current != null && current.isNotEmpty) {
      return current;
    }

    await connectGoogleServicesForCurrentUser();

    final updated = _googleCalendarAccessToken;

    if (updated == null || updated.isEmpty) {
      throw StateError(
        'Google Calendar access was not granted. Sign in with Google and allow calendar event access.',
      );
    }

    return updated;
  }

  Future<String> requireGoogleDriveAccessToken({
    bool forceRefresh = false,
  }) async {
    final current = _googleDriveAccessToken;

    if (!forceRefresh && current != null && current.isNotEmpty) {
      return current;
    }

    await connectGoogleServicesForCurrentUser(forceRefresh: forceRefresh);

    final updated = _googleDriveAccessToken;

    if (updated == null || updated.isEmpty) {
      throw StateError(
        'Google Drive access was not granted. Sign in with Google and allow Drive file access.',
      );
    }

    return updated;
  }

  String _authErrorMessage(String action, FirebaseAuthException error) {
    final message = error.message;

    if (message != null && message.trim().isNotEmpty) {
      return '$action failed: ${message.trim()}';
    }

    return '$action failed: ${error.code}';
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  GoogleAuthProvider _googleServicesProvider({bool forceConsent = false}) {
    final parameters = <String, String>{
      'include_granted_scopes': 'true',
      if (forceConsent) 'prompt': 'consent',
    };

    return GoogleAuthProvider()
      ..addScope('https://www.googleapis.com/auth/calendar.events')
      ..addScope('https://www.googleapis.com/auth/calendar.readonly')
      ..addScope('https://www.googleapis.com/auth/drive.file')
      ..setCustomParameters(parameters);
  }

  void _storeGoogleServicesToken(UserCredential credential) {
    final oauth = credential.credential;
    final token = oauth is OAuthCredential ? oauth.accessToken : null;

    _googleCalendarAccessToken = token;
    _googleDriveAccessToken = token;
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  DocumentReference<Map<String, dynamic>> get _appDataDoc {
    final uid = userId;

    if (uid == null || uid.isEmpty) {
      throw StateError('Cannot access cloud data before Firebase sign-in.');
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('appData');
  }

  Future<StoredAppData?> load() async {
    if (!isSignedIn) return null;

    final snapshot = await _appDataDoc.get(
      const GetOptions(source: Source.server),
    );

    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return StoredAppData.fromJson(data);
  }

  Stream<StoredAppData?> watch() {
    if (!isSignedIn) return Stream.value(null);

    return _appDataDoc.snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return StoredAppData.fromJson(data);
    });
  }

  Future<void> save(StoredAppData data) async {
    if (!isSignedIn) return;

    await _appDataDoc.set({
      ...data.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.waitForPendingWrites();
  }
}
