import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/session_store.dart';

// Gere la session et son etat, sans connaitre les widgets ou la navigation.
class AuthController extends ChangeNotifier {
  AuthController({required this.service, required this.store}) {
    // Toutes les futures routes protegees utilisent le meme traitement du 401.
    service.client.onUnauthorized = _expireSession;
  }

  final AuthService service;
  final SessionStore store;
  User? _user;
  bool _isLoading = false;
  bool _isRestoring = false;
  bool _restoreFailed = false;
  String? _error;
  bool _disposed = false;

  // L'interface lit ces valeurs; elle ne les modifie pas directement.
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isRestoring => _isRestoring;
  bool get restoreFailed => _restoreFailed;
  String? get error => _error;

  Future<bool> signIn({required String email, required String password}) async {
    // Un deuxieme clic ne doit pas envoyer une autre connexion.
    if (_isLoading || _isRestoring) return false;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      // L'utilisateur devient connecte apres la reponse ET la sauvegarde du token.
      final session = await service.signIn(email: email, password: password);
      await store.saveToken(session.token);
      _user = session.user;
      _restoreFailed = false;
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      service.clearSession();
      return false;
    } on Exception {
      // Un echec du stockage ne doit pas etre affiche comme une connexion reussie.
      _error = 'Could not save your session. Please try again.';
      service.clearSession();
      return false;
    } finally {
      // Le bouton redevient disponible meme si la requete echoue.
      _isLoading = false;
      _notify();
    }
  }

  Future<void> restoreSession() async {
    // Pendant cette verification, on n'affiche pas encore de contenu protege.
    if (_isLoading || _isRestoring) return;
    _isRestoring = true;
    _restoreFailed = false;
    _error = null;
    _notify();
    try {
      // Le profil vient du serveur; un token trouve seul ne suffit pas.
      final token = await store.readToken();
      if (token != null && token.isNotEmpty) {
        _user = await service.fetchCurrentUser(token);
      }
    } on ApiException catch (error) {
      // Le callback a deja efface une session expiree (401).
      // Une panne reseau ou un 403 garde le token pour un nouvel essai explicite.
      if (error.statusCode != 401) {
        _restoreFailed = true;
        _error = error.message;
        service.clearSession();
      }
    } on Exception {
      _restoreFailed = true;
      _error = 'Could not read your saved session. Please try again.';
      service.clearSession();
    } finally {
      _isRestoring = false;
      _notify();
    }
  }

  Future<void> _expireSession() async {
    // Un 401 protege retire tout de suite l'acces aux ecrans connectes.
    // Bloque aussi une nouvelle connexion tant que l'ancien token est efface.
    _isLoading = true;
    _user = null;
    service.clearSession();
    _error = 'Your session has expired. Please sign in again.';
    _restoreFailed = false;
    _notify();
    try {
      await store.clearToken();
    } on Exception {
      // Si l'effacement echoue, on propose un nouvel essai sans rendre l'acces.
      _restoreFailed = true;
      _error = 'Could not clear your expired session. Please try again.';
    } finally {
      _isLoading = false;
    }
    _notify();
  }

  void _notify() {
    // Une requete peut finir apres la destruction du controller.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // Le client ne doit plus appeler un controller detruit.
    _disposed = true;
    service.client.onUnauthorized = null;
    super.dispose();
  }
}
