import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/date_formatter.dart';
import '../models/task.dart';
import 'app_surface.dart';
import 'task_badges.dart';

// Le titre et le status se lisent avant la priorite et la date plus discretes.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});
  final Task task;
  final VoidCallback onTap;

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
        // Wrap garde les deux informations entieres sur petit ecran/grande police.
        Wrap(
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TaskPriority(task: task),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: AppColors.of(context).muted,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    task.dueDate == null
                        ? 'No due date'
                        : 'Due ${DateFormatter.date(task.dueDate!)}',
                    style: TextStyle(
                      color: AppColors.of(context).muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
