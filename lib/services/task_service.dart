import '../core/api_exception.dart';
import '../models/task.dart';
import '../models/task_details.dart';
import 'api_client.dart';

// Charge la collection d'un projet avec le client et le token de la session.
class TaskService {
  const TaskService({required this.client});

  final ApiClient client;

  Future<TaskDetails> fetchTaskDetails(int taskId) async {
    // L'ID est celui de la carte choisie, sans parametre de filtre ni modification.
    if (taskId <= 0) throw ArgumentError('Task ID must be positive.');
    final response = await client.get('/api/tasks/$taskId');
    final task = response['task'];
    if (task is! Map<String, dynamic>) {
      throw const ApiException('The server returned incomplete task details.');
    }
    try {
      final details = TaskDetails.fromJson(task);
      // Une reponse pour un autre ID ne doit pas afficher la mauvaise task.
      if (details.task.id != taskId) {
        throw const FormatException('Unexpected task ID.');
      }
      return details;
    } on FormatException {
      throw const ApiException('The server returned incomplete task details.');
    }
  }

  Future<List<Task>> fetchProjectTasks(int projectId) async {
    // L'ID vient du projet selectionne; cette route n'utilise aucune pagination.
    if (projectId <= 0) throw ArgumentError('Project ID must be positive.');
    final response = await client.get('/api/tasks/project/$projectId');
    final tasks = response['tasks'];
    if (tasks is! List) {
      throw const ApiException(
        'The server returned incomplete task information.',
      );
    }
    try {
      // On lit tasks et ignore statistiques/champs supplementaires de l'enveloppe.
      return tasks.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid task.');
        }
        return Task.fromJson(item);
      }).toList();
    } on FormatException {
      // Une enveloppe incorrecte ne doit pas passer pour un projet sans tasks.
      throw const ApiException(
        'The server returned incomplete task information.',
      );
    }
  }
}
