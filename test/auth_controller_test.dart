import 'dart:async';
import 'dart:convert';

import 'package:beemview/controllers/auth_controller.dart';
import 'package:beemview/core/api_exception.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/auth_service.dart';
import 'package:beemview/services/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig(subdomain: 'test-tenant');
  const store = SessionStore();

  // Le plugin simule teste les lectures/ecritures sans utiliser le coffre du PC.
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('login ignores duplicate submissions and saves token', () async {
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
      store: store,
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

    // Le succes rend l'utilisateur disponible et garde seulement le token.
    expect(await signIn, isTrue);
    expect(requestCount, 1);
    expect(controller.isLoading, isFalse);
    expect(controller.user?.id, 12);
    expect(await store.readToken(), 'test-token');
  });

  test(
    '403 preserves saved session, retry restores it, 401 expires it',
    () async {
      var statusCode = 403;
      final client = ApiClient(
        config: config,
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              statusCode == 200
                  ? {
                      'user': {'id': 12, 'full_name': 'Candidate'},
                    }
                  : {'message': 'Access denied'},
            ),
            statusCode,
          ),
        ),
      );
      final controller = AuthController(
        service: AuthService(client: client, config: config),
        store: store,
      );
      addTearDown(client.close);
      addTearDown(controller.dispose);

      // Un acces refuse propose Retry et ne detruit pas la session sauvegardee.
      await store.saveToken('test-token');
      await controller.restoreSession();
      expect(controller.user, isNull);
      expect(controller.restoreFailed, isTrue);
      expect(controller.error, 'Access denied');
      expect(await store.readToken(), 'test-token');

      // Le nouvel essai valide le token grace au profil courant.
      statusCode = 200;
      await controller.restoreSession();
      expect(controller.user?.fullName, 'Candidate');
      expect(controller.restoreFailed, isFalse);
      expect(controller.error, isNull);

      // N'importe quelle route protegee en 401 efface la session et l'utilisateur.
      statusCode = 401;
      await expectLater(
        client.get('/api/protected-test'),
        throwsA(isA<ApiException>()),
      );
      expect(controller.user, isNull);
      expect(controller.restoreFailed, isFalse);
      expect(controller.error, contains('expired'));
      expect(client.token, isNull);
      expect(await store.readToken(), isNull);
    },
  );
}
