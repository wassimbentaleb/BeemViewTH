import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/task.dart';
import 'app_icons.dart';

// Le status porte la couleur forte; la priorite reste une information secondaire.
class TaskBadges extends StatelessWidget {
  const TaskBadges({super.key, required this.task, this.fontSize = 12});
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
  const TaskStatusBadge({super.key, required this.task, this.fontSize = 11});
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                ? TaskProgressIcon(color: foreground, size: 12)
                : Icon(icon, size: 12, color: foreground),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              task.statusLabel,
              style: TextStyle(
                color: foreground,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1.2,
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
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (task.priority) {
      'urgent' => dark ? const Color(0xFFFF9AAE) : const Color(0xFFE66A82),
      'high' => dark ? const Color(0xFFFFB39F) : const Color(0xFFED806D),
      'medium' => dark ? const Color(0xFFFFD45D) : const Color(0xFFF0B429),
      'low' => dark ? const Color(0xFF82DDCB) : const Color(0xFF3AB6A2),
      _ => colors.muted,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          // Les accents restent vifs; le texte neutre garde une lecture discrete.
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withValues(alpha: dark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.flag_rounded, size: 13, color: color),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            task.priorityLabel,
            style: TextStyle(
              color: colors.muted,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
