import 'dart:math' as math;
import 'dart:ui' show Color;

/// Palette handling.
///
/// A pasted Coolors palette only ever drives accents. Backgrounds stay neutral
/// and every accent is pushed into a lightness/chroma band that stays readable
/// on the current background, so no palette can produce an eyesore.
const List<int> defaultPalette = [
  0xFF7C9CF5,
  0xFF5FC9A7,
  0xFFE8B45F,
  0xFFE88080,
  0xFFB48BE8,
];

/// Accepts a coolors.co URL, or any text containing hex colours.
List<int> parsePalette(String input) {
  final matches = RegExp(
    r'(?:#|\b)([0-9a-fA-F]{6})\b',
  ).allMatches(input.replaceAll('-', ' '));
  final out = <int>[];
  for (final m in matches) {
    final v = int.parse(m.group(1)!, radix: 16) | 0xFF000000;
    if (!out.contains(v)) out.add(v);
  }
  return out;
}

String paletteToString(List<int> palette) =>
    palette.map((c) => (c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')).join('-');

// --- OKLab / OKLCH -----------------------------------------------------------

double _toLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _toSrgb(double c) => c <= 0.0031308
    ? 12.92 * c
    : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

/// (L, C, h) with L in 0..1, h in degrees.
({double l, double c, double h}) toOklch(int argb) {
  final r = _toLinear(((argb >> 16) & 0xFF) / 255);
  final g = _toLinear(((argb >> 8) & 0xFF) / 255);
  final b = _toLinear((argb & 0xFF) / 255);

  final l = math.pow(
    0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    1 / 3,
  ).toDouble();
  final m = math.pow(
    0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    1 / 3,
  ).toDouble();
  final s = math.pow(
    0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    1 / 3,
  ).toDouble();

  final okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  final okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;

  final chroma = math.sqrt(okA * okA + okB * okB);
  var hue = math.atan2(okB, okA) * 180 / math.pi;
  if (hue < 0) hue += 360;
  return (l: okL, c: chroma, h: hue);
}

int _oklchToArgbRaw(double okL, double chroma, double hueDeg) {
  final hr = hueDeg * math.pi / 180;
  final okA = chroma * math.cos(hr);
  final okB = chroma * math.sin(hr);

  final l = math.pow(okL + 0.3963377774 * okA + 0.2158037573 * okB, 3).toDouble();
  final m = math.pow(okL - 0.1055613458 * okA - 0.0638541728 * okB, 3).toDouble();
  final s = math.pow(okL - 0.0894841775 * okA - 1.2914855480 * okB, 3).toDouble();

  final r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  final g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  final b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

  int ch(double v) => (_toSrgb(v.clamp(0.0, 1.0)) * 255).round().clamp(0, 255);
  return 0xFF000000 | (ch(r) << 16) | (ch(g) << 8) | ch(b);
}

bool _inGamut(double okL, double chroma, double hueDeg) {
  final hr = hueDeg * math.pi / 180;
  final okA = chroma * math.cos(hr);
  final okB = chroma * math.sin(hr);
  final l = math.pow(okL + 0.3963377774 * okA + 0.2158037573 * okB, 3).toDouble();
  final m = math.pow(okL - 0.1055613458 * okA - 0.0638541728 * okB, 3).toDouble();
  final s = math.pow(okL - 0.0894841775 * okA - 1.2914855480 * okB, 3).toDouble();
  final rgb = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  ];
  return rgb.every((v) => v >= -0.001 && v <= 1.001);
}

/// Builds an sRGB colour, walking chroma down until the colour is displayable.
int fromOklch(double okL, double chroma, double hueDeg) {
  var c = chroma;
  while (c > 0.001 && !_inGamut(okL, c, hueDeg)) {
    c -= 0.005;
  }
  return _oklchToArgbRaw(okL, math.max(c, 0), hueDeg);
}

// --- Roles -------------------------------------------------------------------

/// Pulls any colour into the band that reads well on the given background.
///
/// Dark UI wants light, moderately saturated accents; light UI wants darker
/// ones. Chroma is capped so neon input calms down instead of screaming.
int accentFor(int argb, {required bool dark}) {
  final o = toOklch(argb);
  var l = dark ? o.l.clamp(0.70, 0.84) : o.l.clamp(0.40, 0.60);
  final c = math.min(o.c, dark ? 0.135 : 0.125);
  // Greys in, greys out: keep near-neutral inputs neutral.
  final chroma = o.c < 0.02 ? o.c : math.max(c, 0.045);

  // Nudge lightness until it clears 4.5:1 on this mode's page background.
  final bg = backgroundFor(const [], dark: dark);
  var out = fromOklch(l, chroma, o.h);
  while (contrastRatio(out, bg) < 4.5 && l > 0.25 && l < 0.95) {
    l += dark ? 0.01 : -0.01;
    out = fromOklch(l, chroma, o.h);
  }
  return out;
}

double _relLuminance(int argb) {
  final r = _toLinear(((argb >> 16) & 0xFF) / 255);
  final g = _toLinear(((argb >> 8) & 0xFF) / 255);
  final b = _toLinear((argb & 0xFF) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(int a, int b) {
  final la = _relLuminance(a), lb = _relLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Black or white, whichever is readable on [background].
int onColor(int background) =>
    contrastRatio(background, 0xFF000000) >= contrastRatio(background, 0xFFFFFFFF)
    ? 0xFF14150F
    : 0xFFFFFFFF;

/// Background tinted by the palette's hue, but nearly neutral (chroma <= 0.02).
int backgroundFor(List<int> palette, {required bool dark, double level = 0}) {
  final hue = palette.isEmpty ? 260.0 : toOklch(palette.first).h;
  if (dark) {
    // 0 = page, 1 = card, 2 = raised.
    const ls = [0.175, 0.225, 0.265];
    return fromOklch(ls[level.clamp(0, 2).toInt()], 0.012, hue);
  }
  // Eggshell: warm, never pure white.
  const ls = [0.955, 0.985, 0.925];
  return fromOklch(ls[level.clamp(0, 2).toInt()], 0.016, 85);
}

Color color(int argb) => Color(argb);
