import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/theme_controller.dart';

Future<void> main() async {
  // Initialise les plugins avant de lire le stockage securise.
  WidgetsFlutterBinding.ensureInitialized();
  // Lit le theme avant la premiere frame pour eviter un flash au demarrage.
  final theme = ThemeController();
  await theme.restore();
  runApp(BeemViewApp(themeController: theme));
}
