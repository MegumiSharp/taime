import 'package:flutter/material.dart';

import 'palette.dart';

const double kRadius = 22;

ThemeData buildTheme(List<int> palette, {required bool dark}) {
  final accent = Color(accentFor(palette.first, dark: dark));
  final bg = Color(backgroundFor(palette, dark: dark, level: 0));
  final card = Color(backgroundFor(palette, dark: dark, level: 1));
  final raised = Color(backgroundFor(palette, dark: dark, level: 2));
  final onBg = dark ? const Color(0xFFE8E6E1) : const Color(0xFF2B2A26);
  final muted = onBg.withValues(alpha: 0.55);
  final outline = onBg.withValues(alpha: 0.10);

  final scheme =
      ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: Color(onColor(accent.toARGB32())),
        secondary: Color(
          accentFor(palette.length > 1 ? palette[1] : palette.first, dark: dark),
        ),
        onSecondary: onBg,
        error: Color(accentFor(0xFFE05252, dark: dark)),
        onError: dark ? Colors.black : Colors.white,
        surface: card,
        onSurface: onBg,
        surfaceContainerHighest: raised,
        onSurfaceVariant: muted,
        outline: outline,
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme().apply(
      bodyColor: onBg,
      displayColor: onBg,
      fontFamily: 'Nunito',
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: onBg,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: onBg,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: raised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: raised,
      contentTextStyle: TextStyle(fontFamily: 'Nunito', color: onBg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      iconColor: muted,
    ),
  );
}

/// Colour of an activity under the current palette.
Color activityColor(int colorIndex, List<int> palette, {required bool dark}) =>
    Color(accentFor(palette[colorIndex % palette.length], dark: dark));

String fmtHms(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

/// "2h 15m", "45m", "0m" — for totals.
String fmtHm(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}
