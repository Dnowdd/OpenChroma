import 'package:flutter/material.dart';

class OcColors {
  static const background = Color(0xFF0E0E12);
  static const sidebar = Color(0xFF131318);
  static const surface = Color(0xFF1A1A21);
  static const surfaceHigh = Color(0xFF23232C);
  static const border = Color(0xFF2C2C37);
  static const accent = Color(0xFFFF3D7F);
  static const accent2 = Color(0xFF8B5CF6);
  static const text = Color(0xFFEDEDF2);
  static const textMuted = Color(0xFF9A9AA8);
  static const ok = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);

  static const accentGradient = LinearGradient(colors: [accent, accent2]);
}

ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    primary: OcColors.accent,
    secondary: OcColors.accent2,
    surface: OcColors.surface,
    onSurface: OcColors.text,
    error: OcColors.error,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: OcColors.background,
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    dividerColor: OcColors.border,
    cardTheme: const CardThemeData(
      color: OcColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: OcColors.border),
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      activeTrackColor: OcColors.accent,
      inactiveTrackColor: OcColors.border,
      thumbColor: OcColors.text,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.white
            : OcColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? OcColors.accent
            : OcColors.surfaceHigh,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: OcColors.surfaceHigh,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: OcColors.surfaceHigh,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      textStyle: TextStyle(color: OcColors.text, fontSize: 12),
    ),
  );
}
