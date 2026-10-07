import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';
import '../core/app_theme.dart';
import 'app_motion.dart';

// Le scope reste au-dessus du Navigator pour partager le choix entre les routes.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.circular = false});

  final bool circular;

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return AppPressScale(
      enabled: !controller.isBusy,
      child: IconButton(
        tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
        style: IconButton.styleFrom(
          foregroundColor: circular
              ? AppColors.of(context).primary
              : AppColors.of(context).text,
          backgroundColor: circular ? AppColors.of(context).surface : null,
          shape: circular ? const CircleBorder() : null,
          fixedSize: circular ? const Size.square(40) : null,
          elevation: circular ? 3 : 0,
          shadowColor: circular
              ? AppColors.of(context).shadow.withValues(alpha: 0.1)
              : null,
        ),
        icon: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          child: Icon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            key: ValueKey(dark),
            size: circular ? 20 : 22,
          ),
        ),
        onPressed: controller.isBusy
            ? null
            : () async {
                final saved = await controller.toggle(brightness);
                if (!saved && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Theme changed. Could not save your preference for next time.',
                      ),
                    ),
                  );
                }
              },
      ),
    );
  }
}
