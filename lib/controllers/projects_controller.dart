import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/project.dart';
import '../services/project_service.dart';

// Gere les donnees de Projects sans connaitre ses widgets.
class ProjectsController extends ChangeNotifier {
  ProjectsController({required this.service});

  final ProjectService service;
  List<Project> _projects = [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  // La liste est en lecture seule pour que l'interface ne modifie pas l'etat.
  List<Project> get projects => List.unmodifiable(_projects);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProjects() async {
    // Un seul chargement peut etre en cours, meme si plusieurs clics arrivent.
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final page = await service.fetchProjects();
      if (_disposed) return;
      _projects = page.projects;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      // Une reponse tardive ne doit pas notifier un ecran deja ferme.
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // L'ecran possede ce controller; le client HTTP reste celui de l'app.
    _disposed = true;
    super.dispose();
  }
}
