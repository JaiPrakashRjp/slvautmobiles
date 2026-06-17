// Smoke test: the app boots into the splash screen and shows the brand.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slv_auto_consultant/controllers/theme_controller.dart';
import 'package:slv_auto_consultant/main.dart';

void main() {
  testWidgets('App boots to splash with brand title', (tester) async {
    await tester.pumpWidget(SlvApp(themeController: ThemeController()));
    await tester.pump();

    expect(find.text('SLV Auto Consultant'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);

    // Let the splash's 1.5s route timer fire so no timers remain pending.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  });
}
