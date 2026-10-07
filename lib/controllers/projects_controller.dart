import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/project.dart';
import '../services/project_service.dart';

// Gere les donnees de Projects sans connaitre ses widgets.
class ProjectsController extends ChangeNotifier {
  ProjectsController({required this.service});

  // Cinq projets gardent Load more accessible sur le telephone de reference.
  static const pageSize = 5;

  final ProjectService service;
  List<Project> _projects = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _nextOffset = 0;
  String? _error;
  bool _disposed = false;

  // La liste est en lecture seule pour que l'interface ne modifie pas l'etat.
  List<Project> get projects => List.unmodifiable(_projects);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  // Le premier chargement et son retry repartent de l'offset zero.
  Future<void> loadProjects() => _loadPage(append: false);

  Future<void> loadMore() async {
    // Une liste complete ne doit plus provoquer de requete supplementaire.
    if (!_hasMore) return;
    await _loadPage(append: true);
  }

  Future<void> _loadPage({required bool append}) async {
    // Les deux actions partagent un verrou pour eviter les doubles requetes.
    if (_isLoading || _isLoadingMore || _disposed) return;
    _isLoading = !append;
    _isLoadingMore = append;
    _error = null;
    _notify();
    try {
      final page = await service.fetchProjects(
        limit: pageSize,
        offset: append ? _nextOffset : 0,
      );
      if (_disposed) return;
      // La cle ID garde l'ordre et remplace un doublon par sa version recente.
      final byId = {
        for (final project in append ? _projects : <Project>[])
          project.id: project,
      };
      for (final project in page.projects) {
        byId[project.id] = project;
      }
      _projects = byId.values.toList();
      // On avance uniquement apres succes, selon le nombre recu par le service.
      _nextOffset = page.nextOffset;
      _hasMore = page.hasMore;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      // Une reponse tardive ne doit pas notifier un ecran deja ferme.
      _isLoading = false;
      _isLoadingMore = false;
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
