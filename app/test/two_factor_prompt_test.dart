import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wealth_tracker/presentation/widgets/two_factor_prompt.dart';

Widget _harness(TwoFactorPrompt prompt) => MaterialApp(home: Scaffold(body: prompt));

void main() {
  group('TwoFactorPrompt', () {
    testWidgets('shows what the broker said about the code', (tester) async {
      await tester.pumpWidget(_harness(TwoFactorPrompt(
        accountName: 'Swisscard',
        twoFaType: 'sms',
        challenge: 'Enter the code sent to +41 79 ***',
        onSubmit: (_) async => null,
      )));

      expect(find.text('Code for Swisscard'), findsOneWidget);
      expect(find.text('Enter the code sent to +41 79 ***'), findsOneWidget);
    });

    testWidgets('falls back to wording for the factor type', (tester) async {
      await tester.pumpWidget(_harness(TwoFactorPrompt(
        accountName: 'Swisscard',
        twoFaType: 'sms',
        onSubmit: (_) async => null,
      )));

      expect(find.textContaining('by SMS'), findsOneWidget);
    });

    testWidgets('submits the entered code and closes on success',
        (tester) async {
      String? submitted;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => TwoFactorPrompt(
                  accountName: 'Swisscard',
                  twoFaType: 'sms',
                  onSubmit: (code) async {
                    submitted = code;
                    return null;
                  },
                ),
              ),
              child: const Text('open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(submitted, '123456');
      expect(find.byType(TwoFactorPrompt), findsNothing);
    });

    testWidgets('keeps the dialog open and shows why a code was refused',
        (tester) async {
      await tester.pumpWidget(_harness(TwoFactorPrompt(
        accountName: 'Swisscard',
        twoFaType: 'sms',
        onSubmit: (_) async => 'That SMS code was not accepted.',
      )));

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('That SMS code was not accepted.'), findsOneWidget);
      expect(find.byType(TwoFactorPrompt), findsOneWidget);
    });

    testWidgets('shows a spinner on the button while the code is checked',
        (tester) async {
      final checking = Completer<String?>();
      await tester.pumpWidget(_harness(TwoFactorPrompt(
        accountName: 'Swisscard',
        twoFaType: 'sms',
        onSubmit: (_) => checking.future,
      )));

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Confirm'));
      await tester.pump();

      expect(find.text('Checking…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      checking.complete('That SMS code was not accepted.');
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('refuses an empty code without calling the broker',
        (tester) async {
      var called = false;
      await tester.pumpWidget(_harness(TwoFactorPrompt(
        accountName: 'Swisscard',
        twoFaType: 'sms',
        onSubmit: (_) async {
          called = true;
          return null;
        },
      )));

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('Enter the code.'), findsOneWidget);
    });
  });
}
