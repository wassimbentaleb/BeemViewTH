import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/date_formatter.dart';
import '../models/project.dart';
import '../models/task_details.dart';
import 'app_surface.dart';

// Les personnes et les dates restent completes, meme si le texte est agrandi.
class TaskInfoCard extends StatelessWidget {
  const TaskInfoCard({super.key, required this.details, required this.project});

  final TaskDetails details;
  final Project project;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _identityRow(
            context,
            label: 'Project',
            value: (details.project ?? project).name,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.selected,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.folder_outlined, color: colors.text, size: 22),
            ),
          ),
          const SizedBox(height: 16),
          if (details.assignees.isEmpty)
            _identityRow(
              context,
              label: 'Assigned to',
              value: 'Unassigned',
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: colors.avatar,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: colors.avatarText,
                  size: 22,
                ),
              ),
            )
          else
            for (var i = 0; i < details.assignees.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: _identityRow(
                  context,
                  label: i == 0 ? 'Assigned to' : null,
                  value: details.assignees[i].fullName.trim().isEmpty
                      ? 'User'
                      : details.assignees[i].fullName,
                  leading: ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.avatar,
                      foregroundColor: colors.avatarText,
                      child: Text(
                        details.assignees[i].fullName.trim().isEmpty
                            ? 'U'
                            : details.assignees[i].fullName
                                  .trim()
                                  .characters
                                  .first
                                  .toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final start = _dateTile(
                context,
                label: 'Start date',
                value: details.task.startedDate == null
                    ? 'No start date'
                    : DateFormatter.date(details.task.startedDate!),
              );
              final due = _dateTile(
                context,
                label: 'Due date',
                value: details.task.dueDate == null
                    ? 'No due date'
                    : DateFormatter.date(details.task.dueDate!),
                emphasized: true,
              );
              // Une colonne evite de compresser les dates sur petit ecran.
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [start, const SizedBox(height: 10), due],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: start),
                  const SizedBox(width: 10),
                  Expanded(child: due),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _identityRow(
    BuildContext context, {
    required String? label,
    required String value,
    required Widget leading,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(child: leading),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Text(
                label,
                style: TextStyle(
                  color: AppColors.of(context).muted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 3),
            ],
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _dateTile(
    BuildContext context, {
    required String label,
    required String value,
    bool emphasized = false,
  }) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 15,
                  color: emphasized ? colors.primary : colors.muted,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
