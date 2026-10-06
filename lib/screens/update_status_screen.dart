import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/task.dart';
import '../widgets/brand_logo.dart';

// Destination de navigation; sauvegarde et commentaire seront ajoutes a l'etape 7.
class UpdateStatusScreen extends StatelessWidget {
  const UpdateStatusScreen({super.key, required this.task});

  final Task task;

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
                    'Update status',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  // La destination recoit la version actuelle de Details, jamais l'ancienne carte.
                  Text(
                    task.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current status: ${task.statusLabel}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Icon(
                    Icons.edit_note_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 20),
                  // Le message evite de presenter une sauvegarde qui n'est pas encore disponible.
                  const Text(
                    'Status updates are not available in this version.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.muted,
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
