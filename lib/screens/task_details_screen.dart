import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../widgets/brand_logo.dart';

// Destination de selection; l'API et le contenu Details seront ajoutes a l'etape 6.
class TaskDetailsScreen extends StatelessWidget {
  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.project,
  });

  final Task task;
  final Project project;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(),
        centerTitle: true,
        toolbarHeight: 76,
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Task details',
                    style: TextStyle(color: AppColors.muted, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  // Ces informations viennent de la carte selectionnee, pas de donnees fixes.
                  Text(
                    task.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.name,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Icon(
                    Icons.assignment_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 20),
                  // Le message indique une fonction indisponible, pas une task vide de l'API.
                  const Text(
                    'Task details are not available in this version.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
