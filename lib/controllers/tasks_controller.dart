import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/task.dart';
import '../services/task_service.dart';

// Gere les tasks d'un seul projet; l'ecran reste responsable de leur presentation.
class TasksController extends ChangeNotifier {
  TasksController({required this.service, required this.projectId});

  final TaskService service;
  final int projectId;
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  // L'interface peut lire les tasks sans modifier directement la liste chargee.
  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTasks() async {
    // Un double clic ou un ecran ferme ne doit pas lancer une autre requete.
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final tasks = await service.fetchProjectTasks(projectId);
      if (_disposed) return;
      _tasks = tasks;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      // Une reponse tardive ne doit pas notifier apres le retour vers Projects.
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // Le controller appartient a l'ecran; le client HTTP appartient toujours a l'app.
    _disposed = true;
    super.dispose();
  }
}
