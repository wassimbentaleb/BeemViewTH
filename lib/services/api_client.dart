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

  Map<String, String> _headers(bool authenticated) {
    // Seules les routes protegees recoivent le token Bearer.
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': 'en',
      if (authenticated && token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(String path) {
    // GET sert a lire des donnees, comme le profil de l'utilisateur.
    return _readResponse(
      _client.get(_origin.resolve(path), headers: _headers(true)),
      authenticated: true,
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
    );
  }

  Future<Map<String, dynamic>> _readResponse(
    Future<http.Response> request, {
    required bool authenticated,
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
        // 401 invalide la session. 403 laisse le token intact.
        if (authenticated && response.statusCode == 401) {
          token = null;
        }
        throw ApiException.fromResponse(response.statusCode, data ?? {});
      }
      if (data == null) {
        throw const ApiException('The server returned an unexpected response.');
      }
      return data;
    } on TimeoutException {
      // Pas de retry automatique: l'utilisateur decide quand reessayer.
      throw const ApiException('The request timed out. Please try again.');
    } on http.ClientException {
      throw const ApiException(
        'Could not connect. Check your internet connection.',
      );
    }
  }

  // Le proprietaire du client libere ses connexions quand il est detruit.
  void close() => _client.close();
}
