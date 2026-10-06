import 'project.dart';

// Une page distingue les projets recus du nombre total disponible.
class ProjectPage {
  const ProjectPage({
    required this.projects,
    required this.total,
    required this.nextOffset,
  });

  final List<Project> projects;
  final int total;
  final int nextOffset;

  // Une page vide termine le chargement, meme si un total ancien est retourne.
  bool get hasMore => projects.isNotEmpty && nextOffset < total;
}
