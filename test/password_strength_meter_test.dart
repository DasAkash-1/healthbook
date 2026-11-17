import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthbook_test/widgets/password_strength_meter.dart';

void main() {
  Future<void> show(WidgetTester tester, String password) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordStrengthMeter(password: password)),
      ),
    );
  }

  testWidgets('shows nothing until the person starts typing', (tester) async {
    await show(tester, '');
    expect(find.text('Password strength: '), findsNothing);
  });

  testWidgets('shows Weak for an easy password', (tester) async {
    await show(tester, 'abc');
    expect(find.text('Password strength: '), findsOneWidget);
    expect(find.text('Weak'), findsOneWidget);
  });

  testWidgets('shows Strong for a long mixed password', (tester) async {
    await show(tester, 'Xk9#mQ2\$vL7pRt4!');
    expect(find.text('Strong'), findsOneWidget);
  });
}
