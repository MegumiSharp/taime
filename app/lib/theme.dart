import 'package:flutter/material.dart';

import 'palette.dart';
import 'settings.dart';

const double kRadius = 24;
const double kRadiusSmall = 16;

/// Hue of each built-in theme (OKLCH degrees) and how colourful it may get.
const Map<String, ({double hue, double chroma, String label})> kThemes = {
  'salvia': (hue: 152, chroma: 0.8, label: 'Salvia'),
  'lavanda': (hue: 300, chroma: 1.0, label: 'Lavanda'),
  'azzurro': (hue: 238, chroma: 0.9, label: 'Azzurro polvere'),
};

/// Hue of the pause colour: soft apricot.
const double kPauseHue = 62;

/// Every colour the app paints with, derived from one hue so any theme keeps
/// the same contrast. Reach it with `context.tc`.
@immutable
class TaimeColors extends ThemeExtension<TaimeColors> {
  const TaimeColors({
    required this.bgTop,
    required this.bgBottom,
    required this.surface,
    required this.raised,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.text,
    required this.muted,
    required this.outline,
    required this.pause,
    required this.pauseSoft,
    required this.pauseBgTop,
    required this.pauseBgBottom,
    required this.grass,
    required this.grassRich,
    required this.earth,
    required this.danger,
    required this.dark,
  });

  final Color bgTop, bgBottom, surface, raised;
  final Color accent, onAccent, accentSoft;
  final Color text, muted, outline;
  final Color pause, pauseSoft, pauseBgTop, pauseBgBottom;
  final Color grass, grassRich, earth, danger;
  final bool dark;

  /// Soft drop shadow. Dark themes use black: a shadow in the (light) text
  /// colour would glow like a halo.
  Color shadow([double strength = 1]) => dark
      ? const Color(0xFF000000).withValues(alpha: 0.22 * strength)
      : text.withValues(alpha: 0.05 * strength);

  factory TaimeColors.from(Settings s, {required bool dark}) {
    double hue;
    double k;
    if (s.theme == 'custom') {
      hue = toOklch(s.palette.first).h;
      k = 1.0;
    } else {
      final t = kThemes[s.theme] ?? kThemes['salvia']!;
      hue = t.hue;
      k = t.chroma;
    }
    Color c(double l, double ch, [double? h]) =>
        Color(oklch(l, ch * k, h ?? hue));
    Color p(double l, double ch) => Color(oklch(l, ch, kPauseHue));

    final accent = s.theme == 'custom'
        ? Color(accentFor(s.palette.first, dark: dark))
        : (dark ? c(0.80, 0.085) : c(0.50, 0.095));

    if (dark) {
      return TaimeColors(
        bgTop: c(0.265, 0.03),
        bgBottom: c(0.195, 0.022),
        surface: c(0.285, 0.022),
        raised: c(0.33, 0.026),
        accent: accent,
        onAccent: Color(onColor(accent.toARGB32())),
        accentSoft: c(0.38, 0.05),
        text: c(0.945, 0.008),
        muted: c(0.74, 0.014),
        outline: c(0.36, 0.02),
        pause: p(0.80, 0.11),
        pauseSoft: p(0.40, 0.06),
        pauseBgTop: p(0.29, 0.035),
        pauseBgBottom: p(0.21, 0.026),
        grass: Color(oklch(0.36, 0.035, 140)),
        grassRich: Color(oklch(0.56, 0.10, 140)),
        earth: Color(oklch(0.30, 0.03, 60)),
        danger: Color(oklch(0.74, 0.11, 25)),
        dark: true,
      );
    }
    return TaimeColors(
      bgTop: c(0.975, 0.02),
      bgBottom: c(0.925, 0.042),
      surface: c(0.992, 0.007),
      raised: c(0.955, 0.02),
      accent: accent,
      onAccent: Color(onColor(accent.toARGB32())),
      accentSoft: c(0.895, 0.05),
      text: c(0.28, 0.02),
      muted: c(0.52, 0.016),
      outline: c(0.895, 0.016),
      pause: p(0.66, 0.125),
      pauseSoft: p(0.915, 0.05),
      pauseBgTop: p(0.975, 0.025),
      pauseBgBottom: p(0.925, 0.05),
      grass: Color(oklch(0.905, 0.035, 135)),
      grassRich: Color(oklch(0.76, 0.10, 138)),
      earth: Color(oklch(0.80, 0.045, 62)),
      danger: Color(oklch(0.56, 0.13, 25)),
      dark: false,
    );
  }

  @override
  TaimeColors copyWith() => this;

  @override
  TaimeColors lerp(TaimeColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return TaimeColors(
      bgTop: l(bgTop, other.bgTop),
      bgBottom: l(bgBottom, other.bgBottom),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentSoft: l(accentSoft, other.accentSoft),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      outline: l(outline, other.outline),
      pause: l(pause, other.pause),
      pauseSoft: l(pauseSoft, other.pauseSoft),
      pauseBgTop: l(pauseBgTop, other.pauseBgTop),
      pauseBgBottom: l(pauseBgBottom, other.pauseBgBottom),
      grass: l(grass, other.grass),
      grassRich: l(grassRich, other.grassRich),
      earth: l(earth, other.earth),
      danger: l(danger, other.danger),
      dark: t < 0.5 ? dark : other.dark,
    );
  }
}

extension TaimeContext on BuildContext {
  TaimeColors get tc => Theme.of(this).extension<TaimeColors>()!;
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

ThemeData buildTheme(Settings s, {required bool dark}) {
  final tc = TaimeColors.from(s, dark: dark);
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: tc.accent,
    onPrimary: tc.onAccent,
    primaryContainer: tc.accentSoft,
    onPrimaryContainer: tc.text,
    secondary: tc.accent,
    onSecondary: tc.onAccent,
    secondaryContainer: tc.accentSoft,
    onSecondaryContainer: tc.text,
    error: tc.danger,
    onError: dark ? Colors.black : Colors.white,
    surface: tc.surface,
    onSurface: tc.text,
    surfaceContainerHighest: tc.raised,
    surfaceContainerHigh: tc.raised,
    surfaceContainer: tc.surface,
    surfaceContainerLow: tc.surface,
    surfaceContainerLowest: tc.surface,
    onSurfaceVariant: tc.muted,
    outline: tc.outline,
    outlineVariant: tc.outline,
  );

  TextStyle f(double size, FontWeight w, {double height = 1.3}) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: size,
    fontWeight: w,
    height: height,
    color: tc.text,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    colorScheme: scheme,
    extensions: [tc],
    scaffoldBackgroundColor: tc.bgTop,
    canvasColor: tc.surface,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    textTheme: TextTheme(
      displayLarge: f(64, FontWeight.w200, height: 1.1),
      displayMedium: f(44, FontWeight.w300, height: 1.1),
      displaySmall: f(34, FontWeight.w300, height: 1.1),
      headlineMedium: f(28, FontWeight.w800, height: 1.2),
      headlineSmall: f(24, FontWeight.w800, height: 1.2),
      titleLarge: f(20, FontWeight.w700),
      titleMedium: f(16, FontWeight.w700),
      titleSmall: f(14, FontWeight.w700),
      bodyLarge: f(16, FontWeight.w400, height: 1.45),
      bodyMedium: f(14, FontWeight.w400, height: 1.45),
      bodySmall: f(12.5, FontWeight.w400, height: 1.4).copyWith(color: tc.muted),
      labelLarge: f(15, FontWeight.w700),
      labelMedium: f(13, FontWeight.w600),
      labelSmall: f(11.5, FontWeight.w600),
    ),
    iconTheme: IconThemeData(color: tc.text),
    cardTheme: CardThemeData(
      color: tc.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
    dividerTheme: DividerThemeData(color: tc.outline, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: tc.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: f(22, FontWeight.w800),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tc.accent,
        foregroundColor: tc.onAccent,
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: f(15, FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tc.text,
        side: BorderSide(color: tc.outline, width: 1.5),
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: f(14, FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tc.accent,
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 44),
        textStyle: f(14, FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tc.accent,
      foregroundColor: tc.onAccent,
      elevation: 2,
      highlightElevation: 4,
      shape: const StadiumBorder(),
      extendedTextStyle: f(15, FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tc.raised,
      hintStyle: TextStyle(color: tc.muted, fontFamily: 'Nunito'),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSmall),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tc.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: tc.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tc.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: f(20, FontWeight.w800),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tc.text,
      contentTextStyle: TextStyle(
        fontFamily: 'Nunito',
        color: tc.surface,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: tc.dark ? tc.accentSoft : tc.accentSoft,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      iconColor: tc.muted,
      titleTextStyle: f(15, FontWeight.w600),
      subtitleTextStyle: f(13, FontWeight.w400).copyWith(color: tc.muted),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? tc.onAccent : tc.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? tc.accent : tc.raised,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: tc.accent,
      inactiveTrackColor: tc.raised,
      thumbColor: tc.accent,
      overlayColor: tc.accent.withValues(alpha: 0.12),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tc.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: f(14, FontWeight.w600),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: tc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: tc.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: tc.accent),
  );
}

/// Colour of an activity, softened for the current mode.
Color activityColor(int argb, {required bool dark}) =>
    Color(accentFor(argb, dark: dark));

/// Pastel fill for an activity (chips, tiles).
Color activitySoft(int argb, {required bool dark}) =>
    Color(softFillFor(argb, dark: dark));

/// Big timer digits: thin and tabular so they do not dance.
TextStyle timerStyle(BuildContext context, {double size = 68}) =>
    Theme.of(context).textTheme.displayLarge!.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w200,
      letterSpacing: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// "12:34" under an hour, "1:02:03" after.
String fmtClock(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:$ss'
      : '${m.toString().padLeft(2, '0')}:$ss';
}

/// "2h 15m", "45m", "0m" — for totals.
String fmtHm(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

