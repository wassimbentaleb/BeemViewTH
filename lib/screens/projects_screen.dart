import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../controllers/projects_controller.dart';
import '../core/app_theme.dart';
import '../models/project.dart';
import '../services/project_service.dart';
import '../widgets/brand_logo.dart';

// Affiche les projets du compte connecte et possede leur controller.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.controller,
    required this.service,
  });

  final AuthController controller;
  final ProjectService service;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final ProjectsController _projects;

  @override
  void initState() {
    super.initState();
    // La premiere page se charge une seule fois a l'ouverture de cet ecran.
    _projects = ProjectsController(service: widget.service);
    unawaited(_projects.loadProjects());
  }

  @override
  void dispose() {
    _projects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // La session peut expirer pendant un appel; on evite de forcer user non-null.
    final name = widget.controller.user?.fullName ?? 'User';
    final initial = name.trim().isEmpty ? 'U' : name.trim().characters.first;
    return ListenableBuilder(
      listenable: _projects,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: const BrandLogo(),
          centerTitle: true,
          toolbarHeight: 76,
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
          actions: [
            // L'avatar ouvre le menu du compte et conserve la deconnexion locale.
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: PopupMenuButton<String>(
                tooltip: 'Account',
                enabled: !widget.controller.isLoading,
                onSelected: (action) {
                  if (action == 'sign_out') {
                    unawaited(widget.controller.signOut());
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'sign_out', child: Text('Sign out')),
                ],
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFE8EDF5),
                  foregroundColor: AppColors.text,
                  child: Text(initial.toUpperCase()),
                ),
              ),
            ),
          ],
        ),
        // Le fond discret et les espacements reprennent la maquette Projects.
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF3FBFE), AppColors.background],
              stops: [0, 0.5],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Projects',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Hello, $name',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose a project to view its tasks.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      // Une erreur de logout reste visible sans effacer les projets.
                      if (widget.controller.error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          widget.controller.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _buildProjects(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjects() {
    // Le spinner remplace les cartes uniquement pendant le premier chargement.
    if (_projects.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading projects'),
        ),
      );
    }
    if (_projects.error != null) {
      return Text(_projects.error!);
    }
    // Les couleurs sont decoratives; les noms et IDs viennent toujours de l'API.
    const colors = [AppColors.primary, Color(0xFF00B88D), AppColors.amber];
    return Column(
      children: [
        for (var index = 0; index < _projects.projects.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProjectCard(
              project: _projects.projects[index],
              color: colors[index % colors.length],
              highlighted: index == 0,
            ),
          ),
      ],
    );
  }
}

// Une carte laisse le nom se repartir sur plusieurs lignes si necessaire.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.color,
    required this.highlighted,
  });

  final Project project;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: highlighted ? 0 : 1,
      shadowColor: AppColors.text.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.55)
              : const Color(0xFFE8EDF5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // L'icone de dossier utilise une teinte legere comme dans la reference.
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.folder_outlined, color: color, size: 32),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Project',
                    style: TextStyle(color: AppColors.muted, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
