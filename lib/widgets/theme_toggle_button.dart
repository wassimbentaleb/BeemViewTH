import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';

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
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
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
    );
  }
}
