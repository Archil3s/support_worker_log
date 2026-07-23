import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/shared/widgets/google_drive_connection_animation.dart';

void main() {
  testWidgets('shows a compact animation without a loading bar', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(320, 180);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoogleDriveConnectionAnimation(reconnecting: true),
        ),
      ),
    );

    expect(
      find.byKey(const Key('google-drive-connection-animation')),
      findsOneWidget,
    );
    expect(find.text('Reconnecting Google Drive'), findsOneWidget);
    expect(find.byKey(const Key('app-boot-logo')), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });
}
