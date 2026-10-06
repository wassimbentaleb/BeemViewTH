import 'dart:convert';

import 'package:beemview/core/api_exception.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('comment trims outer spaces and preserves quotes and newlines', () async {
    // Le JSON garde le contenu saisi et n'envoie aucune mention ni autre champ.
    var calls = 0;
    final client = ApiClient(
      config: const AppConfig(subdomain: 'test-tenant'),
      client: MockClient((request) async {
        calls++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/tasks/comment');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {
          'task_id': 501,
          'content': 'Inspection "started"\nNext step',
          'mentioned_user_ids': [],
        });
        return http.Response(
          '{"message":"Comment added","comment":{"id":99}}',
          201,
        );
      }),
    )..token = 'test-token';
    addTearDown(client.close);
    final service = TaskService(client: client);
    await service.addComment(501, '  Inspection "started"\nNext step  ');
    await expectLater(service.addComment(0, 'Note'), throwsArgumentError);
    await expectLater(service.addComment(501, ' \n '), throwsArgumentError);
    expect(calls, 1);
  });

  test('comment failures are surfaced without hidden retries', () async {
    // Un reseau ambigu reste different d'un rejet explicite de validation/acces.
    for (final code in [400, 401, 403, 404, 429, 500]) {
      var calls = 0;
      final client = ApiClient(
        config: const AppConfig(subdomain: 'test-tenant'),
        client: MockClient((request) async {
          calls++;
          return http.Response('{"message":"Comment failed"}', code);
        }),
      )..token = 'test-token';
      addTearDown(client.close);
      await expectLater(
        TaskService(client: client).addComment(501, 'Note'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'code', code)
              .having((e) => e.outcomeUnknown, 'unknown', code >= 500),
        ),
      );
      expect(calls, 1);
      expect(client.token, code == 401 ? isNull : 'test-token');
    }
  });
}
