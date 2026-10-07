import 'package:beemview/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  // Les tests de formulaire commencent sans session et sans stockage natif reel.
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('field errors wait for blur while the user starts typing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BeemViewApp());
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);

    // Un email incomplet ne doit pas etre signale pendant sa premiere saisie.
    await tester.enterText(fields.at(0), 'c');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsNothing);
    await tester.enterText(fields.at(0), 'candidate@');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsNothing);

    // Passer au password valide l'email, sans interrompre la saisie du password.
    await tester.enterText(fields.at(1), '1');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 6 characters.'), findsNothing);
    await tester.enterText(fields.at(1), '12345');
    await tester.pumpAndSettle();
    expect(find.text('Use at least 6 characters.'), findsNothing);
    await tester.tap(fields.at(0));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 6 characters.'), findsOneWidget);

    // Les erreurs disparaissent quand les valeurs corrigees quittent leurs champs.
    await tester.enterText(fields.at(0), 'candidate@example.com');
    await tester.enterText(fields.at(1), '123456');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsNothing);
    expect(find.text('Use at least 6 characters.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid credentials stay in the form with useful errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BeemViewApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'candidate@');
    await tester.enterText(fields.at(1), '12345');
    // Sign in valide les deux champs, meme si le dernier garde le focus.
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 6 characters.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.enterText(fields.at(0), ' candidate@example.com ');
    await tester.enterText(fields.at(1), '123456');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsNothing);
    expect(find.text('Use at least 6 characters.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password toggle preserves input and compact layout can scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const BeemViewApp());
    await tester.pumpAndSettle();

    final passwordField = find.byType(TextFormField).at(1);
    await tester.ensureVisible(passwordField);
    await tester.enterText(passwordField, 'sample-password');
    await tester.pumpAndSettle();

    EditableText passwordInput() => tester.widget<EditableText>(
      find.descendant(of: passwordField, matching: find.byType(EditableText)),
    );
    expect(passwordInput().obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(passwordInput().obscureText, isFalse);
    expect(passwordInput().controller.text, 'sample-password');

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();
    expect(passwordInput().obscureText, isTrue);
    expect(passwordInput().controller.text, 'sample-password');

    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
