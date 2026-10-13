import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app.dart';
import 'package:time_tracker/db.dart';
import 'package:time_tracker/settings.dart';
import 'package:time_tracker/water.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String hm(DateTime t) => '${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  // Tuesday 13 October 2026.
  final now = DateTime(2026, 10, 13, 10, 30);

  test('off, nothing is planned', () {
    expect(waterPlan(const Settings({}), now), isEmpty);
  });

  test('within the hours, every interval, then the next day from the start', () {
    final plan = waterPlan(const Settings({'waterOn': '1'}), now).map(hm).toList();
    expect(plan.take(3), ['13 11:00', '13 12:00', '13 13:00']);
    expect(plan, contains('13 21:00'));
    expect(plan, isNot(contains('13 22:00')));
    expect(plan[plan.indexOf('13 21:00') + 1], '14 9:00');
  });

  test('a glass restarts the count, days off are skipped', () {
    final s = Settings({'waterOn': '1', 'waterLast': DateTime(2026, 10, 13, 10, 40).toIso8601String(), 'waterDays': '2'});
    final plan = waterPlan(s, now).map(hm).toList();
    expect(plan.first, '13 11:40');
    expect(plan.where((t) => t.startsWith('14 ')), isEmpty); // Wednesday off
    expect(plan, contains('20 9:00')); // next Tuesday
  });

  test('hours past midnight', () {
    final s = Settings({'waterOn': '1', 'waterFrom': '${22 * 60}', 'waterTo': '${2 * 60}'});
    final plan = waterPlan(s, DateTime(2026, 10, 13, 23, 10)).map(hm).take(4).toList();
    expect(plan, ['14 0:00', '14 1:00', '14 2:00', '14 22:00']);
  });

  test('"Solo in focus" follows the session', () {
    final s = Settings({'waterOn': '1', 'waterMode': 'focus', 'waterEvery': '30'});
    expect(waterPlan(s, now), isEmpty);
    expect(waterPlan(s, now, focusStart: DateTime(2026, 10, 13, 10)).map(hm).take(2), ['13 11:00', '13 11:30']);
    final drank = Settings({...{'waterOn': '1', 'waterMode': 'focus', 'waterEvery': '30'}, 'waterLast': DateTime(2026, 10, 13, 10, 50).toIso8601String()});
    expect(waterPlan(drank, now, focusStart: DateTime(2026, 10, 13, 10)).map(hm).first, '13 11:20');
  });

  test('glasses and litres', () {
    const s = Settings({});
    expect(waterSummary(3, s), '3 di 8 bicchieri · 0,75 L');
    expect(waterSummary(4, s), '4 di 8 bicchieri · 1 L');
    expect(waterSummary(6, s), '6 di 8 bicchieri · 1,5 L');
  });

  test('a glass is counted, one less never goes below zero', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('taime_native'),
      (_) async => null,
    );
    db = Db.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await addWater(1);
    await addWater(1);
    var s = Settings(await db.allPrefs());
    expect(s.waterCount(DateTime.now()), 2);
    expect(s.waterLast, isNotNull);
    for (var i = 0; i < 3; i++) {
      await addWater(-1);
    }
    s = Settings(await db.allPrefs());
    expect(s.waterCount(DateTime.now()), 0);
  });
}
