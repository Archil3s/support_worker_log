import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('test runner works', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Support Worker Log'))),
    );

    expect(find.text('Support Worker Log'), findsOneWidget);
  });
}
