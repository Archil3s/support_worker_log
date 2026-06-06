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

  static const _secondaryAppName = 'support_worker_log_google_exports';

  final FirebaseAuth? _authOverride;
  FirebaseAuth? _auth;
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
    final auth = await _secondaryAuth();
    final credential = await _signInWithGoogle(auth, forceRefresh);
    final oauth = credential.credential;
    final token = oauth is OAuthCredential ? oauth.accessToken : null;

    if (token == null || token.isEmpty) {
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

  Future<FirebaseAuth> _secondaryAuth() async {
    final override = _authOverride;
    if (override != null) return override;

    final current = _auth;
    if (current != null) return current;

    final existing = Firebase.apps.where(
      (app) => app.name == _secondaryAppName,
    );
    final app = existing.isNotEmpty
        ? existing.first
        : await Firebase.initializeApp(
            name: _secondaryAppName,
            options: DefaultFirebaseOptions.currentPlatform,
          );

    _auth = FirebaseAuth.instanceFor(app: app);
    return _auth!;
  }

  Future<UserCredential> _signInWithGoogle(
    FirebaseAuth auth,
    bool forceRefresh,
  ) {
    final parameters = <String, String>{
      'include_granted_scopes': 'true',
      'prompt': forceRefresh ? 'consent select_account' : 'select_account',
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
}
