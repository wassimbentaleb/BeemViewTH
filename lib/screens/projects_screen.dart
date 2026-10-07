import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../controllers/projects_controller.dart';
import '../core/app_theme.dart';
import '../models/project.dart';
import '../services/project_service.dart';
import '../services/task_service.dart';
import '../widgets/app_surface.dart';
import '../widgets/brand_logo.dart';
import '../widgets/project_card.dart';
import '../widgets/theme_toggle_button.dart';
import 'project_tasks_screen.dart';

// Affiche les projets du compte connecte et possede leur controller.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.controller,
    required this.service,
    required this.taskService,
  });

  final AuthController controller;
  final ProjectService service;
  final TaskService taskService;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final ProjectsController _projects;
  bool _openingProject = false;

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
          centerTitle: false,
          toolbarHeight: 56,
          backgroundColor: AppColors.of(context).background,
          scrolledUnderElevation: 0,
          actions: [
            const ThemeToggleButton(),
            // L'avatar ouvre le menu du compte et conserve la deconnexion locale.
            Padding(
              padding: const EdgeInsets.only(right: 12),
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
                  radius: 18,
                  backgroundColor: AppColors.of(context).avatar,
                  foregroundColor: AppColors.of(context).avatarText,
                  child: Text(initial.toUpperCase()),
                ),
              ),
            ),
          ],
        ),
        // Le fond discret et les espacements reprennent la maquette Projects.
        body: AppBackdrop(
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Hello, $name',
                        style: TextStyle(
                          color: AppColors.of(context).muted,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Projects',
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose a project to view its tasks.',
                        style: TextStyle(
                          color: AppColors.of(context).muted,
                          fontSize: 14,
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

  Future<void> _openProject(Project project) async {
    // Un double clic ne doit pas empiler deux fois le meme ecran.
    if (_openingProject || widget.controller.isLoading) return;
    _openingProject = true;
    // Le projet type transporte son ID et son nom sans refaire un appel API.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            ProjectTasksScreen(project: project, service: widget.taskService),
      ),
    );
    if (mounted) _openingProject = false;
  }

  Widget _buildProjects() {
    // Une copie stable sert aux cartes et a leurs callbacks pendant ce rebuild.
    final projects = _projects.projects;
    // Les placeholders remplacent les cartes uniquement au premier chargement.
    if (_projects.isLoading) {
      return const LoadingCards(label: 'Loading projects');
    }
    if (_projects.error != null && projects.isEmpty) {
      // Un echec initial propose un nouvel essai de la premiere page.
      return Semantics(
        liveRegion: true,
        child: _buildMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load projects',
          message: _projects.error!,
          onRetry: _projects.loadProjects,
        ),
      );
    }
    if (projects.isEmpty) {
      // Zero projet est un resultat valide; Reload permet de verifier un nouvel acces.
      return _buildMessage(
        icon: Icons.folder_off_outlined,
        title: 'No projects yet',
        message: 'You do not have any accessible projects.',
        onRetry: _projects.loadProjects,
        actionLabel: 'Reload',
      );
    }
    // Les couleurs sont decoratives; les noms et IDs viennent toujours de l'API.
    final colors = [
      AppColors.of(context).primary,
      AppColors.of(context).amber,
      const Color(0xFF9480DC),
      const Color(0xFF27A980),
    ];
    return Column(
      children: [
        for (var index = 0; index < projects.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppEntrance(
              key: ValueKey(projects[index].id),
              order: index,
              child: ProjectCard(
                project: projects[index],
                color: colors[index % colors.length],
                onTap: () => unawaited(_openProject(projects[index])),
              ),
            ),
          ),
        // La page suivante conserve les cartes et desactive le bouton pendant l'appel.
        if (_projects.error != null)
          // Un echec de pagination conserve les cartes et le meme offset pour Retry.
          Semantics(
            liveRegion: true,
            child: _buildMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load more projects',
              message: _projects.error!,
              onRetry: _projects.loadMore,
            ),
          )
        else if (_projects.hasMore) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _projects.isLoadingMore ? null : _projects.loadMore,
            iconAlignment: IconAlignment.end,
            icon: _projects.isLoadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(_projects.isLoadingMore ? 'Loading...' : 'Load more'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              foregroundColor: AppColors.of(context).primary,
              side: BorderSide(color: AppColors.of(context).primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onRetry,
    String actionLabel = 'Retry',
  }) {
    // Les etats vide et erreur partagent un petit panneau lisible avec une action.
    return AppSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 36, color: AppColors.of(context).muted),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: AppColors.of(context).muted,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
