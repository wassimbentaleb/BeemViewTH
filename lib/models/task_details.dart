import 'project.dart';
import 'task.dart';
import 'task_comment.dart';
import 'user.dart';

// Complete la task commune avec les informations retournees par la route Details.
class TaskDetails {
  const TaskDetails({
    required this.task,
    this.description,
    this.project,
    this.assignees = const [],
    this.createdAt,
    this.updatedAt,
    this.comments = const [],
  });

  final Task task;
  final String? description;
  final Project? project;
  final List<User> assignees;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<TaskComment> comments;

  List<TaskComment> get commentsNewestFirst {
    // La date trie les commentaires; l'index conserve l'ordre des dates egales/absentes.
    final entries = comments.indexed.toList();
    entries.sort((a, b) {
      final firstDate = a.$2.createdAt;
      final secondDate = b.$2.createdAt;
      if (firstDate == null && secondDate != null) return 1;
      if (firstDate != null && secondDate == null) return -1;
      if (firstDate != null && secondDate != null) {
        final order = secondDate.compareTo(firstDate);
        if (order != 0) return order;
      }
      return a.$1.compareTo(b.$1);
    });
    return List.unmodifiable(entries.map((entry) => entry.$2));
  }

  factory TaskDetails.fromJson(Map<String, dynamic> json) {
    // Les associations peuvent etre absentes ou null, mais doivent garder leur type.
    final project = json['Project'];
    final assignees = json['Assignees'];
    final comments = json['Comments'];
    if (project != null && project is! Map<String, dynamic>) {
      throw const FormatException('Invalid task project.');
    }
    if (assignees != null && assignees is! List) {
      throw const FormatException('Invalid task assignees.');
    }
    if (comments != null && comments is! List) {
      throw const FormatException('Invalid task comments.');
    }
    return TaskDetails(
      // Le meme model normalise status, priorite et dates pour liste et details.
      task: Task.fromJson(json),
      description: _text(json['description']),
      project: project == null ? null : Project.fromJson(project),
      assignees: List.unmodifiable(
        (assignees as List? ?? []).map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid assignee.');
          }
          return User.fromJson(item);
        }),
      ),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      // On conserve seulement les commentaires retournes, pas un historique complet.
      comments: List.unmodifiable(
        (comments as List? ?? []).map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid task comment.');
          }
          return TaskComment.fromJson(item);
        }),
      ),
    );
  }

  // Les informations facultatives restent null plutot que d'inventer des valeurs.
  static String? _text(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static DateTime? _date(dynamic value) {
    final text = _text(value);
    return text == null ? null : DateTime.tryParse(text);
  }
}
