import 'user.dart';

// La reponse de connexion utile: un token et son utilisateur.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final User user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    // Une reponse incomplete ne doit pas etre consideree comme une connexion.
    final token = json['token'];
    final user = json['user'];
    if (token is! String ||
        token.trim().isEmpty ||
        user is! Map<String, dynamic>) {
      throw const FormatException('Invalid login response.');
    }
    return AuthSession(token: token, user: User.fromJson(user));
  }
}
