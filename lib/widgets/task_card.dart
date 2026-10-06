import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/task.dart';

// Affiche les informations demandees pour une task de la collection API.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    // Les couleurs de presentation restent dans le widget, pas dans le model.
    final statusColor = switch (task.status) {
      'in_progress' => const Color(0xFF007AF5),
      'done' => const Color(0xFF07824F),
      'blocked' => const Color(0xFFE83232),
      'on_hold' => const Color(0xFFC18400),
      'review' || 'changes_requested' => const Color(0xFF7755B5),
      _ => AppColors.muted,
    };
    final priorityColor = switch (task.priority) {
      'urgent' => const Color(0xFFE83232),
      'high' => const Color(0xFFF48B00),
      'medium' => const Color(0xFFD49B00),
      'low' => const Color(0xFF27A980),
      _ => AppColors.muted,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0607182F),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          // Wrap laisse les badges passer a la ligne lorsque le texte est agrandi.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TaskBadge(label: task.statusLabel, color: statusColor),
              _TaskBadge(
                label: task.priorityLabel,
                color: priorityColor,
                showDot: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: AppColors.muted,
              ),
              const SizedBox(width: 10),
              // La date garde son jour de calendrier API sans conversion de fuseau horaire.
              Expanded(
                child: Text(
                  task.dueDate == null
                      ? 'No due date'
                      : 'Due ${_formatDate(task.dueDate!)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Le format anglais de la maquette ne necessite pas de package supplementaire.
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// Petit badge prive partage par status et priorite dans la carte.
class _TaskBadge extends StatelessWidget {
  const _TaskBadge({
    required this.label,
    required this.color,
    this.showDot = false,
  });

  final String label;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (showDot) const TextSpan(text: '\u25cf  '),
            TextSpan(text: label),
          ],
        ),
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
