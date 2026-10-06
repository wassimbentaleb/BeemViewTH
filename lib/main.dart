import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  // Initialise les plugins avant de lire le stockage securise.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BeemViewApp());
}
