// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:grocery_app/main.dart';

void main() {
  testWidgets('Register page loads correctly smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GroceryApp());

    // Verify that our main registration page header is displayed.
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Fresh groceries are just one step away'), findsOneWidget);
  });
}
