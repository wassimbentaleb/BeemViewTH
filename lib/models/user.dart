// Les informations utilisateur dont l'application a besoin.
class User {
  const User({required this.id, required this.fullName, this.email});

  final int id;
  final String fullName;
  final String? email;

  factory User.fromJson(Map<String, dynamic> json) {
    // L'API nomme le champ full_name; le code Dart utilise fullName.
    final id = json['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('Invalid user ID.');
    }
    final fullName = json['full_name'];
    final email = json['email'];
    // Les champs facultatifs peuvent etre absents ou null.
    return User(
      id: id,
      fullName: fullName is String && fullName.trim().isNotEmpty
          ? fullName
          : 'User',
      email: email is String ? email : null,
    );
  }
}
