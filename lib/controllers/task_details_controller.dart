import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/task_details.dart';
import '../services/task_service.dart';

// Charge les details d'une seule task sans connaitre leur presentation.
class TaskDetailsController extends ChangeNotifier {
  TaskDetailsController({required this.service, required this.taskId});

  final TaskService service;
  final int taskId;
  TaskDetails? _details;
  bool _isLoading = false;
  String? _error;
  int? _errorStatus;
  bool _disposed = false;

  // L'ecran lit les resultats et les etats sans les modifier directement.
  TaskDetails? get details => _details;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isNotFound => _errorStatus == 404;

  Future<void> loadDetails() async {
    // Les appels simultanes et les requetes apres fermeture sont bloques.
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _error = null;
    _errorStatus = null;
    _notify();
    try {
      final details = await service.fetchTaskDetails(taskId);
      if (_disposed) return;
      _details = details;
    } on ApiException catch (error) {
      if (_disposed) return;
      _error = error.message;
      _errorStatus = error.statusCode;
    } finally {
      // Une reponse tardive ne notifie jamais un ecran deja ferme.
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // Le client reste partage avec l'app; seul ce controller est libere ici.
    _disposed = true;
    super.dispose();
  }
}
