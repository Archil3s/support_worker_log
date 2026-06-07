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

  String? accessTokenFor(GoogleExportAccountScope scope) {
    return _connections[scope]?.accessToken;
  }

  String? emailFor(GoogleExportAccountScope scope) {
    return _connections[scope]?.email;
  }

  bool isConnected(GoogleExportAccountScope scope) {
    final token = accessTokenFor(scope);
    return token != null && token.isNotEmpty;
  }

  Future<GoogleExportConnection> connect({
    required GoogleExportAccountScope scope,
    bool forceRefresh = false,
  }) async {
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
      await _resetSecondaryAuth(auth);
      throw StateError(
        '${scope.label} Google sign-in timed out. Close any old Google popup and try again.',
      );
    } on FirebaseAuthException catch (error) {
      await _resetSecondaryAuth(auth);
      throw StateError(_authErrorMessage(scope, error));
    } catch (_) {
      await _resetSecondaryAuth(auth);
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

  Future<FirebaseAuth> _secondaryAuth(GoogleExportAccountScope scope) async {
    final override = _authOverride;
    if (override != null) return override;

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
    _authByScope[scope] = auth;
    return auth;
  }

  Future<UserCredential> _signInWithGoogle(
    FirebaseAuth auth,
    bool forceRefresh, {
    required bool hasCurrentUser,
  }) {
    final prompt = forceRefresh
        ? 'consent select_account'
        : hasCurrentUser
        ? 'consent'
        : 'select_account';
    final parameters = <String, String>{
      'include_granted_scopes': 'true',
      'prompt': prompt,
    };
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..addScope('https://www.googleapis.com/auth/calendar.events')
      ..addScope('https://www.googleapis.com/auth/calendar.readonly')
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
