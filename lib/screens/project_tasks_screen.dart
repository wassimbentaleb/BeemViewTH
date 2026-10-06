import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/project.dart';
import '../widgets/brand_logo.dart';

// Destination de selection; le contenu des tasks sera ajoute a l'etape 5.
class ProjectTasksScreen extends StatelessWidget {
  const ProjectTasksScreen({super.key, required this.project});

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
                  // Le titre vient du projet choisi, jamais d'une valeur fixe.
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Project tasks',
                    style: TextStyle(color: AppColors.muted, fontSize: 18),
                  ),
                  const SizedBox(height: 56),
                  // Le message indique une fonction indisponible, pas une liste vide du serveur.
                  const Icon(
                    Icons.checklist_rounded,
                    color: AppColors.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Project tasks are not available in this version.',
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
