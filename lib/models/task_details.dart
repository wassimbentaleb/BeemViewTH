import 'project.dart';
import 'task.dart';
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
  });

  final Task task;
  final String? description;
  final Project? project;
  final List<User> assignees;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TaskDetails.fromJson(Map<String, dynamic> json) {
    // Les associations peuvent etre absentes ou null, mais doivent garder leur type.
    final project = json['Project'];
    final assignees = json['Assignees'];
    if (project != null && project is! Map<String, dynamic>) {
      throw const FormatException('Invalid task project.');
    }
    if (assignees != null && assignees is! List) {
      throw const FormatException('Invalid task assignees.');
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
