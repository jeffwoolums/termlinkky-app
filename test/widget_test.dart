import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:termlinkky/main.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const TermLinkkyApp());
    
    // Initial pump shows loading indicator
    await tester.pump();
    
    // Wait for FutureBuilder to resolve (with timeout)
    await tester.pump(const Duration(seconds: 1));
    
    // App should at least render without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
