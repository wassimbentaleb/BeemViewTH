import 'package:flutter/material.dart';

import '../core/app_theme.dart';

// Les cartes partagent les memes coins, bordures et ombres dans les deux themes.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: colors.border),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (Theme.of(context).brightness == Brightness.light)
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.035),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

// Une entree courte ne se rejoue pas pendant la saisie ou un changement de theme.
class AppEntrance extends StatelessWidget {
  const AppEntrance({super.key, required this.child, this.order = 0});

  final Widget child;
  final int order;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delay = order.clamp(0, 4) * 35;
    final duration = 260 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: duration),
      child: child,
      builder: (context, value, child) {
        final progress = Interval(
          delay / duration,
          1,
          curve: Curves.easeOutCubic,
        ).transform(value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}

// Les formes de la page Login sont purement decoratives et ignorent les touches.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child, this.login = false});

  final Widget child;
  final bool login;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final lightLogin =
        login && Theme.of(context).brightness == Brightness.light;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  login ? colors.loginGradient : colors.gradient,
                  lightLogin ? const Color(0xFFF9FCFF) : colors.background,
                  lightLogin ? const Color(0xFFF3FAFF) : colors.background,
                ],
                stops: const [0, 0.48, 1],
              ),
            ),
          ),
        ),
        if (login) ...[
          Positioned(
            top: -220,
            left: -180,
            child: _circle(colors.primary.withValues(alpha: 0.13), 360),
          ),
          Positioned(
            top: 95,
            left: -125,
            child: _circle(colors.primary.withValues(alpha: 0.055), 240),
          ),
        ],
        child,
      ],
    );
  }

  Widget _circle(Color color, double size) => IgnorePointer(
    child: ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}

// Quatre emplacements gardent la structure de liste visible pendant la lecture.
class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key, required this.label, this.tasks = false});

  final String label;
  final bool tasks;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.subtle,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppEntrance(
                  order: i,
                  child: AppSurface(
                    padding: const EdgeInsets.all(16),
                    child: tasks
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FractionallySizedBox(
                                widthFactor: 0.7,
                                child: bar(double.infinity, 16),
                              ),
                              const SizedBox(height: 10),
                              bar(90, 22),
                              const SizedBox(height: 10),
                              bar(150, 12),
                            ],
                          )
                        : Row(
                            children: [
                              bar(48, 48),
                              const SizedBox(width: 16),
                              Expanded(child: bar(double.infinity, 16)),
                              const SizedBox(width: 32),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
