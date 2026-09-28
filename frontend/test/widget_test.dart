import 'package:flutter_test/flutter_test.dart';
import 'package:FitOak/main.dart'; // Fixed package import name

void main() {
  testWidgets('FitOak app launches successfully test', (WidgetTester tester) async {
    // Build the FitOak application
    await tester.pumpWidget(const FitOakApp());

    // Verify Onboarding screen text is rendered
    expect(find.textContaining('Welcome to FitOak'), findsOneWidget);
  });
}