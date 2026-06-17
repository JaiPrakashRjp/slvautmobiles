// Exercises the full provider graph and navigation: sign in as Super Admin,
// land on the module chooser, open Auto Sale, and see seeded data.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slv_auto_consultant/controllers/theme_controller.dart';
import 'package:slv_auto_consultant/main.dart';

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(SlvApp(themeController: ThemeController()));
  await tester.pump(const Duration(milliseconds: 1600)); // past splash timer
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Super Admin signs in and opens Auto Sale with seed data',
      (tester) async {
    await _boot(tester);

    // Sign-in screen.
    expect(find.text('Sign in'), findsWidgets);
    await tester.enterText(find.byType(TextFormField).first, 'owner');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 700)); // mock auth delay
    await tester.pumpAndSettle();

    // Module chooser.
    expect(find.text('Choose module'), findsOneWidget);
    expect(find.text('Auto sale system'), findsWidgets);

    // Open Auto Sale → vehicles list with a seeded registration.
    await tester.tap(find.text('Auto sale system').first);
    await tester.pumpAndSettle();
    expect(find.text('KA-01-AB-1234'), findsOneWidget);

    // Switch to the Customers tab.
    await tester.tap(find.text('Customers').first);
    await tester.pumpAndSettle();
    expect(find.text('Ravi Kumar'), findsOneWidget);
  });
}
