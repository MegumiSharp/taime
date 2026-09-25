import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/kitten/skins.dart';
import 'package:time_tracker/palette.dart';
import 'package:time_tracker/settings.dart';
import 'package:time_tracker/theme.dart';

void main() {
  test('one adult per full hour, a kitten for the rest', () {
    final cats = catsForSession(150, 'biscotto', 1); // 2h30
    expect(cats.where((c) => c.growth == 1).length, 2);
    expect(cats.length, 3);
    expect(cats.last.growth, closeTo(0.5, 1e-9));
    expect(stageOf(30), 2); // Giovane

    expect(catsForSession(60, 'x', 1).length, 1);
    expect(catsForSession(64, 'x', 1).length, 1); // 4 leftover minutes: no kitten
    expect(catsForSession(65, 'x', 1).length, 2);
    expect(catsForSession(4, 'x', 1), isEmpty);
    expect(catsForSession(0, 'x', 1), isEmpty);
  });

  test('growth stages', () {
    expect([0, 9, 10, 24, 25, 44, 45, 59, 60].map((m) => stageOf(m.toDouble())), [0, 0, 1, 1, 2, 2, 3, 3, 4]);
    expect(growthOf(60), 1);
    expect(growthOf(90), 1);
  });

  test('crocchette: a minute of work each, minus spending', () {
    expect(crocchetteBalance(0, 0), 0);
    expect(crocchetteBalance(3599, 0), 59);
    expect(crocchetteBalance(7200, 100), 20);
    // Deleting sessions can push it below zero; the UI clamps and blocks buying.
    expect(crocchetteBalance(60, 100), -99);
  });

  test('catalogue: at least 30 skins, 3 free, unique ids, four rarities', () {
    expect(kSkins.length, greaterThanOrEqualTo(30));
    expect(kSkins.where((s) => s.free).length, 3);
    expect(kSkins.map((s) => s.id).toSet().length, kSkins.length);
    for (final r in Rarity.values) {
      expect(kSkins.where((s) => s.rarity == r), isNotEmpty);
    }
    for (final s in kSkins.where((s) => !s.free)) {
      expect(s.price, greaterThan(0));
    }
  });

  test('every theme keeps text readable in light and dark', () {
    for (final theme in ['salvia', 'lavanda', 'azzurro', 'custom']) {
      for (final dark in [false, true]) {
        final tc = TaimeColors.from(Settings({'theme': theme, 'palette': 'ff00ff-00ff00'}), dark: dark);
        final reason = '$theme ${dark ? 'dark' : 'light'}';
        expect(contrastRatio(tc.text.toARGB32(), tc.bgTop.toARGB32()), greaterThanOrEqualTo(7), reason: reason);
        expect(contrastRatio(tc.text.toARGB32(), tc.surface.toARGB32()), greaterThanOrEqualTo(7), reason: reason);
        expect(contrastRatio(tc.muted.toARGB32(), tc.surface.toARGB32()), greaterThanOrEqualTo(3.5), reason: reason);
        expect(contrastRatio(tc.accent.toARGB32(), tc.surface.toARGB32()), greaterThanOrEqualTo(3), reason: reason);
      }
    }
  });
}
