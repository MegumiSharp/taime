import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/kitten/skins.dart';
import 'package:time_tracker/todo/todo_sync.dart';

void main() {
  final now = DateTime(2026, 9, 28, 15);

  test('a to-do lands in Oggi, Questa settimana or Più avanti', () {
    expect(sectionFor(null, 0, now), 0);
    expect(sectionFor(null, 2, now), 2);
    expect(sectionFor(DateTime(2026, 9, 20), 2, now), 0); // overdue: today
    expect(sectionFor(DateTime(2026, 9, 28, 23), 2, now), 0);
    expect(sectionFor(DateTime(2026, 9, 29), 0, now), 1);
    expect(sectionFor(DateTime(2026, 10, 4), 0, now), 1);
    expect(sectionFor(DateTime(2026, 10, 5), 0, now), 2);
    // Across the end of summer time (25 Oct 2026) days still count right.
    expect(sectionFor(DateTime(2026, 10, 26), 0, DateTime(2026, 10, 24)), 1);
  });

  test('a kitten you made survives a save and a reload', () {
    final wendy = kSkinById['wendy']!;
    final look = jsonDecode(jsonEncode(wendy.lookJson())) as Map<String, Object?>;
    final copy = Skin.fromLook('${kCustomPrefix}1', 'Mia', look);
    expect(copy.coat.pattern, CoatPattern.maculato);
    expect(copy.coat.base, wendy.coat.base);
    expect(copy.eyes, EyeStyle.verdi);
    expect(copy.isCustom, isTrue);

    loadCustomSkins([
      (id: 1, name: 'Mia', spec: jsonEncode(look), deleted: false),
      (id: 2, name: 'Vecchia', spec: '{}', deleted: true),
    ]);
    expect(skinById('${kCustomPrefix}1').name, 'Mia');
    expect(skinById('${kCustomPrefix}2').name, 'Vecchia'); // old sessions still draw it
    expect(myCustomSkins.map((s) => s.name), ['Mia']);
    expect(Skin.fromLook('x', 'Nera', {'base': 0xFF514748}).coat.darkOutline, isTrue);
  });

  test('owned kittens unlock their styles', () {
    final starter = KittenParts(kSkins.where((s) => s.free));
    final more = KittenParts([...kSkins.where((s) => s.free), kSkinById['bruno']!, kSkinById['minou']!]);
    expect(starter.head.map((h) => h.$1), [Accessory.nessuno]);
    expect(more.neck.map((n) => n.$1), contains(Accessory.papillon));
    expect(more.eyes, contains(EyeStyle.dorati));
    expect(more.blackNose, isTrue);
    expect(starter.blackNose, isFalse);
    expect(more.count, greaterThan(starter.count));
    expect(KittenParts.total, greaterThan(more.count));
  });
}
