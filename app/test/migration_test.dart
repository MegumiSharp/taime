import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/backup.dart';
import 'package:time_tracker/db.dart';

/// Opens a database exactly as Taime 1.0 left it (schema dumped from 1.0 in
/// test/fixtures/schema_v1.sql), then lets 2.0 upgrade it.
Db openV1(List<String> inserts) {
  final schema = File('test/fixtures/schema_v1.sql').readAsStringSync();
  return Db.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(schema);
        for (final s in inserts) {
          raw.execute(s);
        }
        raw.execute('PRAGMA user_version = 1');
      },
    ),
  );
}

/// A database as Taime 2.0/2.1 left it (test/fixtures/schema_v2.sql).
Db openV2(List<String> inserts) {
  final schema = File('test/fixtures/schema_v2.sql').readAsStringSync();
  return Db.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(schema);
        for (final s in inserts) {
          raw.execute(s);
        }
        raw.execute('PRAGMA user_version = 2');
      },
    ),
  );
}

/// A database as Taime 2.2 left it (test/fixtures/schema_v3.sql).
Db openV3(List<String> inserts) {
  final schema = File('test/fixtures/schema_v3.sql').readAsStringSync();
  return Db.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(schema);
        for (final s in inserts) {
          raw.execute(s);
        }
        raw.execute('PRAGMA user_version = 3');
      },
    ),
  );
}

void main() {
  test('a 2.2 database gains pinned notes', () async {
    final db = openV3([
      "INSERT INTO notes (id, body, created_at, updated_at) VALUES (1, 'idea', 1758000000, 1758000000)",
      "INSERT INTO custom_skins (id, name, spec, created_at) VALUES (1, 'Mia', '{}', 1758000000)",
    ]);
    final n = (await db.select(db.notes).get()).single;
    expect(n.body, 'idea');
    expect(n.pinned, isFalse);
    expect((await db.select(db.customSkins).get()).single.name, 'Mia');
    await db.close();
  });

  test('a 2.x database upgrades to notes and custom kittens', () async {
    final db = openV2([
      "INSERT INTO todos (id, title, created_at) VALUES (1, 'latte', 1758000000)",
      "INSERT INTO purchases (id, skin_id, price, purchased_at) VALUES (1, 'ombra', 600, 1758000000)",
    ]);
    final t = (await db.select(db.todos).get()).single;
    expect(t.title, 'latte');
    expect(t.horizon, 0);
    expect((await db.select(db.purchases).get()).single.skinId, 'ombra');
    await db.into(db.notes).insert(NotesCompanion.insert(body: 'ciao', createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    await db.into(db.customSkins).insert(CustomSkinsCompanion.insert(name: 'Mia', spec: '{}', createdAt: DateTime(2026)));
    expect((await db.select(db.notes).get()).single.body, 'ciao');
    expect((await db.select(db.customSkins).get()).single.name, 'Mia');
    await db.close();
  });

  test('a 1.0 database upgrades with nothing lost', () async {
    final db = openV1([
      "INSERT INTO prefs VALUES ('palette', 'aabbcc-112233'), ('themeMode', 'dark'), ('breakAfterMin', '90')",
      "INSERT INTO activities (id, name, color_index, icon, archived, sort) VALUES "
          "(1, 'Studio', 0, 'book', 0, 0), (2, 'Palestra', 1, 'barbell', 0, 1), (3, 'Vecchia', 7, 'broom', 1, 2)",
      "INSERT INTO sessions (id, activity_id, note, started_at, ended_at) VALUES "
          "(10, 1, 'capitolo 3', 1758000000, 1758007200), (11, 2, '', 1758100000, NULL)",
      "INSERT INTO segments (id, session_id, is_pause, started_at, ended_at, deadline_at, deadline_kind) VALUES "
          "(100, 10, 0, 1758000000, 1758003600, NULL, NULL), "
          "(101, 10, 1, 1758003600, 1758004200, NULL, NULL), "
          "(102, 10, 0, 1758004200, 1758007200, NULL, NULL), "
          "(103, 11, 0, 1758100000, NULL, 1758107200, 'autoPause')",
    ]);

    final acts = await (db.select(db.activities)..orderBy([(a) => OrderingTerm(expression: a.id)])).get();
    expect(acts.map((a) => a.name), ['Studio', 'Palestra', 'Vecchia']);
    // Palette index became the colour the user was looking at.
    expect(acts[0].color, 0xFFAABBCC);
    expect(acts[1].color, 0xFF112233);
    expect(acts[2].color, 0xFF112233); // 7 % 2 = 1
    expect(acts[2].archived, isTrue);
    expect(acts[0].icon, 'book');

    final sessions = await db.select(db.sessions).get();
    expect(sessions.length, 2);
    final s10 = sessions.firstWhere((s) => s.id == 10);
    expect(s10.note, 'capitolo 3');
    expect(s10.skinId, null);
    expect(s10.startedAt, DateTime.fromMillisecondsSinceEpoch(1758000000 * 1000));
    expect(sessions.firstWhere((s) => s.id == 11).endedAt, null);

    final segs = await db.select(db.segments).get();
    expect(segs.length, 4);
    final open = segs.firstWhere((s) => s.id == 103);
    expect(open.deadlineKind, 'autoPause');
    expect(open.endedAt, null);

    final prefs = await db.allPrefs();
    expect(prefs['themeMode'], 'dark');
    expect(prefs['breakAfterMin'], '90');

    // New tables exist and work.
    expect((await db.select(db.todoCategories).get()).length, 3);
    expect(await db.select(db.purchases).get(), isEmpty);
    expect(await db.select(db.todos).get(), isEmpty);

    // Worked time survives: 1h + 50m of closed work.
    expect(await db.watchClosedWorkSeconds().first, 3600 + 3000);
    await db.close();
  });

  test('a 1.0 JSON backup still imports', () async {
    final db = Db.forTesting(NativeDatabase.memory());
    await db.customStatement('select 1');
    final n = await restoreAll(db, {
      'app': 'taime',
      'version': 1,
      'activities': [
        {'id': 5, 'name': 'Studio', 'colorIndex': 1, 'icon': 'book', 'archived': false, 'sort': 0},
      ],
      'sessions': [
        {'id': 1, 'activityId': 5, 'note': 'x', 'startedAt': '2026-09-01T10:00:00.000', 'endedAt': '2026-09-01T11:00:00.000'},
      ],
      'segments': [
        {'id': 1, 'sessionId': 1, 'isPause': false, 'startedAt': '2026-09-01T10:00:00.000', 'endedAt': '2026-09-01T11:00:00.000'},
      ],
      'prefs': {'palette': '111111-222222'},
    });
    expect(n, 1);
    final a = (await db.select(db.activities).get()).single;
    expect(a.color, 0xFF222222);
    expect((await db.select(db.segments).get()).single.isPause, isFalse);
    await db.close();
  });

  test('a backup round-trips', () async {
    final a = Db.forTesting(NativeDatabase.memory());
    await a.customStatement('select 1');
    await a.into(a.purchases).insert(PurchasesCompanion.insert(skinId: 'ombra', price: 600, purchasedAt: DateTime(2026, 9, 1)));
    await a.into(a.todos).insert(TodosCompanion.insert(title: 'comprare latte', createdAt: DateTime(2026, 9, 1), due: Value(DateTime(2026, 9, 2, 18)), hasTime: const Value(true)));
    await a.into(a.todos).insert(TodosCompanion.insert(title: 'dopo', createdAt: DateTime(2026, 9, 1), horizon: const Value(2)));
    await a.into(a.notes).insert(NotesCompanion.insert(body: 'idea', color: const Value(0xFFF2A7C3), date: Value(DateTime(2026, 9, 3, 9)), hasTime: const Value(true), remind: const Value(true), pinned: const Value(true), createdAt: DateTime(2026, 9, 1), updatedAt: DateTime(2026, 9, 1)));
    await a.into(a.customSkins).insert(CustomSkinsCompanion.insert(name: 'Mia', spec: '{"base":1}', createdAt: DateTime(2026, 9, 1)));
    final dump = await dumpAll(a);

    final b = Db.forTesting(NativeDatabase.memory());
    await b.customStatement('select 1');
    await restoreAll(b, dump);
    expect((await b.select(b.purchases).get()).single.skinId, 'ombra');
    final t = (await b.select(b.todos).get()).firstWhere((x) => x.title == 'comprare latte');
    expect((await b.select(b.todos).get()).firstWhere((x) => x.title == 'dopo').horizon, 2);
    final n = (await b.select(b.notes).get()).single;
    expect(n.body, 'idea');
    expect(n.color, 0xFFF2A7C3);
    expect(n.date, DateTime(2026, 9, 3, 9));
    expect(n.remind, isTrue);
    expect(n.pinned, isTrue);
    expect((await b.select(b.customSkins).get()).single.spec, '{"base":1}');
    expect(t.due, DateTime(2026, 9, 2, 18));
    expect(t.hasTime, isTrue);
    expect((await b.select(b.activities).get()).length, 3);
    await a.close();
    await b.close();
  });
}
