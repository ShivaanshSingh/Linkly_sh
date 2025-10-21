// This is a basic Flutter widget test for the Linkly app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:linkly/main.dart';
import 'package:linkly/services/auth_service.dart';
import 'package:linkly/services/firestore_service.dart';
import 'package:linkly/services/notification_service.dart';

void main() {
  testWidgets('Linkly app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => FirestoreService()),
          ChangeNotifierProvider(create: (_) => NotificationService()),
        ],
        child: const LinklyApp(firebaseInitialized: false),
      ),
    );

    // Wait for any pending timers to complete
    await tester.pumpAndSettle();

    // Verify that the app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
