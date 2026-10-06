import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

// Gere la session et son etat, sans connaitre les widgets ou la navigation.
class AuthController extends ChangeNotifier {
  AuthController({required this.service});

  final AuthService service;
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  // L'interface lit ces valeurs; elle ne les modifie pas directement.
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> signIn({required String email, required String password}) async {
    // Un deuxieme clic ne doit pas envoyer une autre connexion.
    if (_isLoading) return false;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      // La reponse valide rend l'utilisateur disponible dans l'interface.
      final session = await service.signIn(email: email, password: password);
      _user = session.user;
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      service.clearSession();
      return false;
    } finally {
      // Le bouton redevient disponible meme si la requete echoue.
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    // Une requete peut finir apres la destruction du controller.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // Termine les notifications du controller quand on quitte l'app.
    _disposed = true;
    super.dispose();
  }
}
