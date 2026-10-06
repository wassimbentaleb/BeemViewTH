import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/tasks_controller.dart';
import '../core/app_theme.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/task_card.dart';

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
          centerTitle: true,
          toolbarHeight: 76,
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
        ),
        // Le fond, le titre et les cartes reprennent la maquette Project Tasks.
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Le titre vient du projet choisi, jamais d'une valeur fixe.
                      Text(
                        widget.project.name,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Project tasks',
                        style: TextStyle(color: AppColors.muted, fontSize: 18),
                      ),
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 8),
                      const Text(
                        'Filters apply to loaded tasks',
                        style: TextStyle(color: AppColors.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
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
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (!_tasks.isLoading && _tasks.error == null)
                            Text(
                              '${_tasks.visibleTasks.length} ${_tasks.visibleTasks.length == 1 ? 'task' : 'tasks'}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 16,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTasks(),
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
    // Le spinner disparait des que la collection complete est disponible.
    if (_tasks.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading tasks'),
        ),
      );
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
      children: [
        for (final task in _tasks.visibleTasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TaskCard(task: task),
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
        label: Text(label),
        tooltip: 'Filter: $label',
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => _tasks.setStatus(value),
        selectedColor: AppColors.primary,
        backgroundColor: const Color(0xFFF4F7FC),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.text,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : AppColors.border.withValues(alpha: 0.6),
        ),
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    // Les etats de lecture partagent un panneau simple avec une action explicite.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 36, color: AppColors.muted),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
