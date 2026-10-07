import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_exception.dart';
import '../core/app_config.dart';

// Point commun pour les requetes HTTP et leurs erreurs.
class ApiClient {
  ApiClient({
    required AppConfig config,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _origin = config.origin,
       _client = client ?? http.Client();

  final Uri _origin;
  final http.Client _client;
  final Duration timeout;
  String? token;
  // Le controller efface aussi le stockage quand une route signale un 401.
  Future<void> Function()? onUnauthorized;

  Map<String, String> _headers(bool authenticated) {
    // Seules les routes protegees recoivent le token Bearer.
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': 'en',
      if (authenticated && token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    // Uri encode les parametres; les appels sans pagination restent identiques.
    final uri = _origin.resolve(path);
    return _readResponse(
      _client.get(
        queryParameters == null
            ? uri
            : uri.replace(queryParameters: queryParameters),
        headers: _headers(true),
      ),
      authenticated: true,
      sessionToken: token,
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) {
    // POST envoie un objet JSON. La connexion est une route publique.
    return _readResponse(
      _client.post(
        _origin.resolve(path),
        headers: _headers(authenticated),
        body: jsonEncode(body),
      ),
      authenticated: authenticated,
      sessionToken: authenticated ? token : null,
      isWrite: authenticated,
    );
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    // PUT partage JSON, Bearer, timeout et gestion de session avec les lectures.
    return _readResponse(
      _client.put(
        _origin.resolve(path),
        headers: _headers(true),
        body: jsonEncode(body),
      ),
      authenticated: true,
      sessionToken: token,
      isWrite: true,
    );
  }

  Future<Map<String, dynamic>> _readResponse(
    Future<http.Response> request, {
    required bool authenticated,
    required String? sessionToken,
    bool isWrite = false,
  }) async {
    // Le delai couvre la requete et la lecture de sa reponse.
    try {
      final response = await request.timeout(timeout);
      Map<String, dynamic>? data;
      // Les reponses utiles sont des objets JSON, pas des listes ou du HTML.
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } on FormatException {
        // Une panne de serveur/proxy peut renvoyer du HTML au lieu de JSON.
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Un ancien 401 ne doit pas effacer un nouveau token obtenu pendant l'appel.
        // Le 401 du token courant invalide la session; 403 la conserve toujours.
        if (authenticated &&
            response.statusCode == 401 &&
            token == sessionToken) {
          token = null;
          await onUnauthorized?.call();
        }
        throw ApiException.fromResponse(
          response.statusCode,
          data ?? {},
          // Un 5xx peut arriver apres une modification deja appliquee au serveur.
          outcomeUnknown: isWrite && response.statusCode >= 500,
        );
      }
      if (data == null) {
        throw ApiException(
          'The server returned an unexpected response.',
          outcomeUnknown: isWrite,
        );
      }
      return data;
    } on TimeoutException {
      // Pas de retry automatique: l'utilisateur decide quand reessayer.
      throw ApiException(
        'The request timed out. Please try again.',
        outcomeUnknown: isWrite,
      );
    } on http.ClientException {
      throw ApiException(
        'Could not connect. Check your internet connection.',
        outcomeUnknown: isWrite,
      );
    }
  }

  // Le proprietaire du client libere ses connexions quand il est detruit.
  void close() => _client.close();
}
