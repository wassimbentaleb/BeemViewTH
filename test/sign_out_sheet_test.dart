import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beemview/app.dart';
import 'package:beemview/controllers/auth_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/auth_service.dart';
import 'package:beemview/services/session_store.dart';
import 'package:beemview/widgets/sign_out_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Controle l'effacement pour observer le loading et un echec du coffre local.
class ControlledSessionStore extends SessionStore {
  String? token = 'test-token';
  int clears = 0;
  Future<void> Function()? onClear;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> clearToken() async {
    clears++;
    await onClear?.call();
    token = null;
  }
}

AuthController createAuth(
  ControlledSessionStore store, {
  String name = 'Nour Ben Ali',
  String? email = 'nour@example.com',
  VoidCallback? onProjectRead,
}) {
  const config = AppConfig(subdomain: 'test-tenant');
  final client = ApiClient(
    config: config,
    client: MockClient((request) async {
      if (request.url.path == '/api/users/me/profile') {
        return http.Response(
          jsonEncode({
            'user': {'id': 12, 'full_name': name, 'email': email},
          }),
          200,
        );
      }
      expect(request.method, 'GET');
      expect(request.url.path, '/api/projects');
      onProjectRead?.call();
      return http.Response('{"data":[],"total":0}', 200);
    }),
  );
  final auth = AuthController(
    service: AuthService(client: client, config: config),
    store: store,
  );
  addTearDown(auth.dispose);
  addTearDown(client.close);
  return auth;
}

Future<void> openAccount(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  await tester.pump();
  expect(tester.getSemantics(find.byTooltip('Account')).label, 'Account');
  semantics.dispose();
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
  expect(find.byType(SignOutSheet), findsOneWidget);
}

// Les previews utilisent des comptes fictifs et restent dans build, ignore par Git.
Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  const output = String.fromEnvironment('DESIGN_PREVIEW_DIR');
  if (output.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Cancel and outside dismissal keep the account and projects', (
    tester,
  ) async {
    final store = ControlledSessionStore();
    var reads = 0;
    final auth = createAuth(store, onProjectRead: () => reads++);
    await tester.pumpWidget(BeemViewApp(authController: auth));
    await tester.pumpAndSettle();
    await openAccount(tester);
    expect(find.text('Nour Ben Ali'), findsOneWidget);
    expect(find.text('nour@example.com'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(SignOutSheet), findsNothing);
    await openAccount(tester);
    await tester.tapAt(const Offset(8, 40));
    await tester.pumpAndSettle();
    expect(find.byType(SignOutSheet), findsNothing);
    expect(auth.user?.id, 12);
    expect(auth.service.client.token, 'test-token');
    expect(store.token, 'test-token');
    expect(store.clears, 0);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending sign out blocks repeat taps, Cancel, Back and barrier', (
    tester,
  ) async {
    final cleared = Completer<void>();
    final store = ControlledSessionStore()..onClear = () => cleared.future;
    final auth = createAuth(store);
    await tester.pumpWidget(BeemViewApp(authController: auth));
    await tester.pumpAndSettle();
    await openAccount(tester);
    final confirm = find.byKey(const ValueKey('confirm-sign-out'));
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pump();
    expect(store.clears, 1);
    expect(store.token, 'test-token');
    expect(find.text('Signing out…'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Cancel'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.tapAt(const Offset(8, 40));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SignOutSheet), findsOneWidget);
    cleared.complete();
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(SignOutSheet), findsNothing);
    expect(auth.user, isNull);
    expect(auth.service.client.token, isNull);
    expect(store.token, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hello, Nour Ben Ali'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a storage failure keeps the session and offers an inline retry',
    (tester) async {
      final store = ControlledSessionStore()
        ..onClear = () async => throw Exception('Storage unavailable');
      final auth = createAuth(store, email: null);
      await tester.pumpWidget(BeemViewApp(authController: auth));
      await tester.pumpAndSettle();
      await openAccount(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SignOutSheet),
          matching: find.text(
            'Could not clear your session. Please try again.',
          ),
        ),
        findsOneWidget,
      );
      expect(auth.user?.id, 12);
      expect(auth.service.client.token, 'test-token');
      expect(store.token, 'test-token');
      expect(store.clears, 1);
      store.onClear = null;
      await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
      await tester.pumpAndSettle();
      expect(store.clears, 2);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final mode in [Brightness.light, Brightness.dark]) {
    testWidgets('sign out fits the phone and enlarged text in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 802);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 32, bottom: 16);
      tester.platformDispatcher.platformBrightnessTestValue = mode;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final font = FontLoader('PlusJakartaSans')
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final store = ControlledSessionStore();
      final auth = createAuth(store);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: BeemViewApp(authController: auth),
        ),
      );
      await tester.pumpAndSettle();
      await openAccount(tester);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(find.text('Sign out').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'sign-out-${mode.name}');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 480);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pump();
      // La route n'a aucune transition quand les animations sont reduites.
      final sheetContext = tester.element(find.byType(SignOutSheet));
      expect(ModalRoute.of(sheetContext)!.animation!.value, 1);
      final confirm = find.byKey(const ValueKey('confirm-sign-out'));
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(confirm.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.clears, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
