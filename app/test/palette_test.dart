import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/palette.dart';

void main() {
  test('parses a coolors url', () {
    expect(
      parsePalette('https://coolors.co/264653-2a9d8f-e9c46a-f4a261-e76f51'),
      [0xFF264653, 0xFF2A9D8F, 0xFFE9C46A, 0xFFF4A261, 0xFFE76F51],
    );
  });

  test('accents stay readable on both backgrounds, whatever goes in', () {
    const nasty = [
      0xFFFF00FF, // neon fuchsia
      0xFF000000, // black
      0xFFFFFFFF, // white
      0xFF0000A0, // very dark blue
      0xFFFFFF00, // yellow
      0xFF808080, // grey
    ];
    for (final dark in [true, false]) {
      final bg = backgroundFor(nasty, dark: dark);
      for (final input in nasty) {
        final a = accentFor(input, dark: dark);
        expect(
          contrastRatio(a, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'accent ${a.toRadixString(16)} on bg ${bg.toRadixString(16)}',
        );
        expect(toOklch(a).c, lessThanOrEqualTo(0.14));
      }
    }
  });

  test('backgrounds are near-neutral and light mode is eggshell', () {
    final darkBg = toOklch(backgroundFor([0xFFFF00FF], dark: true));
    expect(darkBg.c, lessThanOrEqualTo(0.02));
    expect(darkBg.l, lessThan(0.25));

    final lightBg = toOklch(backgroundFor([0xFFFF00FF], dark: false));
    expect(lightBg.c, lessThanOrEqualTo(0.02));
    expect(lightBg.l, greaterThan(0.9));
    expect(backgroundFor([0xFFFF00FF], dark: false), isNot(0xFFFFFFFF));
  });

  test('text on an accent is picked for contrast', () {
    for (final input in [0xFFFFFF00, 0xFF0000A0, 0xFF7C9CF5]) {
      final a = accentFor(input, dark: true);
      expect(contrastRatio(a, onColor(a)), greaterThanOrEqualTo(4.5));
    }
  });
}
