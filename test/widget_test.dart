import 'package:flutter_test/flutter_test.dart';

import 'package:healthbook_test/main.dart';
import 'package:healthbook_test/splash_screen.dart';

void main() {
  testWidgets('app opens on the splash screen, then shows the intro screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    // The splash screen waits 3 seconds, then fades into the intro screen.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(IntroScreen), findsOneWidget);
  });
}
