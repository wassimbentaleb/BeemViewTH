import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/task.dart';
import 'app_icons.dart';

// Le status porte la couleur forte; la priorite reste une information secondaire.
class TaskBadges extends StatelessWidget {
  const TaskBadges({super.key, required this.task, this.fontSize = 13});
  final Task task;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TaskStatusBadge(task: task, fontSize: fontSize),
      TaskPriority(task: task, fontSize: fontSize),
    ],
  );
}

class TaskStatusBadge extends StatelessWidget {
  const TaskStatusBadge({super.key, required this.task, this.fontSize = 12});
  final Task task;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (task.status) {
      'in_progress' => const Color(0xFF007AC2),
      'done' => const Color(0xFF087F52),
      'blocked' => const Color(0xFFBE3545),
      'on_hold' => const Color(0xFF906200),
      'review' || 'changes_requested' => const Color(0xFF7755B5),
      _ => colors.muted,
    };
    final icon = switch (task.status) {
      'in_progress' => Icons.timelapse_rounded,
      'done' => Icons.check_circle_outline_rounded,
      'blocked' => Icons.block_rounded,
      'on_hold' => Icons.pause_circle_outline_rounded,
      'review' => Icons.visibility_outlined,
      'changes_requested' => Icons.edit_outlined,
      'canceled' => Icons.cancel_outlined,
      _ => Icons.radio_button_unchecked_rounded,
    };
    final neutral =
        !Task.statusLabels.containsKey(task.status) ||
        task.status == 'to_do' ||
        task.status == 'canceled';
    final foreground = neutral ? colors.muted : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: neutral
            ? colors.subtle
            : color.withValues(alpha: dark ? 0.85 : 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: task.status == 'in_progress'
                ? TaskProgressIcon(color: foreground)
                : Icon(icon, size: 15, color: foreground),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              task.statusLabel,
              style: TextStyle(
                color: foreground,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TaskPriority extends StatelessWidget {
  const TaskPriority({super.key, required this.task, this.fontSize = 12});
  final Task task;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (task.priority) {
      'urgent' ||
      'high' => dark ? const Color(0xFFFFA096) : const Color(0xFFBE3545),
      'medium' => dark ? const Color(0xFFFFCC70) : const Color(0xFF906200),
      _ => AppColors.of(context).muted,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(Icons.flag_rounded, size: 14, color: color),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            task.priorityLabel,
            style: TextStyle(color: color, fontSize: fontSize, height: 1.4),
          ),
        ),
      ],
    );
  }
}
