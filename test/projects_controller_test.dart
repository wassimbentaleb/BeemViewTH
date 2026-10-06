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
