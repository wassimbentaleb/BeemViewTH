import 'dart:async';
import 'dart:convert';

import 'package:beemview/app.dart';
import 'package:beemview/controllers/auth_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/auth_service.dart';
import 'package:beemview/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Une session simulee permet de tester Projects dans le vrai arbre de l'app.
AuthController createController(
  Future<http.Response> Function(http.Request) projects,
) {
  const config = AppConfig(subdomain: 'test-tenant');
  FlutterSecureStorage.setMockInitialValues({
    'beemview_auth_token': 'test-token',
  });
  final client = ApiClient(
    config: config,
    client: MockClient((request) async {
      if (request.url.path == '/api/users/me/profile') {
        return http.Response('{"user":{"id":12,"full_name":"Test User"}}', 200);
      }
      expect(request.url.path, '/api/projects');
      return projects(request);
    }),
  );
  final controller = AuthController(
    service: AuthService(client: client, config: config),
    store: const SessionStore(),
  );
  addTearDown(client.close);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  testWidgets('projects show loading then real API names', (tester) async {
    // La reponse reste en attente pour observer le chargement de l'interface.
    final response = Completer<http.Response>();
    final controller = createController((request) => response.future);
    await tester.pumpWidget(BeemViewApp(authController: controller));
    await tester.pump();
    await tester.pump();
    expect(find.text('Hello, Test User'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(
      http.Response(
        jsonEncode({
          'data': [
            {'id': 101, 'name': 'Assigned project'},
            {'id': 102, 'name': 'Second project'},
          ],
          'total': 2,
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Assigned project'), findsOneWidget);
    expect(find.text('Second project'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('long project names fit a small screen with enlarged text', (
    tester,
  ) async {
    // Une carte doit grandir plutot que deborder sur les petits telephones.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const name =
        'A project with a very long name for the assigned construction site';
    final controller = createController(
      (request) async => http.Response(
        jsonEncode({
          'data': [
            {'id': 101, 'name': name},
          ],
          'total': 1,
        }),
        200,
      ),
    );
    await tester.pumpWidget(BeemViewApp(authController: controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(name));
    expect(find.text(name), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
