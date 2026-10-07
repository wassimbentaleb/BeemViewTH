import 'package:flutter/material.dart';

import '../services/theme_store.dart';

// Le choix est commun a toutes les routes et independant de la session.
class ThemeController extends ChangeNotifier {
  ThemeController({this.store = const ThemeStore()});

  final ThemeStore store;
  ThemeMode _mode = ThemeMode.system;
  bool _isRestoring = false;
  bool _isSaving = false;
  bool _disposed = false;

  ThemeMode get mode => _mode;
  bool get isBusy => _isRestoring || _isSaving;

  Future<void> restore() async {
    _isRestoring = true;
    final mode = await store.readMode();
    if (_disposed) return;
    _mode = mode;
    _isRestoring = false;
    notifyListeners();
  }

  Future<bool> toggle(Brightness currentBrightness) async {
    if (isBusy || _disposed) return true;
    _mode = currentBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    _isSaving = true;
    notifyListeners();
    var saved = true;
    try {
      await store.saveMode(_mode);
    } catch (_) {
      // Le theme reste utilisable pour cette session si l'ecriture echoue.
      saved = false;
    } finally {
      _isSaving = false;
      if (!_disposed) notifyListeners();
    }
    return saved;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
