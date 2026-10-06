import 'dart:convert';

import 'package:beemview/core/api_exception.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/models/task.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'each documented status sends only status to the selected task',
    () async {
      // Les valeurs API restent exactes; le service n'envoie aucun autre champ.
      var calls = 0;
      final client = ApiClient(
        config: const AppConfig(subdomain: 'test-tenant'),
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/tasks/501');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(jsonDecode(request.body), {
            'status': Task.statusLabels.keys.elementAt(calls++),
          });
          return http.Response(
            '{"message":"Task updated","task":{"id":501}}',
            200,
          );
        }),
      )..token = 'test-token';
      addTearDown(client.close);
      final service = TaskService(client: client);
      for (final status in Task.statusLabels.keys) {
        await service.updateStatus(501, status);
      }
      await expectLater(service.updateStatus(0, 'done'), throwsArgumentError);
      await expectLater(service.updateStatus(501, 'Done'), throwsArgumentError);
      expect(calls, 8);
    },
  );

  test(
    'status errors preserve validation HTTP codes and session behavior',
    () async {
      // Un refus explicite est retentable; un 5xx peut cacher une ecriture appliquee.
      for (final code in [400, 401, 403, 404, 429, 500]) {
        var expired = false;
        final client =
            ApiClient(
                config: const AppConfig(subdomain: 'test-tenant'),
                client: MockClient(
                  (request) async => http.Response(
                    '{"message":"Status failed","details":[{"message":"Invalid value"}]}',
                    code,
                  ),
                ),
              )
              ..token = 'test-token'
              ..onUnauthorized = () async {
                expired = true;
              };
        addTearDown(client.close);
        await expectLater(
          TaskService(client: client).updateStatus(501, 'done'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'code', code)
                .having(
                  (e) => e.message,
                  'message',
                  'Status failed Invalid value',
                )
                .having((e) => e.outcomeUnknown, 'unknown', code >= 500),
          ),
        );
        expect(expired, code == 401);
        expect(client.token, code == 401 ? isNull : 'test-token');
      }
    },
  );
}
