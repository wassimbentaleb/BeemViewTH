import 'dart:convert';

import 'package:beemview/core/api_exception.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = AppConfig(subdomain: 'test-tenant');

  test('project tasks use the selected ID and existing bearer without filters', () async {
    // Le test verifie le contrat HTTP reel et la normalisation de l'enveloppe.
    final client = ApiClient(
      config: config,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/tasks/project/102');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'project': {'id': 102, 'name': 'Second project'},
            'tasks': [
              {
                'id': 501,
                'name': 'Inspection',
                'status': 'review',
                'priority': 'Low',
                'dueDate': null,
              },
            ],
            'count': 1,
            'statistics': {},
          }),
          200,
        );
      }),
    )..token = 'test-token';
    addTearDown(client.close);
    final task = (await TaskService(client: client).fetchProjectTasks(102))
        .single;
    expect(task.id, 501);
    expect(task.priority, 'low');
    expect(task.dueDate, isNull);
    expect(task.statusLabel, 'Review');
  });

  test('empty tasks are valid but malformed tasks report an error', () async {
    // Distingue un vrai resultat vide d'une reponse incompletable.
    final responses = [
      {'tasks': []},
      {'count': 0},
      {
        'tasks': [null],
      },
      {
        'tasks': [
          {'id': 0},
        ],
      },
    ];
    final client = ApiClient(
      config: config,
      client: MockClient(
        (request) async =>
            http.Response(jsonEncode(responses.removeAt(0)), 200),
      ),
    );
    addTearDown(client.close);
    final service = TaskService(client: client);
    expect(await service.fetchProjectTasks(101), isEmpty);
    for (var index = 0; index < 3; index++) {
      await expectLater(
        service.fetchProjectTasks(101),
        throwsA(isA<ApiException>()),
      );
    }
    await expectLater(service.fetchProjectTasks(0), throwsArgumentError);
  });

  test('401 expires the session while 403 preserves its token', () async {
    // TaskService garde le comportement commun du client protege.
    for (final status in [403, 401]) {
      var expired = false;
      final client =
          ApiClient(
              config: config,
              client: MockClient(
                (request) async =>
                    http.Response('{"message":"Access unavailable"}', status),
              ),
            )
            ..token = 'test-token'
            ..onUnauthorized = () async {
              expired = true;
            };
      addTearDown(client.close);
      await expectLater(
        TaskService(client: client).fetchProjectTasks(101),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', status),
        ),
      );
      expect(expired, status == 401);
      expect(client.token, status == 401 ? isNull : 'test-token');
    }
  });
}
