import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/task.dart';
import 'app_surface.dart';
import 'task_badges.dart';
import 'task_deadline.dart';

// Le titre et le status se lisent avant la priorite et la date plus discretes.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.now,
  });
  final Task task;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) => AppSurface(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                task.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.of(context).muted,
              size: 22,
            ),
          ],
        ),
        const SizedBox(height: 6),
        TaskStatusBadge(task: task),
        const SizedBox(height: 6),
        // La priorite reste a gauche; le delai est toujours aligne a droite.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: TaskPriority(task: task)),
            const SizedBox(width: 12),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: TaskDeadline(task: task, now: now),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
