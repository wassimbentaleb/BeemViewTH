import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../core/app_theme.dart';
import '../widgets/brand_logo.dart';

// Attend la verification du profil ou propose une action si elle echoue.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final busy = controller.isRestoring || controller.isLoading;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(),
                  const SizedBox(height: 32),
                  // Pendant le chargement, aucun ecran protege n'est affiche.
                  if (controller.isRestoring) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text('Restoring your session…'),
                  ] else ...[
                    const Text(
                      'Session unavailable',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.error ?? 'Please try again.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 24),
                    // Retry garde le token; Sign in efface la session sur demande.
                    FilledButton(
                      onPressed: busy ? null : controller.restoreSession,
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: busy ? null : controller.signOut,
                      child: const Text('Sign in'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
