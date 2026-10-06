import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Seul le token est sauvegarde; le mot de passe reste dans le formulaire.
class SessionStore {
  const SessionStore({this.storage = const FlutterSecureStorage()});

  final FlutterSecureStorage storage;
  static const tokenKey = 'beemview_auth_token';

  // Au demarrage, on cherche une session deja enregistree.
  Future<String?> readToken() => storage.read(key: tokenKey);

  // On attend la sauvegarde avant d'afficher l'espace connecte.
  Future<void> saveToken(String token) =>
      storage.write(key: tokenKey, value: token);

  // Le logout et l'expiration retirent uniquement la cle de cette session.
  Future<void> clearToken() => storage.delete(key: tokenKey);
}
