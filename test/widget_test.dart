import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meca_app_cliente/main.dart';

void main() {
  testWidgets('MECA App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MecaClienteApp());

    // Verify that the app starts without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}