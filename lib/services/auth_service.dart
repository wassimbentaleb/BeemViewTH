import '../core/api_exception.dart';
import '../core/app_config.dart';
import '../models/auth_session.dart';
import '../models/user.dart';
import 'api_client.dart';

// Connait les endpoints d'authentification, sans dependre de l'interface.
class AuthService {
  const AuthService({required this.client, required this.config});

  final ApiClient client;
  final AppConfig config;

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    // Le tenant vient de la configuration, jamais d'un troisieme champ du form.
    if (config.subdomain.trim().isEmpty) {
      throw const ApiException('App configuration is incomplete.');
    }
    // On nettoie l'email; on conserve le mot de passe exactement comme saisi.
    final response = await client.post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
      'subdomain': config.subdomain.trim(),
    }, authenticated: false);
    try {
      // Le token reste en memoire. Le stockage securise sera gere separement.
      final session = AuthSession.fromJson(response);
      client.token = session.token;
      return session;
    } on FormatException {
      throw const ApiException(
        'The server returned incomplete login information.',
      );
    }
  }

  Future<User> fetchCurrentUser(String token) async {
    // Le profil permet de verifier un token retrouve au redemarrage.
    client.token = token;
    final response = await client.get('/api/users/me/profile');
    final user = response['user'];
    if (user is! Map<String, dynamic>) {
      throw const ApiException(
        'The server returned incomplete profile information.',
      );
    }
    try {
      return User.fromJson(user);
    } on FormatException {
      throw const ApiException(
        'The server returned incomplete profile information.',
      );
    }
  }

  // Le logout local retire le token utilise par les prochaines requetes.
  void clearSession() => client.token = null;
}
