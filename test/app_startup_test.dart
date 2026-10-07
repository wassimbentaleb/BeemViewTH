import 'dart:async';
import 'dart:convert';

import 'package:beemview/app.dart';
import 'package:beemview/controllers/auth_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/screens/login_screen.dart';
import 'package:beemview/screens/projects_screen.dart';
import 'package:beemview/screens/session_screen.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/auth_service.dart';
import 'package:beemview/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Retarde la lecture initiale sans lire le coffre du telephone.
class DelayedSessionStore extends SessionStore {
  DelayedSessionStore(this.token);

  String? token;
  final initialRead = Completer<String?>();
  int reads = 0;

  @override
  Future<String?> readToken() =>
      reads++ == 0 ? initialRead.future : Future.value(token);

  @override
  Future<void> clearToken() async => token = null;
}

AuthController startupController(
  DelayedSessionStore store,
  Future<http.Response> Function(http.Request) handler,
) {
  const config = AppConfig(subdomain: 'test-tenant');
  final client = ApiClient(config: config, client: MockClient(handler));
  final auth = AuthController(
    service: AuthService(client: client, config: config),
    store: store,
  );
  addTearDown(client.close);
  addTearDown(auth.dispose);
  return auth;
}

http.Response validProfile() => http.Response(
  jsonEncode({
    'user': {'id': 12, 'full_name': 'Startup User'},
  }),
  200,
);

void expectStartupHidden(WidgetTester tester) {
  expect(tester.binding.sendFramesToEngine, isFalse);
  expect(find.byType(SessionScreen), findsNothing);
  expect(find.byType(LoginScreen), findsNothing);
  expect(find.byType(ProjectsScreen), findsNothing);
  expect(find.text('Restoring your session…'), findsNothing);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('no saved session opens login as the first visible frame', (
    tester,
  ) async {
    final store = DelayedSessionStore(null);
    var requests = 0;
    final auth = startupController(store, (_) async {
      requests++;
      return validProfile();
    });
    await tester.pumpWidget(BeemViewApp(authController: auth));
    expectStartupHidden(tester);

    store.initialRead.complete(null);
    await tester.pumpAndSettle();
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved session stays on splash until the profile is verified', (
    tester,
  ) async {
    final store = DelayedSessionStore('test-token');
    final profile = Completer<http.Response>();
    final auth = startupController(store, (request) {
      if (request.url.path == '/api/projects') {
        return Future.value(http.Response('{"data":[],"total":0}', 200));
      }
      return profile.future;
    });
    await tester.pumpWidget(BeemViewApp(authController: auth));
    store.initialRead.complete(store.token);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expectStartupHidden(tester);
    expect(auth.user, isNull);

    profile.complete(validProfile());
    await tester.pumpAndSettle();
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(find.text('Hello, Startup User'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(SessionScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired session opens login directly and clears its token', (
    tester,
  ) async {
    final store = DelayedSessionStore('expired-token');
    final auth = startupController(
      store,
      (_) async => http.Response('{"message":"Expired"}', 401),
    );
    await tester.pumpWidget(BeemViewApp(authController: auth));
    expectStartupHidden(tester);
    store.initialRead.complete(store.token);
    await tester.pumpAndSettle();

    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);
    expect(store.token, isNull);
    expect(auth.user, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed profile check releases splash and keeps retry usable', (
    tester,
  ) async {
    final store = DelayedSessionStore('test-token');
    var profileReads = 0;
    final auth = startupController(store, (request) async {
      if (request.url.path == '/api/projects') {
        return http.Response('{"data":[],"total":0}', 200);
      }
      profileReads++;
      return profileReads == 1
          ? http.Response('{"message":"Service unavailable"}', 503)
          : validProfile();
    });
    await tester.pumpWidget(BeemViewApp(authController: auth));
    expectStartupHidden(tester);
    store.initialRead.complete(store.token);
    await tester.pumpAndSettle();

    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.text('Session unavailable'), findsOneWidget);
    expect(find.text('Service unavailable'), findsOneWidget);
    expect(store.token, 'test-token');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(profileReads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during startup releases the frame exactly once', (
    tester,
  ) async {
    final store = DelayedSessionStore(null);
    final auth = startupController(store, (_) async => validProfile());
    await tester.pumpWidget(BeemViewApp(authController: auth));
    expectStartupHidden(tester);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.sendFramesToEngine, isTrue);

    store.initialRead.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.sendFramesToEngine, isTrue);
  });
}
