import 'dart:async';
import 'dart:convert';

import 'package:beemview/controllers/projects_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/project_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Le controller passe par le vrai service, seul le transport HTTP est simule.
ProjectsController createController(
  Future<http.Response> Function(http.Request) handler,
) {
  final client = ApiClient(
    config: const AppConfig(subdomain: 'test-tenant'),
    client: MockClient(handler),
  );
  addTearDown(client.close);
  return ProjectsController(service: ProjectService(client: client));
}

void main() {
  test(
    'failed initial load retries offset zero and clears the error',
    () async {
      // Une premiere erreur ne rend pas le controller inutilisable.
      final offsets = <String>[];
      final controller = createController((request) async {
        offsets.add(request.url.queryParameters['offset']!);
        return offsets.length == 1
            ? http.Response('{"message":"Temporary server error"}', 500)
            : http.Response(
                '{"data":[{"id":101,"name":"First"}],"total":1}',
                200,
              );
      });
      addTearDown(controller.dispose);
      await controller.loadProjects();
      expect(controller.error, 'Temporary server error');
      expect(controller.projects, isEmpty);
      expect(controller.isLoading, isFalse);
      await controller.loadProjects();
      expect(controller.error, isNull);
      expect(controller.projects.single.id, 101);
      expect(offsets, ['0', '0']);
    },
  );

  test('failed next page keeps projects and retries the same offset', () async {
    // L'offset ne change pas sur erreur, sinon une page serait sautee au retry.
    final offsets = <String>[];
    final controller = createController((request) async {
      final offset = request.url.queryParameters['offset']!;
      offsets.add(offset);
      if (offsets.length == 2) {
        return http.Response('{"message":"Temporary server error"}', 500);
      }
      return http.Response(
        jsonEncode({
          'data': [
            {'id': offset == '0' ? 101 : 102, 'name': 'Project'},
          ],
          'total': 2,
        }),
        200,
      );
    });
    addTearDown(controller.dispose);
    await controller.loadProjects();
    await controller.loadMore();
    expect(controller.projects.single.id, 101);
    expect(controller.hasMore, isTrue);
    expect(controller.isLoadingMore, isFalse);
    expect(controller.error, 'Temporary server error');
    await controller.loadMore();
    expect(controller.projects.map((project) => project.id), [101, 102]);
    expect(controller.error, isNull);
    expect(offsets, ['0', '1', '1']);
  });

  test('an empty next page ends pagination without clearing existing cards', () async {
    // Le total peut changer entre deux appels; une page vide termine la liste.
    var calls = 0;
    final controller = createController((request) async {
      calls++;
      return calls == 1
          ? http.Response('{"data":[{"id":101,"name":"First"}],"total":3}', 200)
          : http.Response('{"result":[],"count":0}', 200);
    });
    addTearDown(controller.dispose);
    await controller.loadProjects();
    await controller.loadMore();
    expect(controller.projects.single.id, 101);
    expect(controller.hasMore, isFalse);
    await controller.loadMore();
    expect(calls, 2);
  });

  test('pagination deduplicates IDs and advances by raw page length', () async {
    // La seconde page reste en attente pour verifier le verrou des doubles clics.
    final secondPage = Completer<http.Response>();
    final secondRequest = Completer<void>();
    final offsets = <String>[];
    final controller = createController((request) async {
      final offset = request.url.queryParameters['offset']!;
      offsets.add(offset);
      if (offset == '2') {
        secondRequest.complete();
        return secondPage.future;
      }
      return http.Response(
        jsonEncode({
          'total': 5,
          'data': offset == '0'
              ? [
                  {'id': 101, 'name': 'First'},
                  {'id': 102, 'name': 'Second'},
                ]
              : [
                  {'id': 104, 'name': 'Last'},
                ],
        }),
        200,
      );
    });
    addTearDown(controller.dispose);
    await controller.loadProjects();
    expect(controller.hasMore, isTrue);
    final loading = controller.loadMore();
    // On attend l'envoi HTTP reel avant de verifier le nombre de requetes.
    await secondRequest.future;
    await controller.loadMore();
    expect(offsets, ['0', '2']);
    expect(controller.isLoadingMore, isTrue);
    expect(controller.projects.length, 2);
    // L'ID 102 revient, mais l'offset avance de deux entrees recues, pas d'une.
    secondPage.complete(
      http.Response(
        jsonEncode({
          'total': 5,
          'data': [
            {'id': 102, 'name': 'Updated second'},
            {'id': 103, 'name': 'Third'},
          ],
        }),
        200,
      ),
    );
    await loading;
    expect(controller.projects.map((project) => project.id), [101, 102, 103]);
    expect(controller.projects[1].name, 'Updated second');
    await controller.loadMore();
    expect(offsets, ['0', '2', '4']);
    expect(controller.projects.map((project) => project.id), [
      101,
      102,
      103,
      104,
    ]);
    expect(controller.hasMore, isFalse);
    await controller.loadMore();
    expect(offsets.length, 3);
  });

  test('a late response never notifies a disposed controller', () async {
    // Quitter Projects pendant le chargement ne doit pas provoquer d'exception.
    final response = Completer<http.Response>();
    final controller = createController((request) => response.future);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final loading = controller.loadProjects();
    expect(notifications, 1);
    controller.dispose();
    response.complete(http.Response('{"data":[],"total":0}', 200));
    await loading;
    expect(notifications, 1);
  });
}
