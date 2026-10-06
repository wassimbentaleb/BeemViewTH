// Les informations du projet utiles a la liste et a la navigation.
class Project {
  const Project({required this.id, required this.name});

  final int id;
  final String name;

  factory Project.fromJson(Map<String, dynamic> json) {
    // Un ID positif permet ensuite d'ouvrir le bon projet dans l'API.
    final id = json['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('Invalid project ID.');
    }

    // Un nom absent ne casse pas la liste; les autres champs sont ignores.
    final name = json['name'];
    return Project(
      id: id,
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Untitled project',
    );
  }
}
