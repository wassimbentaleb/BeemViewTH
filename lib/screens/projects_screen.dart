import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../core/app_theme.dart';
import '../widgets/brand_logo.dart';

// Accueil provisoire apres connexion. La liste Projects arrive a l'etape 4.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(),
        centerTitle: true,
        actions: [
          // La deconnexion efface le token local avant de revenir au Login.
          IconButton(
            tooltip: 'Sign out',
            onPressed: controller.isLoading ? null : controller.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Projects',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              // Le nom vient de l'utilisateur authentifie, pas de la maquette.
              Text(
                'Hello, ${controller.user!.fullName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You are signed in.',
                style: TextStyle(color: AppColors.muted, fontSize: 16),
              ),
              // Un echec du logout reste visible et peut etre retente.
              if (controller.error != null) ...[
                const SizedBox(height: 20),
                Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
