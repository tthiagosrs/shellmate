import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.isDark,
    required this.bg,
    required this.bgSidebar,
    required this.bgSurface,
    required this.accent,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.border,
    required this.divider,
  });

  final bool isDark;
  final Color bg;
  final Color bgSidebar;
  final Color bgSurface;
  final Color accent;
  final Color text1;
  final Color text2;
  final Color text3;
  final Color border;
  final Color divider;

  // Derived
  Color get accentDim => accent.withValues(alpha: 0.07);
  Color get accentSub => accent.withValues(alpha: 0.11);
  Color get accentBorder => accent.withValues(alpha: 0.27);
  Color get accentFocus => accent.withValues(alpha: 0.51);
  Color get accentGlow => accent.withValues(alpha: 0.13);
  Color get accentStrong => accent.withValues(alpha: 0.45);

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  static const dark = AppColors(
    isDark: true,
    bg: Color(0xFF0E0F13),
    bgSidebar: Color(0xFF08090D),
    bgSurface: Color(0xFF15171D),
    accent: Color(0xFF5BCEFA),
    text1: Color(0xFFE8EAF0),
    text2: Color(0xFF8B8FA8),
    text3: Color(0xFF555870),
    border: Color(0xFF2A2D36),
    divider: Color(0xFF181A22),
  );

  static const light = AppColors(
    isDark: false,
    bg: Color(0xFFF2F4FA),
    bgSidebar: Color(0xFFFFFFFF),
    bgSurface: Color(0xFFFFFFFF),
    accent: Color(0xFF1480C8),
    text1: Color(0xFF1A1B28),
    text2: Color(0xFF585C72),
    text3: Color(0xFF9EA2B8),
    border: Color(0xFFD4D8EA),
    divider: Color(0xFFE8EAF5),
  );

  @override
  AppColors copyWith({
    bool? isDark,
    Color? bg,
    Color? bgSidebar,
    Color? bgSurface,
    Color? accent,
    Color? text1,
    Color? text2,
    Color? text3,
    Color? border,
    Color? divider,
  }) =>
      AppColors(
        isDark: isDark ?? this.isDark,
        bg: bg ?? this.bg,
        bgSidebar: bgSidebar ?? this.bgSidebar,
        bgSurface: bgSurface ?? this.bgSurface,
        accent: accent ?? this.accent,
        text1: text1 ?? this.text1,
        text2: text2 ?? this.text2,
        text3: text3 ?? this.text3,
        border: border ?? this.border,
        divider: divider ?? this.divider,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      isDark: t < 0.5 ? isDark : other.isDark,
      bg: Color.lerp(bg, other.bg, t)!,
      bgSidebar: Color.lerp(bgSidebar, other.bgSidebar, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      text1: Color.lerp(text1, other.text1, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
