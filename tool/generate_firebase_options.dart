import 'dart:io';

String env(String key) {
  final value = Platform.environment[key];

  if (value == null || value.trim().isEmpty) {
    stderr.writeln('Missing environment variable: $key');
    exit(1);
  }

  return value.trim();
}

void main() {
  final output =
      '''
// Generated at build time.
// Do not commit this file.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return web;
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: '${env('FIREBASE_WEB_API_KEY')}',
        appId: '${env('FIREBASE_WEB_APP_ID')}',
        messagingSenderId: '${env('FIREBASE_MESSAGING_SENDER_ID')}',
        projectId: '${env('FIREBASE_PROJECT_ID')}',
        authDomain: '${env('FIREBASE_AUTH_DOMAIN')}',
        storageBucket: '${env('FIREBASE_STORAGE_BUCKET')}',
      );
}
''';

  Directory('lib').createSync(recursive: true);
  File('lib/firebase_options.dart').writeAsStringSync(output);

  stdout.writeln('Generated lib/firebase_options.dart');
}
