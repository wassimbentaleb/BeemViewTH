import 'dart:async';
import 'dart:convert';

import 'package:beemview/app.dart';
import 'package:beemview/controllers/auth_controller.dart';
import 'package:beemview/core/app_config.dart';
import 'package:beemview/services/api_client.dart';
import 'package:beemview/services/auth_service.dart';
import 'package:beemview/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'login keeps input on API failure then opens the session on retry',
    (tester) async {
      // L'API attend notre reponse pour verifier le vrai etat de chargement du form.
      FlutterSecureStorage.setMockInitialValues({});
      const config = AppConfig(subdomain: 'test-tenant');
      var response = Completer<http.Response>();
      final client = ApiClient(
        config: config,
        client: MockClient((request) {
          // L'accueil lit sa propre liste apres la reponse de connexion.
          if (request.url.path == '/api/projects') {
            return Future.value(http.Response('{"data":[],"total":0}', 200));
          }
          return response.future;
        }),
      );
      final controller = AuthController(
        service: AuthService(client: client, config: config),
        store: const SessionStore(),
      );
      addTearDown(client.close);
      addTearDown(controller.dispose);
      await tester.pumpWidget(BeemViewApp(authController: controller));
      await tester.pumpAndSettle();

      // Pendant la connexion, ni les champs ni le bouton ne permettent un autre envoi.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'candidate@example.com');
      await tester.enterText(fields.at(1), '123456');
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(tester.widget<TextFormField>(fields.at(0)).enabled, isFalse);

      // L'erreur serveur reste visible et la saisie est conservee pour corriger/reessayer.
      response.complete(
        http.Response('{"message":"Invalid credentials"}', 401),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invalid credentials'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'candidate@example.com',
      );
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller!.text,
        '123456',
      );

      // Un succes ouvre l'accueil avec le nom reel; le logout revient au formulaire vide.
      response = Completer<http.Response>();
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      response.complete(
        http.Response(
          jsonEncode({
            'token': 'test-token',
            'user': {'id': 12, 'full_name': 'Test User'},
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello, Test User'), findsOneWidget);
      // La deconnexion reste accessible depuis l'avatar de la maquette.
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
