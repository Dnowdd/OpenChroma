import 'package:flutter/material.dart';

/// Design tokens. Neutral near-black surfaces separated by hairline borders;
/// the only saturated color in the chrome is the live effect light itself.
class Oc {
  // Surfaces, from the window background up. Graphite, slightly cool.
  static const bg = Color(0xFF0C0C0E);
  static const panel = Color(0xFF161619);
  static const raised = Color(0xFF1F1F23);
  static const hover = Color(0xFF27272C);
  static const pressed = Color(0xFF303036);

  // Lines.
  static const line = Color(0xFF232328);
  static const lineStrong = Color(0xFF34343A);

  // Text.
  static const text = Color(0xFFF2F2F4);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textTertiary = Color(0xFF6B6B74);

  // Semantic. [accent] is the fallback for the live accent (see accent.dart),
  // used when no effect is running or the effect has no clear color.
  static const accent = Color(0xFF9AA5FF);
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);

  // Type.
  static const font = 'Segoe UI Variable Text';
  static const fontDisplay = 'Segoe UI Variable Display';
  static const mono = 'Cascadia Mono';

  // Radii.
  static const r6 = BorderRadius.all(Radius.circular(8));
  static const r8 = BorderRadius.all(Radius.circular(10));
  static const r10 = BorderRadius.all(Radius.circular(16));
  static const r12 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));
  static const pill = BorderRadius.all(Radius.circular(999));

  // Page layout: content starts just right of the rail.
  static const pageInsets = EdgeInsets.fromLTRB(16, 0, 20, 24);
  static const headerInsets = EdgeInsets.fromLTRB(16, 18, 20, 22);

  /// Height of buttons, fields, selects and segmented controls.
  static const control = 36.0;

  static const fast = Duration(milliseconds: 120);
  static const smooth = Duration(milliseconds: 260);
}

/// Text styles used across the app.
class OcText {
  static const pageTitle = TextStyle(
    fontFamily: Oc.fontDisplay,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: Oc.text,
    height: 1.2,
  );
  static const title = TextStyle(
    fontFamily: Oc.fontDisplay,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: Oc.text,
  );
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Oc.text,
  );
  static const body = TextStyle(fontSize: 13, color: Oc.text, height: 1.45);
  static const secondary = TextStyle(
    fontSize: 12.5,
    color: Oc.textSecondary,
    height: 1.45,
  );
  static const caption = TextStyle(fontSize: 11.5, color: Oc.textTertiary);
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: Oc.textTertiary,
  );
  static const mono = TextStyle(
    fontFamily: Oc.mono,
    fontSize: 12,
    color: Oc.textSecondary,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Oc.text,
    onPrimary: Oc.bg,
    secondary: Oc.accent,
    surface: Oc.panel,
    onSurface: Oc.text,
    error: Oc.danger,
    outline: Oc.line,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: Oc.font,
    scaffoldBackgroundColor: Oc.bg,
    canvasColor: Oc.bg,
    dividerColor: Oc.line,
    dividerTheme: const DividerThemeData(
      color: Oc.line,
      thickness: 1,
      space: 1,
    ),
    // Desktop app: hover states instead of Material ink ripples.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Oc.hover,
    focusColor: Oc.hover,
    visualDensity: VisualDensity.compact,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Oc.text,
      selectionColor: Oc.accent.withValues(alpha: .35),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: .12)),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Oc.pressed,
        borderRadius: Oc.r6,
        border: Border.fromBorderSide(BorderSide(color: Oc.lineStrong)),
      ),
      textStyle: TextStyle(fontSize: 12, color: Oc.text),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Oc.raised,
      shape: RoundedRectangleBorder(
        borderRadius: Oc.r12,
        side: BorderSide(color: Oc.lineStrong),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Oc.raised,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: Oc.r8,
        side: BorderSide(color: Oc.lineStrong),
      ),
      textStyle: TextStyle(fontSize: 13, color: Oc.text),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 2,
      activeTrackColor: Oc.text,
      inactiveTrackColor: Oc.lineStrong,
      thumbColor: Oc.text,
      overlayColor: Colors.transparent,
      thumbShape: RoundSliderThumbShape(
        enabledThumbRadius: 6,
        elevation: 0,
        pressedElevation: 0,
      ),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
      showValueIndicator: ShowValueIndicator.never,
    ),
  );
}
