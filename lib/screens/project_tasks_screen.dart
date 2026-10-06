import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/tasks_controller.dart';
import '../core/app_theme.dart';
import '../models/project.dart';
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
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tasks',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${_tasks.tasks.length} tasks',
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
    if (_tasks.error != null) return Text(_tasks.error!);
    return Column(
      children: [
        for (final task in _tasks.tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TaskCard(task: task),
          ),
      ],
    );
  }
}
