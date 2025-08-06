// This is a basic Flutter widget test for Vent AI.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vent_ai/main.dart';

void main() {
  testWidgets('Vent AI app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VentAiApp());

    // Verify that our app loads with the correct title.
    expect(find.text('Vent AI'), findsOneWidget);

    // Verify the welcome message appears when no conversations exist.
    expect(find.text('Welcome to Vent AI'), findsOneWidget);
    expect(find.text('I\'m here to listen and support you.\nHow are you feeling today?'), findsOneWidget);

    // Verify the mood selector is present.
    expect(find.text('How are you feeling? (Optional)'), findsOneWidget);

    // Verify the message input field is present.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Share what\'s on your mind...'), findsOneWidget);

    // Verify the send button is present.
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('Message input and send functionality', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VentAiApp());

    // Find the text input field.
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    // Enter a test message.
    await tester.enterText(textField, 'Hello, I need someone to talk to');
    await tester.pump();

    // Verify the text was entered.
    expect(find.text('Hello, I need someone to talk to'), findsOneWidget);

    // Tap the send button.
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // Note: In a real test, you'd mock the API service to avoid actual network calls
    // For now, this tests that the send functionality is wired up correctly
  });
}
