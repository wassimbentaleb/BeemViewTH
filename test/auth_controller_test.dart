import 'dart:async';
import 'dart:convert';

import 'package:beemview/controllers/auth_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig(subdomain: 'test-tenant');

  test('login ignores duplicate submissions and opens the session', () async {
    final response = Completer<http.Response>();
    var requestCount = 0;
    final client = ApiClient(
      config: config,
      client: MockClient((request) {
        requestCount++;
        return response.future;
      }),
    );
    final controller = AuthController(
      service: AuthService(client: client, config: config),
    );
    addTearDown(client.close);
    addTearDown(controller.dispose);

    // La premiere requete reste en attente; une autre soumission est ignoree.
    final signIn = controller.signIn(
      email: 'candidate@example.com',
      password: '123456',
    );
    expect(controller.isLoading, isTrue);
    expect(controller.user, isNull);
    expect(
      await controller.signIn(
        email: 'candidate@example.com',
        password: '123456',
      ),
      isFalse,
    );
    response.complete(
      http.Response(
        jsonEncode({
          'token': 'test-token',
          'user': {'id': 12, 'full_name': 'Candidate'},
        }),
        200,
      ),
    );

    // Le succes rend l'utilisateur disponible pour l'interface.
    expect(await signIn, isTrue);
    expect(requestCount, 1);
    expect(controller.isLoading, isFalse);
    expect(controller.user?.id, 12);
    expect(client.token, 'test-token');
  });
}
