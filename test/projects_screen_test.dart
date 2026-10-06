import 'dart:async';
import 'dart:convert';

import 'package:beemview/app.dart';
import 'package:beemview/controllers/auth_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/screens/project_tasks_screen.dart';
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
  Future<http.Response> Function(http.Request) projects, {
  Future<http.Response> Function(http.Request)? tasks,
  Future<http.Response> Function(http.Request)? details,
  Future<http.Response> Function(http.Request)? writes,
}) {
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
      // Les tests Update fournissent les reponses de PUT/POST separement des lectures.
      if (request.method != 'GET') {
        if (writes != null) return writes(request);
        fail('Unexpected write ${request.method} ${request.url.path}');
      }
      // Les tests Projects peuvent ouvrir Tasks sans simuler des appels de projet en plus.
      if (request.url.path.startsWith('/api/tasks/project/')) {
        return tasks == null
            ? http.Response('{"tasks":[]}', 200)
            : tasks(request);
      }
      // Les tests de selection peuvent fournir leur propre reponse Details.
      if (RegExp(r'^/api/tasks/\d+$').hasMatch(request.url.path)) {
        final id = int.parse(request.url.path.split('/').last);
        return details == null
            ? http.Response(
                jsonEncode({
                  'task': {'id': id, 'name': 'Loaded task'},
                }),
                200,
              )
            : details(request);
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
  testWidgets(
    'project selection passes its ID and name and Back preserves the list',
    (tester) async {
      // Le second projet doit ouvrir sa propre destination sans relire la liste au retour.
      var calls = 0;
      final controller = createController((request) async {
        calls++;
        return http.Response(
          '{"data":[{"id":101,"name":"First project"},{"id":102,"name":"Second project"}],"total":2}',
          200,
        );
      });
      await tester.pumpWidget(BeemViewApp(authController: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second project'));
      await tester.pumpAndSettle();
      final screen = tester.widget<ProjectTasksScreen>(
        find.byType(ProjectTasksScreen),
      );
      expect(screen.project.id, 102);
      expect(screen.project.name, 'Second project');
      expect(calls, 1);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('First project'), findsOneWidget);
      expect(find.text('Second project'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('session expiry removes a project route from navigation', (
    tester,
  ) async {
    // Un appel Projects deja en cours peut expirer apres ouverture d'un projet.
    final nextPage = Completer<http.Response>();
    final controller = createController((request) async {
      if (request.url.queryParameters['offset'] == '1') return nextPage.future;
      return http.Response(
        '{"data":[{"id":101,"name":"Assigned project"}],"total":2}',
        200,
      );
    });
    await tester.pumpWidget(BeemViewApp(authController: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pump();
    await tester.tap(find.text('Assigned project'));
    // Deux frames lancent puis terminent la transition sans attendre le spinner HTTP.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    nextPage.complete(http.Response('{"message":"Expired"}', 401));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(ProjectTasksScreen), findsNothing);
    expect(
      Navigator.of(tester.element(find.text('Welcome back'))).canPop(),
      isFalse,
    );
    expect(await controller.store.readToken(), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'empty projects show Reload then replace the empty state on success',
    (tester) async {
      // Le format result/count du contrat est visible comme un vrai etat vide.
      var calls = 0;
      final controller = createController((request) async {
        calls++;
        return calls == 1
            ? http.Response('{"result":[],"count":0}', 200)
            : http.Response(
                '{"data":[{"id":101,"name":"Assigned project"}],"total":1}',
                200,
              );
      });
      await tester.pumpWidget(BeemViewApp(authController: controller));
      await tester.pumpAndSettle();
      expect(find.text('No projects yet'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();
      expect(find.text('Assigned project'), findsOneWidget);
      expect(find.text('No projects yet'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed pagination keeps cards and Retry loads the missing page',
    (tester) async {
      // Retry doit etre une action visible, avec les anciennes cartes toujours presentes.
      final offsets = <String>[];
      final controller = createController((request) async {
        final offset = request.url.queryParameters['offset']!;
        offsets.add(offset);
        if (offsets.length == 2) {
          return http.Response('{"message":"Try again later"}', 500);
        }
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': offset == '0' ? 101 : 102,
                'name': offset == '0' ? 'Assigned project' : 'Next project',
              },
            ],
            'total': 2,
          }),
          200,
        );
      });
      await tester.pumpWidget(BeemViewApp(authController: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Assigned project'), findsOneWidget);
      expect(find.text('Try again later'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Next project'), findsOneWidget);
      expect(find.text('Try again later'), findsNothing);
      expect(offsets, ['0', '1', '1']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('403 shows Retry and retains the session', (tester) async {
    // Acces refuse ne doit pas etre transforme en token expire.
    var calls = 0;
    final controller = createController((request) async {
      calls++;
      return calls == 1
          ? http.Response('{"message":"Access denied"}', 403)
          : http.Response(
              '{"data":[{"id":101,"name":"Assigned project"}],"total":1}',
              200,
            );
    });
    await tester.pumpWidget(BeemViewApp(authController: controller));
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
    expect(controller.user, isNotNull);
    expect(await controller.store.readToken(), 'test-token');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Assigned project'), findsOneWidget);
    expect(find.text('Access denied'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('401 on Projects returns to Login and clears the saved token', (
    tester,
  ) async {
    // L'integration verifie le callback session et le controller ferme pendant l'appel.
    final controller = createController(
      (request) async => http.Response('{"message":"Expired"}', 401),
    );
    await tester.pumpWidget(BeemViewApp(authController: controller));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
    expect(controller.user, isNull);
    expect(await controller.store.readToken(), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'load more keeps cards visible and disappears after the final page',
    (tester) async {
      // Une vraie action UI attend la seconde page et bloque un nouvel envoi.
      final secondPage = Completer<http.Response>();
      final offsets = <String>[];
      final controller = createController((request) async {
        final offset = request.url.queryParameters['offset']!;
        offsets.add(offset);
        if (offset == '1') return secondPage.future;
        return http.Response(
          '{"data":[{"id":101,"name":"Assigned project"}],"total":2}',
          200,
        );
      });
      await tester.pumpWidget(BeemViewApp(authController: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more'));
      await tester.pump();
      expect(find.text('Assigned project'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      secondPage.complete(
        http.Response(
          '{"data":[{"id":102,"name":"Next project"}],"total":2}',
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next project'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      expect(offsets, ['0', '1']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
