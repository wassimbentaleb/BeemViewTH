import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/task.dart';
import '../services/task_service.dart';

// Orchestre deux ecritures separees; ne confond jamais status et commentaire.
class UpdateStatusController extends ChangeNotifier {
  UpdateStatusController({required this.service, required this.task})
    : _selectedStatus = Task.statusLabels.containsKey(task.status)
          ? task.status
          : null;

  final TaskService service;
  final Task task;
  String? _selectedStatus;
  String _note = '';
  String? _savedStatus;
  String? _error;
  int? _errorStatus;
  bool _isSaving = false;
  bool _outcomeUnknown = false;
  bool _isComplete = false;
  bool _disposed = false;

  // Ces valeurs permettent a l'ecran d'afficher succes partiel et actions possibles.
  String? get selectedStatus => _selectedStatus;
  String get note => _note;
  String? get error => _error;
  bool get isSaving => _isSaving;
  bool get statusSaved => _savedStatus != null;
  bool get outcomeUnknown => _outcomeUnknown;
  bool get isComplete => _isComplete;
  bool get isNotFound => _errorStatus == 404;
  bool get taskChanged => statusSaved || outcomeUnknown;
  String get currentStatusLabel =>
      Task.statusLabels[_savedStatus ?? task.status] ?? task.statusLabel;

  // Un status confirme n'est jamais renvoye pendant Retry du commentaire.
  bool get canEditStatus => canEditNote && !statusSaved;
  bool get canEditNote =>
      !_disposed &&
      !_isSaving &&
      !_outcomeUnknown &&
      !_isComplete &&
      !isNotFound;
  bool get canSave =>
      canEditNote &&
      _selectedStatus != null &&
      (!statusSaved || _note.trim().isNotEmpty);

  void selectStatus(String status) {
    // Le label est visuel; seule la cle documentee est conservee pour l'API.
    if (!canEditStatus || _selectedStatus == status) return;
    if (!Task.statusLabels.containsKey(status)) {
      throw ArgumentError('Unknown task status.');
    }
    _selectedStatus = status;
    _notify();
  }

  void setNote(String note) {
    // Le texte reste editable apres un rejet explicite du commentaire.
    if (!canEditNote || _note == note) return;
    _note = note;
    _notify();
  }

  Future<void> save() async {
    // Le verrou est pose avant le premier await: meme deux appels directs n'envoient rien deux fois.
    if (!canSave) return;
    final status = _selectedStatus!;
    final content = _note.trim();
    _isSaving = true;
    _error = null;
    _errorStatus = null;
    _notify();
    try {
      if (!statusSaved) {
        await service.updateStatus(task.id, status);
        if (_disposed) return;
        _savedStatus = status;
        _notify();
      }
      // Une note vide saute POST. Une note refusee reprend ici, sans refaire PUT.
      if (content.isNotEmpty) {
        await service.addComment(task.id, content);
        if (_disposed) return;
      }
      _isComplete = true;
    } on ApiException catch (error) {
      if (_disposed) return;
      _error = error.message;
      _errorStatus = error.statusCode;
      // Une reponse perdue impose une lecture de verification, sans retry de cette ecriture.
      _outcomeUnknown = error.outcomeUnknown;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // Une session expiree peut fermer la route pendant l'appel; aucune note ne part ensuite.
    _disposed = true;
    super.dispose();
  }
}
