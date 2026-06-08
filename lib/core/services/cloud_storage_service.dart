import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

class CloudStorageService {
  CloudStorageService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  String? _googleCalendarAccessToken;
  String? _googleDriveAccessToken;
  DateTime? _sessionExpiresAt;

  static const _googleSignInTimeout = Duration(seconds: 75);
  static const _sessionStartedAtKey =
      'support_worker_log_session_started_at_v1';
  static const _sessionMaxAge = Duration(hours: 24);

  User? get currentUser => _auth.currentUser;

  String? get userId => currentUser?.uid;

  String? get email => currentUser?.email;

  String? get googleCalendarAccessToken => _googleCalendarAccessToken;

  String? get googleDriveAccessToken => _googleDriveAccessToken;

  DateTime? get sessionExpiresAt => _sessionExpiresAt;

  bool get isGoogleBackedUser {
    final user = currentUser;
    if (user == null) return false;

    return user.providerData.any((item) => item.providerId == 'google.com');
  }

  bool get isSignedIn {
    final user = currentUser;
    return user != null && !user.isAnonymous;
  }

  Future<bool> signOutIfSessionExpired() async {
    if (!isSignedIn) return false;

    final prefs = await SharedPreferences.getInstance();
    final startedAtMs = prefs.getInt(_sessionStartedAtKey);

    if (startedAtMs == null) {
      await _recordSessionStart();
      return false;
    }

    final startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
    _sessionExpiresAt = startedAt.add(_sessionMaxAge);
    final expired = DateTime.now().difference(startedAt) >= _sessionMaxAge;
    if (!expired) return false;

    await signOut();
    return true;
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

    await _recordSessionStart();

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

    await _recordSessionStart();

    return user;
  }

  Future<User> signInWithGoogle() async {
    late final UserCredential credential;

    try {
      credential = await _withGooglePopupTimeout(
        _signInWithGoogleProvider(_googleServicesProvider()),
        'Google sign-in',
      );
    } on FirebaseAuthException catch (error) {
      throw StateError(_authErrorMessage('Google sign-in', error));
    }

    final user = credential.user;

    if (user == null) {
      throw StateError('Google sign-in returned no user.');
    }

    _storeGoogleServicesToken(credential);
    await _recordSessionStart();

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

      credential = await _withGooglePopupTimeout(
        isGoogleBackedUser
            ? _refreshGoogleBackedCredential(user, provider)
            : _linkWithGoogleProvider(user, provider),
        'Google services sign-in',
      );

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
    final code = error.code.toLowerCase();
    final message = error.message;

    if (code.contains('popup-closed-by-user') ||
        code.contains('cancelled-popup-request') ||
        code.contains('canceled')) {
      return '$action was cancelled. Close any old Google popup and try again.';
    }

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

  Future<UserCredential> _withGooglePopupTimeout(
    Future<UserCredential> signIn,
    String action,
  ) async {
    try {
      return await signIn.timeout(_googleSignInTimeout);
    } on TimeoutException {
      throw StateError(
        '$action timed out. Close any old Google popup and try again.',
      );
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStartedAtKey);
    _sessionExpiresAt = null;
    await _auth.signOut();
  }

  Future<void> _recordSessionStart() async {
    final startedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionStartedAtKey, startedAt.millisecondsSinceEpoch);
    _sessionExpiresAt = startedAt.add(_sessionMaxAge);
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
