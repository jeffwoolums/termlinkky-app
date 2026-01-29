import 'package:flutter_test/flutter_test.dart';
import 'package:termlinkky/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const TermLinkkyApp());
    // App should show onboarding or home screen
    await tester.pumpAndSettle();
    expect(find.text('TermLinkky'), findsWidgets);
  });
}
