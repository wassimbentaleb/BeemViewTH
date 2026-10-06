import 'dart:convert';

import 'package:beemview/core/api_exception.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  // Le client HTTP simule permet de tester le contrat sans compte reel.
  const config = AppConfig(subdomain: 'test-tenant');

  test('login maps the user and restores the profile with a bearer token', () async {
    var requestCount = 0;
    final client = ApiClient(
      config: config,
      client: MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          // La connexion envoie les trois champs attendus, sans token existant.
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/login');
          expect(request.headers['Authorization'], isNull);
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {
            'email': 'candidate@example.com',
            'password': ' sample-password ',
            'subdomain': 'test-tenant',
          });
          return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {'id': 12, 'full_name': 'Candidate', 'email': null},
              'permissions': [],
            }),
            200,
          );
        }
        // La restauration lit l'enveloppe user sur une route protegee.
        expect(request.method, 'GET');
        expect(request.url.path, '/api/users/me/profile');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'user': {'id': 12, 'full_name': 'Candidate', 'extra_field': true},
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);
    final service = AuthService(client: client, config: config);

    final session = await service.signIn(
      email: ' candidate@example.com ',
      password: ' sample-password ',
    );
    expect(session.user.id, 12);
    expect(session.user.fullName, 'Candidate');
    expect(session.user.email, isNull);
    expect(client.token, 'test-token');

    final restoredUser = await service.fetchCurrentUser(session.token);
    expect(restoredUser.id, session.user.id);
    expect(requestCount, 2);
  });

  test(
    'forbidden access keeps the token while an expired session clears it',
    () async {
      var statusCode = 403;
      final client = ApiClient(
        config: config,
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'message': statusCode == 403 ? 'Access denied' : 'Token expired',
            }),
            statusCode,
          ),
        ),
      );
      addTearDown(client.close);
      final service = AuthService(client: client, config: config);

      await expectLater(
        service.fetchCurrentUser('test-token'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'status', 403)
              .having((error) => error.message, 'message', 'Access denied'),
        ),
      );
      expect(client.token, 'test-token');

      // Un acces refuse n'est pas une expiration de session.
      statusCode = 401;
      await expectLater(
        service.fetchCurrentUser('test-token'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(client.token, isNull);
    },
  );
}
