import 'package:flutter_test/flutter_test.dart';
import 'package:leadtext/main.dart';

void main() {
  testWidgets('LeadText app smoke test', (WidgetTester tester) async {
    // 1. Build LeadTextApp (or LeadTextMobileApp depending on class name in main.dart)
    await tester.pumpWidget(const LeadTextApp());

    // 2. Verify that the LeadText brand name appears on screen
    expect(find.text('LeadText'), findsOneWidget);
  });
}