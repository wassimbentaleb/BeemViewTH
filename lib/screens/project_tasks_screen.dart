import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/tasks_controller.dart';
import '../core/app_theme.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_surface.dart';
import '../widgets/brand_logo.dart';
import '../widgets/task_card.dart';
import '../widgets/theme_toggle_button.dart';
import 'task_details_screen.dart';

// Charge les tasks du projet choisi et possede leur controller.
class ProjectTasksScreen extends StatefulWidget {
  const ProjectTasksScreen({
    super.key,
    required this.project,
    required this.service,
  });

  final Project project;
  final TaskService service;

  @override
  State<ProjectTasksScreen> createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends State<ProjectTasksScreen> {
  late final TasksController _tasks;
  final _search = TextEditingController();
  bool _openingTask = false;

  @override
  void initState() {
    super.initState();
    // Le projet determine une seule requete a l'ouverture, pas a chaque rebuild.
    _tasks = TasksController(
      service: widget.service,
      projectId: widget.project.id,
    );
    unawaited(_tasks.loadTasks());
  }

  @override
  void dispose() {
    // Le champ de recherche appartient a cet ecran, comme le controller des tasks.
    _search.dispose();
    _tasks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _tasks,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: const BrandLogo(),
          centerTitle: false,
          toolbarHeight: 56,
          backgroundColor: AppColors.of(context).background,
          scrolledUnderElevation: 0,
          actions: const [ThemeToggleButton()],
        ),
        // Le fond, le titre et les cartes reprennent la maquette Project Tasks.
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
                      // Le titre vient du projet choisi, jamais d'une valeur fixe.
                      Text(
                        widget.project.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Project tasks',
                        style: TextStyle(
                          color: AppColors.of(context).muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Le nom est cherche dans les tasks deja chargees du projet.
                      TextField(
                        controller: _search,
                        onChanged: _tasks.setQuery,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        decoration: InputDecoration(
                          hintText: 'Search tasks by name',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _tasks.query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _search.clear();
                                    _tasks.setQuery('');
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Les huit statuses restent accessibles en faisant defiler les chips.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilter(null, 'All'),
                            for (final entry in Task.statusLabels.entries)
                              _buildFilter(entry.key, entry.value),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Wrap garde le compteur lisible meme avec une grande police.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'Tasks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (!_tasks.isLoading && _tasks.error == null)
                            Text(
                              '${_tasks.visibleTasks.length} ${_tasks.visibleTasks.length == 1 ? 'task' : 'tasks'}',
                              style: TextStyle(
                                color: AppColors.of(context).muted,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppResultFade(
                        revision: (_tasks.query, _tasks.status),
                        child: _buildTasks(),
                      ),
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

  Widget _buildTasks() {
    // Les placeholders disparaissent des que la collection est disponible.
    if (_tasks.isLoading) {
      return const LoadingCards(label: 'Loading tasks', tasks: true);
    }
    // Le vide du serveur et le vide des filtres demandent des actions differentes.
    if (_tasks.error != null) {
      return Semantics(
        liveRegion: true,
        child: _buildMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load tasks',
          message: _tasks.error!,
          actionLabel: 'Retry',
          onAction: _tasks.loadTasks,
        ),
      );
    }
    if (_tasks.tasks.isEmpty) {
      return _buildMessage(
        icon: Icons.checklist_rounded,
        title: 'No tasks yet',
        message: 'This project has no tasks.',
        actionLabel: 'Reload',
        onAction: _tasks.loadTasks,
      );
    }
    if (_tasks.visibleTasks.isEmpty) {
      return _buildMessage(
        icon: Icons.search_off_rounded,
        title: 'No matching tasks',
        message: 'Try another name or status.',
        actionLabel: 'Clear filters',
        onAction: () {
          _search.clear();
          _tasks.clearFilters();
          FocusScope.of(context).unfocus();
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _tasks.visibleTasks.length; i++)
          Padding(
            key: ValueKey(_tasks.visibleTasks[i].id),
            padding: const EdgeInsets.only(bottom: 10),
            child: AppEntrance(
              key: ValueKey(_tasks.visibleTasks[i].id),
              order: i,
              child: TaskCard(
                task: _tasks.visibleTasks[i],
                onTap: () => unawaited(_openTask(_tasks.visibleTasks[i])),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilter(String? value, String label) {
    // Le controller gere la selection; ChoiceChip annonce son etat a l'accessibilite.
    final selected = _tasks.status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        // Les controllers natifs relisent la duree si la preference change.
        key: ValueKey((value, MediaQuery.disableAnimationsOf(context))),
        label: Text(label),
        tooltip: 'Filter: $label',
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => _tasks.setStatus(value),
        selectedColor: AppColors.of(context).primary,
        backgroundColor: AppColors.of(context).chip,
        labelStyle: TextStyle(
          color: selected
              ? AppColors.of(context).onPrimary
              : AppColors.of(context).text,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        side: BorderSide(
          color: selected
              ? AppColors.of(context).primary
              : AppColors.of(context).border.withValues(alpha: 0.6),
        ),
        shape: const StadiumBorder(),
        chipAnimationStyle: ChipAnimationStyle(
          selectAnimation: AnimationStyle(
            duration: AppMotion.duration(context),
            reverseDuration: AppMotion.duration(context),
          ),
          enableAnimation: AnimationStyle(
            duration: AppMotion.duration(context),
            reverseDuration: AppMotion.duration(context),
          ),
          avatarDrawerAnimation: AnimationStyle.noAnimation,
          deleteDrawerAnimation: AnimationStyle.noAnimation,
        ),
      ),
    );
  }

  Future<void> _openTask(Task task) async {
    // Un double toucher ne doit pas ouvrir deux routes de details.
    if (_openingTask || _tasks.isLoading) return;
    _openingTask = true;
    FocusScope.of(context).unfocus();
    // On transmet le bon ID, le projet et le service partage pour lire la fiche actuelle.
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(
          task: task,
          project: widget.project,
          service: widget.service,
        ),
      ),
    );
    if (!mounted) return;
    _openingTask = false;
    // Une modification recharge la collection; recherche et filtre restent dans le controller.
    if (changed == true) await _tasks.loadTasks();
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    // Les etats de lecture partagent un panneau simple avec une action explicite.
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
          AppPressScale(
            child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}
