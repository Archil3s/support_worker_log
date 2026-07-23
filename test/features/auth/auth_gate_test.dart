import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:support_worker_log/core/state/app_state.dart';
import 'package:support_worker_log/features/auth/auth_gate.dart';

void main() {
  testWidgets('login separates app account from Google Drive access', (
    tester,
  ) async {
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

    expect(find.text('Sign in to your app'), findsOneWidget);
    expect(find.text('App account'), findsOneWidget);
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('Sign in with email'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign In & Sync'), findsNothing);
    expect(find.text('Continue with Google Sync'), findsNothing);
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

    await tester.ensureVisible(find.text('Sign in with email'));
    await tester.tap(find.text('Sign in with email'));
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
