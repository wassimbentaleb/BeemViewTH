import 'dart:async';

import 'package:beemview/core/api_exception.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final method in ['GET', 'PUT', 'POST']) {
    test(
      'a delayed $method 401 from an old token cannot expire a new session',
      () async {
        // Simule une lecture en cours, puis logout/login avant la reponse de l'ancien compte.
        final pending = Completer<http.Response>();
        var expirations = 0;
        final client =
            ApiClient(
                config: const AppConfig(subdomain: 'test-tenant'),
                client: MockClient((request) {
                  expect(request.headers['Authorization'], 'Bearer old-token');
                  return pending.future;
                }),
              )
              ..token = 'old-token'
              ..onUnauthorized = () async {
                expirations++;
              };
        addTearDown(client.close);
        final request = switch (method) {
          'PUT' => client.put('/api/tasks/501', {'status': 'done'}),
          'POST' => client.post('/api/tasks/comment', {'content': 'Note'}),
          _ => client.get('/api/projects'),
        };
        client.token = 'new-token';
        pending.complete(http.Response('{}', 401));
        await expectLater(
          request,
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 401)),
        );
        expect(client.token, 'new-token');
        expect(expirations, 0);
      },
    );
  }
}
