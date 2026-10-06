import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/task.dart';

// Partage les couleurs et labels de status/priorite entre liste et details.
class TaskBadges extends StatelessWidget {
  const TaskBadges({super.key, required this.task, this.fontSize = 14});

  final Task task;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Les couleurs appartiennent a l'interface, jamais au model Task.
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
    // Wrap laisse les badges passer a la ligne sur petit ecran ou grande police.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TaskBadge(
          label: task.statusLabel,
          color: statusColor,
          fontSize: fontSize,
        ),
        _TaskBadge(
          label: task.priorityLabel,
          color: priorityColor,
          fontSize: fontSize,
          showDot: true,
        ),
      ],
    );
  }
}

// Le style d'un badge reste prive; l'ecran utilise seulement TaskBadges.
class _TaskBadge extends StatelessWidget {
  const _TaskBadge({
    required this.label,
    required this.color,
    required this.fontSize,
    this.showDot = false,
  });

  final String label;
  final Color color;
  final double fontSize;
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
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
