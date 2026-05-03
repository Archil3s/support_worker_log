import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'storage_service.dart';

class CloudStorageService {
  CloudStorageService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String? get userId => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  Future<User> signInAnonymouslyIfNeeded() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;

    final credential = await _auth.signInAnonymously();
    final user = credential.user;

    if (user == null) {
      throw StateError('Firebase anonymous sign-in returned no user.');
    }

    return user;
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
    final snapshot = await _appDataDoc.get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return StoredAppData.fromJson(data);
  }

  Future<void> save(StoredAppData data) async {
    await _appDataDoc.set({
      ...data.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
