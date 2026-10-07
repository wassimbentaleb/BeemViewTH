import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Une cle distincte conserve le theme meme apres une deconnexion.
class ThemeStore {
  const ThemeStore({this.storage = const FlutterSecureStorage()});

  final FlutterSecureStorage storage;
  static const themeKey = 'beemview_theme_mode';

  Future<ThemeMode> readMode() async {
    try {
      return switch (await storage.read(key: themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Un stockage indisponible ne doit pas empecher le demarrage.
      return ThemeMode.system;
    }
  }

  Future<void> saveMode(ThemeMode mode) =>
      storage.write(key: themeKey, value: mode.name);
}
