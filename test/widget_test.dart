import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:durusuna_mobile/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: DurusunaMobileApp(),
      ),
    );

    // Verify that the app starts up (look for any text content)
    await tester.pumpAndSettle();

    // This test just ensures the app doesn't crash on startup
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Login page has required elements', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DurusunaMobileApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Look for login-related widgets (adjust based on your actual UI)
    expect(find.text('Durusuna'), findsWidgets);
  });
}
