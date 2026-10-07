import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/project.dart';
import 'app_icons.dart';
import 'app_surface.dart';

// Le nom du projet reste la seule information principale de cette carte.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.color,
    required this.onTap,
  });
  final Project project;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppSurface(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    child: Row(
      children: [
        // Les couleurs de dossier sont decoratives, sans selection implicite.
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: ProjectFolderIcon(color: color)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            project.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.35,
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
  );
}
