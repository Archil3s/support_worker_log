import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final provider = GoogleAuthProvider()
      ..addScope('https://www.googleapis.com/auth/calendar.events')
      ..addScope('https://www.googleapis.com/auth/calendar.readonly')
      ..setCustomParameters({'include_granted_scopes': 'true'});
    final credential = await _auth.signInWithPopup(provider);
    final user = credential.user;

    if (user == null) {
      throw StateError('Google sign-in returned no user.');
    }

    final oauth = credential.credential;
    _googleCalendarAccessToken = oauth is OAuthCredential
        ? oauth.accessToken
        : null;

    return user;
  }

  Future<String> requireGoogleCalendarAccessToken() async {
    final current = _googleCalendarAccessToken;

    if (current != null && current.isNotEmpty) {
      return current;
    }

    final provider = GoogleAuthProvider()
      ..addScope('https://www.googleapis.com/auth/calendar.events')
      ..addScope('https://www.googleapis.com/auth/calendar.readonly')
      ..setCustomParameters({'include_granted_scopes': 'true'});
    final credential = await _auth.signInWithPopup(provider);
    final user = credential.user;
    final oauth = credential.credential;

    if (user == null) {
      throw StateError('Google Calendar sign-in returned no user.');
    }

    _googleCalendarAccessToken = oauth is OAuthCredential
        ? oauth.accessToken
        : null;

    final updated = _googleCalendarAccessToken;

    if (updated == null || updated.isEmpty) {
      throw StateError(
        'Google Calendar access was not granted. Sign in with Google and allow calendar event access.',
      );
    }

    return updated;
  }

  Future<String> requireGoogleDriveAccessToken() async {
    final current = _googleDriveAccessToken;

    if (current != null && current.isNotEmpty) {
      return current;
    }

    final provider = GoogleAuthProvider()
      ..addScope('https://www.googleapis.com/auth/drive.file')
      ..setCustomParameters({'include_granted_scopes': 'true'});
    final credential = await _auth.signInWithPopup(provider);
    final user = credential.user;
    final oauth = credential.credential;

    if (user == null) {
      throw StateError('Google Drive sign-in returned no user.');
    }

    _googleDriveAccessToken = oauth is OAuthCredential
        ? oauth.accessToken
        : null;

    final updated = _googleDriveAccessToken;

    if (updated == null || updated.isEmpty) {
      throw StateError(
        'Google Drive access was not granted. Sign in with Google and allow Drive file access.',
      );
    }

    return updated;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
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

  Future<void> save(StoredAppData data) async {
    if (!isSignedIn) return;

    await _appDataDoc.set({
      ...data.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.waitForPendingWrites();
  }
}
