import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/project.dart';

// La carte affiche un projet et laisse l'ecran decider de sa navigation.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.color,
    required this.highlighted,
    required this.onTap,
  });

  final Project project;
  final Color color;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Material et InkWell donnent le retour visuel et l'action accessible au clic.
    return Material(
      color: AppColors.of(context).surface,
      elevation: highlighted ? 0 : 1,
      shadowColor: AppColors.of(context).shadow.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: highlighted
              ? AppColors.of(context).primary.withValues(alpha: 0.55)
              : AppColors.of(context).subtle,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // La couleur du dossier est decorative, sans lien avec le status.
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder_outlined, color: color, size: 32),
              ),
              const SizedBox(width: 18),
              // Expanded laisse les noms longs revenir a la ligne sans deborder.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Project',
                      style: TextStyle(
                        color: AppColors.of(context).muted,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.of(context).muted,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
