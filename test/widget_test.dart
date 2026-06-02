import 'package:flutter_test/flutter_test.dart';

import 'package:lokalog_app/main.dart';

void main() {
  testWidgets('Scenario page renders key sections', (WidgetTester tester) async {
    await tester.pumpWidget(const LokaLogApp());

    expect(find.text('LokaLog - Locations Log'), findsOneWidget);
    expect(find.text('Locations Log'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Locations'), findsOneWidget);
  });
}
