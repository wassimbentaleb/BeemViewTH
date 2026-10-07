import 'package:flutter/material.dart';

// Les couleurs de chaque surface suivent la luminosite du theme actif.
class AppColors {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.amber,
    required this.text,
    required this.muted,
    required this.background,
    required this.surface,
    required this.border,
    required this.subtle,
    required this.chip,
    required this.gradient,
    required this.loginGradient,
    required this.selected,
    required this.warning,
    required this.warningBorder,
    required this.avatar,
    required this.avatarText,
    required this.shadow,
  });

  final Color primary;
  final Color onPrimary;
  final Color amber;
  final Color text;
  final Color muted;
  final Color background;
  final Color surface;
  final Color border;
  final Color subtle;
  final Color chip;
  final Color gradient;
  final Color loginGradient;
  final Color selected;
  final Color warning;
  final Color warningBorder;
  final Color avatar;
  final Color avatarText;
  final Color shadow;

  static const light = AppColors(
    primary: Color(0xFF00A7D3),
    onPrimary: Colors.white,
    amber: Color(0xFFFFA000),
    text: Color(0xFF07182F),
    muted: Color(0xFF727C96),
    background: Color(0xFFFCFDFE),
    surface: Colors.white,
    border: Color(0xFFD7DFEC),
    subtle: Color(0xFFE8EDF5),
    chip: Color(0xFFF4F7FC),
    gradient: Color(0xFFF3FBFE),
    loginGradient: Color(0xFFF0FAFE),
    selected: Color(0xFFEAF9FE),
    warning: Color(0xFFFFF8EC),
    warningBorder: Color(0xFFF0D7A8),
    avatar: Color(0xFFDDF4FC),
    avatarText: Color(0xFF007AF5),
    shadow: Color(0xFF07182F),
  );

  static const dark = AppColors(
    primary: Color(0xFF52D5F4),
    onPrimary: Color(0xFF072B36),
    amber: Color(0xFFFFBB4D),
    text: Color(0xFFE8EEF8),
    muted: Color(0xFFA4B2C8),
    background: Color(0xFF0D1422),
    surface: Color(0xFF172235),
    border: Color(0xFF34435A),
    subtle: Color(0xFF202D43),
    chip: Color(0xFF202D43),
    gradient: Color(0xFF112C3A),
    loginGradient: Color(0xFF112C3A),
    selected: Color(0xFF183E50),
    warning: Color(0xFF332A1C),
    warningBorder: Color(0xFF7A6036),
    avatar: Color(0xFF183D50),
    avatarText: Color(0xFF7CB8FF),
    shadow: Colors.black,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class AppTheme {
  static final light = _build(Brightness.light, AppColors.light);
  static final dark = _build(Brightness.dark, AppColors.dark);

  // Une meme configuration garde les champs, boutons et polices coherents.
  static ThemeData _build(Brightness brightness, AppColors colors) => ThemeData(
    useMaterial3: true,
    brightness: brightness,
    visualDensity: VisualDensity.standard,
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: colors.background,
    colorScheme: ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: colors.primary,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      surface: colors.surface,
      onSurface: colors.text,
      onSurfaceVariant: colors.muted,
      outline: colors.border,
      outlineVariant: colors.border,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      hintStyle: TextStyle(color: colors.muted),
      prefixIconColor: colors.muted,
      suffixIconColor: colors.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorMaxLines: 2,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
