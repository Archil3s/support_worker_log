import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:support_worker_log/core/state/app_state.dart';
import 'package:support_worker_log/features/auth/auth_gate.dart';

void main() {
  testWidgets('auth gate waits for saved session before showing login', (
    tester,
  ) async {
    final appState = AppState(warmGoogleAccounts: false);
    addTearDown(appState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    expect(find.byKey(const Key('session-restore-screen')), findsOneWidget);
    expect(find.text('Opening your saved work...'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
  });

  testWidgets('login presents simple Google and email choices', (tester) async {
    final appState = AppState(warmGoogleAccounts: false);
    addTearDown(appState.dispose);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('or use email'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      find.textContaining('Face ID or your app password opens the app'),
      findsOneWidget,
    );
    expect(find.text('App account'), findsNothing);
    expect(find.text('Google Drive'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google login shows progress on the Google button', (
    tester,
  ) async {
    final appState = _DelayedGoogleAuthAppState();
    addTearDown(appState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('auth-google-button')));
    await tester.pump();

    expect(find.text('Connecting to Google...'), findsOneWidget);
    expect(find.textContaining('Choose your Google account'), findsOneWidget);
    final emailButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('auth-email-button')),
    );
    expect(emailButton.onPressed, isNull);

    appState.googleSignIn.completeError(
      StateError('Google sign-in was cancelled.'),
    );
    await tester.pump();

    expect(find.text('Google sign-in was cancelled.'), findsOneWidget);
    expect(find.textContaining('Bad state:'), findsNothing);
  });

  testWidgets('login validates locally and scrolls above a small keyboard', (
    tester,
  ) async {
    final appState = AppState(warmGoogleAccounts: false);
    addTearDown(appState.dispose);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    tester.view.physicalSize = const Size(430, 560);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedGoogleAuthAppState extends AppState {
  _DelayedGoogleAuthAppState() : super(warmGoogleAccounts: false);

  final Completer<void> googleSignIn = Completer<void>();

  @override
  Future<void> signInWithGoogle() => googleSignIn.future;
}
