import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge/src/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('knowledge app shows main shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const KnowledgeApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('Tree'), findsOneWidget);
  });
}
