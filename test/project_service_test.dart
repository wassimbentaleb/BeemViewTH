import 'dart:convert';

import 'package:beemview/core/api_exception.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/project_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = AppConfig(subdomain: 'test-tenant');

  test('project pages send pagination and the existing bearer token', () async {
    // La simulation verifie le vrai contrat HTTP, y compris la seconde page.
    final client = ApiClient(
      config: config,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/projects');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.url.queryParameters['limit'], '1');
        final offset = int.parse(request.url.queryParameters['offset']!);
        return http.Response(
          jsonEncode({
            'total': 2,
            'count': 1,
            'limit': 1,
            'offset': offset,
            'data': [
              {'id': 101 + offset, 'name': 'Project $offset'},
            ],
          }),
          200,
        );
      }),
    )..token = 'test-token';
    addTearDown(client.close);
    final service = ProjectService(client: client);
    final first = await service.fetchProjects(limit: 1);
    expect(first.projects.single.id, 101);
    expect(first.hasMore, isTrue);
    final last = await service.fetchProjects(
      limit: 1,
      offset: first.nextOffset,
    );
    expect(last.projects.single.id, 102);
    expect(last.nextOffset, 2);
    expect(last.hasMore, isFalse);
  });

  test('both documented empty responses stop pagination', () async {
    // Un resultat vide peut avoir result/count au lieu de data/total.
    final responses = [
      {'result': [], 'count': 0},
      {'data': [], 'total': 0, 'count': 0, 'offset': 0, 'limit': 10},
    ];
    final client = ApiClient(
      config: config,
      client: MockClient(
        (request) async =>
            http.Response(jsonEncode(responses.removeAt(0)), 200),
      ),
    );
    addTearDown(client.close);
    final service = ProjectService(client: client);
    for (var index = 0; index < 2; index++) {
      final page = await service.fetchProjects();
      expect(page.projects, isEmpty);
      expect(page.hasMore, isFalse);
    }
  });

  test('malformed project data is reported instead of shown as empty', () async {
    // Les erreurs de schema restent differentes d'un succes avec zero projets.
    final responses = [
      {'message': 'OK'},
      {
        'data': [
          {'id': 0, 'name': 'Invalid'},
        ],
        'total': 1,
      },
      {
        'data': [null],
        'total': 1,
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
    final service = ProjectService(client: client);
    for (var index = 0; index < 3; index++) {
      await expectLater(service.fetchProjects(), throwsA(isA<ApiException>()));
    }
  });

  test(
    'project requests reuse session expiry handling and preserve 403',
    () async {
      // La nouvelle route doit suivre la meme regle 401/403 que le profil.
      var status = 403;
      var expired = false;
      final client = ApiClient(
        config: config,
        client: MockClient(
          (request) async =>
              http.Response('{"message":"Access denied"}', status),
        ),
      )..token = 'test-token';
      client.onUnauthorized = () async => expired = true;
      addTearDown(client.close);
      final service = ProjectService(client: client);
      await expectLater(service.fetchProjects(), throwsA(isA<ApiException>()));
      expect(client.token, 'test-token');
      expect(expired, isFalse);
      status = 401;
      await expectLater(service.fetchProjects(), throwsA(isA<ApiException>()));
      expect(client.token, isNull);
      expect(expired, isTrue);
    },
  );
}
