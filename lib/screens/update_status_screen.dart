import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/update_status_controller.dart';
import '../core/app_theme.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/brand_logo.dart';

// Presente les choix et la note; le controller garde les valeurs API et les etats.
class UpdateStatusScreen extends StatefulWidget {
  const UpdateStatusScreen({
    super.key,
    required this.task,
    required this.service,
  });

  final Task task;
  final TaskService service;

  @override
  State<UpdateStatusScreen> createState() => _UpdateStatusScreenState();
}

class _UpdateStatusScreenState extends State<UpdateStatusScreen> {
  late final UpdateStatusController _update;
  final _note = TextEditingController();
  final _feedbackKey = GlobalKey();
  bool _leaving = false;

  // Cet ordre suit la maquette; les labels restent centralises dans Task.
  static const _statusOrder = [
    'to_do',
    'in_progress',
    'on_hold',
    'review',
    'changes_requested',
    'blocked',
    'done',
    'canceled',
  ];

  @override
  void initState() {
    super.initState();
    _update = UpdateStatusController(
      service: widget.service,
      task: widget.task,
    );
  }

  @override
  void dispose() {
    // Les deux controllers appartiennent a cette route, pas le client HTTP partage.
    _note.dispose();
    _update.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _update,
      builder: (context, child) => PopScope<bool>(
        // Chaque sortie renvoie si une modification est confirmee ou possible.
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              icon: const BackButtonIcon(),
              onPressed: _update.isSaving ? null : _leave,
            ),
            title: const BrandLogo(),
            centerTitle: true,
            toolbarHeight: 76,
            backgroundColor: AppColors.background,
            scrolledUnderElevation: 0,
          ),
          bottomNavigationBar: _buildSaveAction(),
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
                        const Text(
                          'Update status',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTaskHeader(),
                        const SizedBox(height: 24),
                        const Text(
                          'Choose a status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusChoices(),
                        const SizedBox(height: 24),
                        const Text(
                          'Note (optional)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Le texte reste selectionnable pour copier une note dont le resultat est incertain.
                        TextField(
                          key: const ValueKey('status-note'),
                          controller: _note,
                          onChanged: _update.setNote,
                          readOnly: !_update.canEditNote,
                          minLines: 3,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Add a note about this update',
                            labelText: 'Optional note',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your note will be added as a comment.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.muted,
                          ),
                        ),
                        if (_update.error != null) ...[
                          const SizedBox(height: 20),
                          _buildFeedback(),
                        ],
                      ],
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

  Future<void> _save() async {
    // Le controller verrouille les deux operations; la route ne ferme qu'apres confirmation.
    if (!_update.canSave || _leaving) return;
    FocusScope.of(context).unfocus();
    await _update.save();
    if (!mounted) return;
    if (_update.isComplete) {
      _leave();
    } else if (_update.error != null) {
      // Le message reste visible apres une sauvegarde depuis le bas du formulaire.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final feedback = _feedbackKey.currentContext;
        if (mounted && feedback != null) {
          unawaited(
            Scrollable.ensureVisible(
              feedback,
              duration: const Duration(milliseconds: 200),
            ),
          );
        }
      });
    }
  }

  void _leave() {
    // Bloque toolbar et retour Android pendant PUT/POST; pas de note perdue en vol.
    if (_update.isSaving || _leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pop(_update.taskChanged || _update.isNotFound);
  }

  Widget _buildSaveAction() {
    // Le bouton fixe reste accessible; la note refusee reutilise uniquement POST.
    final label = _update.isSaving
        ? (_update.statusSaved ? 'Saving comment...' : 'Saving status...')
        : (_update.statusSaved ? 'Retry comment' : 'Save status');
    return SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: FilledButton.icon(
              onPressed: _update.canSave ? () => unawaited(_save()) : null,
              icon: _update.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(label),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    // Les messages distinguent refus, succes partiel et resultat impossible a confirmer.
    final String message;
    if (_update.isNotFound) {
      message = _update.statusSaved
          ? 'Status saved, but the task could not be found when adding the note.'
          : 'Task not found. Return to details to reload.';
    } else if (_update.outcomeUnknown) {
      message = _update.statusSaved
          ? 'Status saved. We could not confirm whether your note was added. Check task details before sending it again.'
          : 'We could not confirm whether the status was saved. Check task details before trying again.';
    } else {
      message = _update.statusSaved
          ? 'Status saved. Your note was not added. Edit it or retry the comment.'
          : 'Status was not saved. Your choices and note are kept.';
    }
    return Semantics(
      key: _feedbackKey,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EC),
          border: Border.all(color: const Color(0xFFF0D7A8)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!_update.outcomeUnknown) ...[
              const SizedBox(height: 8),
              Text(
                _update.error!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
            ],
            if (_update.taskChanged || _update.isNotFound) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _leave,
                child: Text(
                  _update.outcomeUnknown
                      ? 'Check task details'
                      : (_update.isNotFound
                            ? 'Back to details'
                            : 'Return without note'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskHeader() {
    // Le status courant change seulement apres confirmation du PUT par le serveur.
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.task.name,
            style: const TextStyle(
              fontSize: 22,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current status: ${_update.currentStatusLabel}',
            style: const TextStyle(fontSize: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChoices() {
    // Wrap adapte hauteur et nombre de colonnes aux petits ecrans et grandes polices.
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            constraints.maxWidth >= 300 &&
            MediaQuery.textScalerOf(context).scale(14) <= 20;
        final width = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final status in _statusOrder)
              SizedBox(width: width, child: _buildStatusChoice(status)),
          ],
        );
      },
    );
  }

  Widget _buildStatusChoice(String status) {
    // Un seul choix est coche; InkWell rend toute la carte accessible au toucher.
    final selected = _update.selectedStatus == status;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: _update.canEditStatus,
      child: Material(
        color: selected ? const Color(0xFFEAF9FE) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: InkWell(
          key: ValueKey('status-$status'),
          borderRadius: BorderRadius.circular(12),
          onTap: _update.canEditStatus
              ? () => _update.selectStatus(status)
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 24,
                      color: selected ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      Task.statusLabels[status]!,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
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
