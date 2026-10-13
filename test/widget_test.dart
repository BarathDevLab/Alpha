import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha/main.dart';

void main() {
  testWidgets('ConsentPage renders correctly', (WidgetTester tester) async {
    // Set a large screen size so the ListView items are in view
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ConsentPage(
          onContinue: (bool mind, bool sound) {
            continued = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify key titles and controls are rendered
    expect(find.text('Safety, on your terms.'), findsOneWidget);
    expect(find.text('Mind Guard'), findsOneWidget);
    expect(find.text('Sound Guard'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(continued, isFalse);
  });
}
