import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/task_details_controller.dart';
import '../core/app_theme.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/task_badges.dart';

// Charge les informations actuelles de la task choisie dans la liste.
class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.project,
    required this.service,
  });

  final Task task;
  final Project project;
  final TaskService service;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late final TaskDetailsController _details;

  @override
  void initState() {
    super.initState();
    // La lecture commence une fois a l'ouverture, sans reutiliser une ancienne fiche.
    _details = TaskDetailsController(
      service: widget.service,
      taskId: widget.task.id,
    );
    unawaited(_details.loadDetails());
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _details,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: const BrandLogo(),
          centerTitle: true,
          toolbarHeight: 76,
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
        ),
        // Le fond discret, les titres et les panneaux suivent la maquette Details.
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
                    children: _buildContent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    // Le titre et les badges viennent de la reponse Details, pas de la carte precedente.
    const label = Text(
      'Task details',
      style: TextStyle(
        color: AppColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
    if (_details.isLoading) {
      return [
        label,
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading task details',
            ),
          ),
        ),
      ];
    }
    final details = _details.details;
    if (_details.error != null || details == null) {
      return [
        label,
        const SizedBox(height: 24),
        Text(_details.error ?? 'Task details unavailable.'),
      ];
    }
    return [
      label,
      const SizedBox(height: 12),
      Text(
        details.task.name,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 16),
      TaskBadges(task: details.task, fontSize: 16),
      const SizedBox(height: 20),
      _buildPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Text(
              details.description ?? 'No description provided.',
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildPanel({required Widget child}) {
    // Les informations de la fiche utilisent le meme panneau blanc et les memes marges.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0407182F),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
