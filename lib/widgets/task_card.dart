import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/date_formatter.dart';
import '../models/task.dart';
import 'task_badges.dart';

// Affiche les informations demandees pour une task de la collection API.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // La carte annonce son action et affiche un retour visuel au toucher.
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: AppColors.text.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Le titre grandit sur plusieurs lignes en laissant la fleche visible.
                  Expanded(
                    child: Text(
                      task.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                    size: 26,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Les memes badges sont reutilises dans l'ecran Details.
              TaskBadges(task: task),
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
                          : 'Due ${DateFormatter.date(task.dueDate!)}',
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
        ),
      ),
    );
  }
}
