import '../core/api_exception.dart';
import '../models/project.dart';
import '../models/project_page.dart';
import 'api_client.dart';

// Lit les projets accessibles avec le meme client que la session.
class ProjectService {
  const ProjectService({required this.client});

  final ApiClient client;

  Future<ProjectPage> fetchProjects({int limit = 10, int offset = 0}) async {
    // Les arguments viennent du controller, pas de texte saisi dans l'interface.
    if (limit <= 0 || offset < 0) {
      throw ArgumentError(
        'Limit must be positive and offset cannot be negative.',
      );
    }
    final response = await client.get(
      '/api/projects',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );

    // Le contrat utilise une autre enveloppe quand aucun projet n'est visible.
    final result = response['result'];
    if (result is List && result.isEmpty && response['count'] == 0) {
      return ProjectPage(projects: const [], total: 0, nextOffset: offset);
    }

    // Une reponse mal formee doit afficher une erreur, pas une fausse liste vide.
    final data = response['data'];
    final total = response['total'];
    if (data is! List || total is! int || total < 0) {
      throw const ApiException(
        'The server returned incomplete project information.',
      );
    }
    try {
      final projects = data.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid project.');
        }
        return Project.fromJson(item);
      }).toList();
      // L'offset avance du nombre recu, avant toute suppression des doublons.
      return ProjectPage(
        projects: projects,
        total: total,
        nextOffset: offset + projects.length,
      );
    } on FormatException {
      throw const ApiException(
        'The server returned incomplete project information.',
      );
    }
  }
}
