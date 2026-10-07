import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/task_details_controller.dart';
import '../core/app_theme.dart';
import '../core/date_formatter.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/task_comment.dart';
import '../services/task_service.dart';
import '../widgets/app_surface.dart';
import '../widgets/brand_logo.dart';
import '../widgets/task_badges.dart';
import '../widgets/task_info_card.dart';
import '../widgets/theme_toggle_button.dart';
import 'update_status_screen.dart';

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
  bool _openingStatus = false;
  bool _taskChanged = false;
  bool _leaving = false;

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
      builder: (context, child) => PopScope<bool>(
        // Toolbar et retour Android transmettent le meme signal a la liste Tasks.
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _backToTasks();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _backToTasks),
            title: const BrandLogo(),
            centerTitle: false,
            toolbarHeight: 56,
            backgroundColor: AppColors.of(context).background,
            scrolledUnderElevation: 0,
            actions: const [ThemeToggleButton()],
          ),
          // Le fond discret, les titres et les panneaux suivent la maquette Details.
          bottomNavigationBar: _buildStatusAction(),
          body: AppBackdrop(
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: AppEntrance(
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
        ),
      ),
    );
  }

  Widget? _buildStatusAction() {
    // L'action n'est disponible qu'apres une lecture reussie de la fiche actuelle.
    if (_details.isLoading ||
        _details.error != null ||
        _details.details == null) {
      return null;
    }
    return SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: FilledButton.icon(
              onPressed: () => unawaited(_openStatus()),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Update status'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStatus() async {
    // Un double toucher ne doit pas ouvrir deux destinations.
    final task = _details.details?.task;
    if (_openingStatus ||
        _details.isLoading ||
        _details.error != null ||
        task == null) {
      return;
    }
    _openingStatus = true;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            UpdateStatusScreen(task: task, service: widget.service),
      ),
    );
    if (!mounted) return;
    _openingStatus = false;
    // Une ecriture confirmee/possible ou une task disparue demande une fiche fraiche.
    if (changed == true) {
      _taskChanged = true;
      await _details.loadDetails();
    }
  }

  void _backToTasks() {
    // Le signal reste vrai meme si le GET suivant echoue; la liste doit aussi se rafraichir.
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pop(_taskChanged);
  }

  List<Widget> _buildContent() {
    // Le titre et les badges viennent de la reponse Details, pas de la carte precedente.
    final label = Text(
      'Task details',
      style: TextStyle(
        color: AppColors.of(context).muted,
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
      return [label, const SizedBox(height: 24), _buildError()];
    }
    return [
      label,
      const SizedBox(height: 12),
      Text(
        details.task.name,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 16),
      TaskBadges(task: details.task),
      const SizedBox(height: 20),
      _buildPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              details.description ?? 'No description provided.',
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      TaskInfoCard(details: details, project: widget.project),
      const SizedBox(height: 14),
      _buildComment(details.latestComment),
    ];
  }

  Widget _buildError() {
    // 404 propose le retour a la liste; les autres echecs de lecture permettent Retry.
    final missing = _details.isNotFound;
    return Semantics(
      liveRegion: true,
      child: _buildPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              missing
                  ? Icons.assignment_late_outlined
                  : Icons.cloud_off_outlined,
              color: AppColors.of(context).muted,
              size: 36,
            ),
            const SizedBox(height: 16),
            Text(
              missing ? 'Task not found' : 'Could not load task details',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _details.error ?? 'Task details unavailable.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.of(context).muted,
              ),
            ),
            const SizedBox(height: 20),
            if (missing)
              FilledButton.icon(
                onPressed: _backToTasks,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to tasks'),
              )
            else ...[
              FilledButton.icon(
                onPressed: _details.loadDetails,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _backToTasks,
                child: const Text('Back to tasks'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComment(TaskComment? comment) {
    // Un seul commentaire est affiche: le plus recent parmi ceux retournes par l'API.
    return _buildPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Latest comment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (comment == null)
            Text(
              'No comments available.',
              style: TextStyle(
                color: AppColors.of(context).muted,
                fontSize: 14,
                height: 1.5,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(comment.authorName, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        comment.authorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      if (comment.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          DateFormatter.timestamp(comment.createdAt!),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.of(context).muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              comment.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, {required double radius}) {
    // Assignees et auteur du commentaire partagent le meme avatar a initiale.
    final text = name.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.of(context).avatar,
      foregroundColor: AppColors.of(context).avatarText,
      child: Text(
        text.isEmpty ? '?' : text.characters.first.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  // Les panneaux partagent les memes marges que les nouvelles cartes.
  Widget _buildPanel({required Widget child}) => AppSurface(child: child);
}
