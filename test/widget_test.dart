import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthbook_test/main.dart';
import 'package:healthbook_test/splash_screen.dart';

void main() {
  testWidgets('app opens on the splash screen, then shows the intro screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    // The splash waits at least 2.5 seconds, and at most 6 seconds for the
    // intro images to load, then fades into the intro screen.
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(IntroScreen), findsOneWidget);
  });

  testWidgets('splash waits for its loading task before moving on',
      (WidgetTester tester) async {
    final loading = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          nextScreen: const Text('next screen'),
          loadTask: (context) => loading.future,
        ),
      ),
    );

    // The minimum display time has passed, but loading is still going on.
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('next screen'), findsNothing);

    // Once loading finishes, the splash moves on.
    loading.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('next screen'), findsOneWidget);
  });
}
