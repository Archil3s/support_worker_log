import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../firebase_options.dart';
import '../models/google_export_account_scope.dart';

class GoogleExportConnection {
  const GoogleExportConnection({
    required this.scope,
    required this.accessToken,
    this.email,
  });

  final GoogleExportAccountScope scope;
  final String accessToken;
  final String? email;
}

class GoogleExportAccountService {
  GoogleExportAccountService({FirebaseAuth? auth}) : _authOverride = auth;

  static const _secondaryAppNamePrefix = 'support_worker_log_google_exports';
  static const _googleSignInTimeout = Duration(seconds: 90);

  final FirebaseAuth? _authOverride;
  final Map<GoogleExportAccountScope, FirebaseAuth> _authByScope = {};
  final Map<GoogleExportAccountScope, GoogleExportConnection> _connections = {};
  final Map<GoogleExportAccountScope, String> _signedInEmails = {};

  String? accessTokenFor(GoogleExportAccountScope scope) {
    return _connections[scope]?.accessToken;
  }

  String? emailFor(GoogleExportAccountScope scope) {
    return _connections[scope]?.email ?? _signedInEmails[scope];
  }

  bool isConnected(GoogleExportAccountScope scope) {
    final token = accessTokenFor(scope);
    return token != null && token.isNotEmpty;
  }

  bool hasSignedInAccount(GoogleExportAccountScope scope) {
    return emailFor(scope) != null;
  }

  Future<void> warmUp({required GoogleExportAccountScope scope}) async {
    final auth = await _secondaryAuth(scope);
    _rememberSignedInUser(scope, auth.currentUser);
  }

  Future<GoogleExportConnection> connect({
    required GoogleExportAccountScope scope,
    bool forceRefresh = false,
  }) async {
    final current = _connections[scope];
    if (!forceRefresh &&
        current != null &&
        current.accessToken.trim().isNotEmpty) {
      return current;
    }

    final auth = await _secondaryAuth(scope);
    if (forceRefresh) {
      await _resetSecondaryAuth(auth);
    }
    late final UserCredential credential;

    try {
      credential = await _signInWithGoogle(
        auth,
        forceRefresh,
        hasCurrentUser: auth.currentUser != null,
      ).timeout(_googleSignInTimeout);
    } on TimeoutException {
      throw StateError(
        '${scope.label} Google sign-in timed out. Close any old Google popup and try again.',
      );
    } on FirebaseAuthException catch (error) {
      throw StateError(_authErrorMessage(scope, error));
    } catch (_) {
      rethrow;
    }

    final oauth = credential.credential;
    final token = oauth is OAuthCredential ? oauth.accessToken : null;

    if (token == null || token.isEmpty) {
      await _resetSecondaryAuth(auth);
      throw StateError(
        '${scope.label} Google account did not return an access token.',
      );
    }

    final connection = GoogleExportConnection(
      scope: scope,
      accessToken: token,
      email: credential.user?.email,
    );
    _connections[scope] = connection;
    _rememberSignedInUser(scope, credential.user);

    return connection;
  }

  Future<String> requireAccessToken({
    required GoogleExportAccountScope scope,
  }) async {
    final token = accessTokenFor(scope);
    if (token != null && token.isNotEmpty) return token;

    throw StateError(
      '${scope.label} Google account is not connected. Connect it from the Drive screen first.',
    );
  }

  Future<void> signOutAll() async {
    for (final auth in _authByScope.values) {
      await _resetSecondaryAuth(auth);
    }

    _connections.clear();
    _signedInEmails.clear();
  }

  Future<FirebaseAuth> _secondaryAuth(GoogleExportAccountScope scope) async {
    final override = _authOverride;
    if (override != null) {
      await _setLocalPersistence(override);
      return override;
    }

    final current = _authByScope[scope];
    if (current != null) return current;

    final appName = _secondaryAppNameFor(scope);
    final existing = Firebase.apps.where((app) => app.name == appName);
    final app = existing.isNotEmpty
        ? existing.first
        : await Firebase.initializeApp(
            name: appName,
            options: DefaultFirebaseOptions.currentPlatform,
          );

    final auth = FirebaseAuth.instanceFor(app: app);
    await _setLocalPersistence(auth);
    _authByScope[scope] = auth;
    return auth;
  }

  Future<UserCredential> _signInWithGoogle(
    FirebaseAuth auth,
    bool forceRefresh, {
    required bool hasCurrentUser,
  }) {
    final parameters = <String, String>{
      'include_granted_scopes': 'true',
      if (forceRefresh)
        'prompt': 'consent select_account'
      else if (!hasCurrentUser)
        'prompt': 'select_account',
    };
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..addScope('https://www.googleapis.com/auth/drive.file')
      ..setCustomParameters(parameters);

    if (kIsWeb) return auth.signInWithPopup(provider);
    return auth.signInWithProvider(provider);
  }

  String _secondaryAppNameFor(GoogleExportAccountScope scope) {
    return '${_secondaryAppNamePrefix}_${scope.name}';
  }

  Future<void> _resetSecondaryAuth(FirebaseAuth auth) async {
    if (auth.currentUser == null) return;

    await auth.signOut();
  }

  void _rememberSignedInUser(GoogleExportAccountScope scope, User? user) {
    final email = user?.email?.trim();
    if (email == null || email.isEmpty) return;

    _signedInEmails[scope] = email;
  }

  Future<void> _setLocalPersistence(FirebaseAuth auth) async {
    if (!kIsWeb) return;

    await auth.setPersistence(Persistence.LOCAL);
  }

  String _authErrorMessage(
    GoogleExportAccountScope scope,
    FirebaseAuthException error,
  ) {
    final code = error.code.toLowerCase();
    final message = error.message?.trim();

    if (code.contains('popup-closed-by-user') ||
        code.contains('cancelled-popup-request') ||
        code.contains('canceled')) {
      return '${scope.label} Google sign-in was cancelled. Try Choose ${scope.label} Google Account again.';
    }

    if (code.contains('popup-blocked') ||
        (message != null && message.toLowerCase().contains('popup'))) {
      return '${scope.label} Google sign-in popup was blocked. On phone, open the app in Safari/Chrome and tap Choose ${scope.label} Google Account again.';
    }

    if (code.contains('access-denied') ||
        code.contains('permission-denied') ||
        (message != null && message.toLowerCase().contains('access denied'))) {
      return '${scope.label} Google access was denied. Choose the account again and allow Drive and Calendar access.';
    }

    if (message != null && message.isNotEmpty) {
      return '${scope.label} Google sign-in failed: $message';
    }

    return '${scope.label} Google sign-in failed: ${error.code}';
  }
}
