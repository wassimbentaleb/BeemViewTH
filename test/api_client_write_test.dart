import 'dart:async';
import 'dart:convert';

import 'package:beemview/core/api_exception.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = AppConfig(subdomain: 'test-tenant');

  test('PUT sends JSON and the current bearer', () async {
    // Verifie le vrai transport partage, y compris caracteres speciaux JSON.
    final client = ApiClient(
      config: config,
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/tasks/501');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {'status': 'in_progress'});
        return http.Response('{"message":"Updated"}', 200);
      }),
    )..token = 'test-token';
    addTearDown(client.close);
    expect(await client.put('/api/tasks/501', {'status': 'in_progress'}), {
      'message': 'Updated',
    });
  });

  test('only unconfirmed writes report an unknown outcome', () async {
    // Lecture et login restent retentables; les modifications demandent une verification.
    final client = ApiClient(
      config: config,
      client: MockClient(
        (request) async => throw http.ClientException('Offline'),
      ),
    );
    addTearDown(client.close);
    for (final call in [
      client.get('/read'),
      client.post('/login', {}, authenticated: false),
    ]) {
      await expectLater(
        call,
        throwsA(
          isA<ApiException>().having((e) => e.outcomeUnknown, 'unknown', false),
        ),
      );
    }
    for (final call in [
      client.put('/write', {}),
      client.post('/comment', {}),
    ]) {
      await expectLater(
        call,
        throwsA(
          isA<ApiException>().having((e) => e.outcomeUnknown, 'unknown', true),
        ),
      );
    }
  });

  test(
    'write timeouts and unusable acknowledgements are not safe retries',
    () async {
      // Un serveur peut avoir enregistre la note avant de perdre sa reponse.
      final pending = Completer<http.Response>();
      final client = ApiClient(
        config: config,
        timeout: const Duration(milliseconds: 5),
        client: MockClient((request) => pending.future),
      );
      addTearDown(client.close);
      await expectLater(
        client.post('/comment', {}),
        throwsA(
          isA<ApiException>().having((e) => e.outcomeUnknown, 'unknown', true),
        ),
      );
      pending.complete(http.Response('{}', 201));
      for (final response in [
        http.Response('html', 200),
        http.Response('{}', 500),
      ]) {
        final other = ApiClient(
          config: config,
          client: MockClient((request) async => response),
        );
        addTearDown(other.close);
        await expectLater(
          other.put('/write', {}),
          throwsA(
            isA<ApiException>().having(
              (e) => e.outcomeUnknown,
              'unknown',
              true,
            ),
          ),
        );
      }
    },
  );
}
