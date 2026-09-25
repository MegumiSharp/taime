import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:taime_native/taime_native.dart';

import 'app.dart';
import 'db.dart';
import 'kitten/skins.dart';
import 'palette.dart';

/// JSON backup (re-importable, v1 and v2) and CSV export (for spreadsheets).
const int kBackupVersion = 2;

String? _iso(DateTime? d) => d?.toIso8601String();
DateTime? _parse(Object? v) => v == null ? null : DateTime.parse(v as String);

Future<Map<String, dynamic>> dumpAll(Db db) async {
  final acts = await db.select(db.activities).get();
  final sess = await db.select(db.sessions).get();
  final segs = await db.select(db.segments).get();
  final buys = await db.select(db.purchases).get();
  final cats = await db.select(db.todoCategories).get();
  final todos = await db.select(db.todos).get();
  return {
    'app': 'taime',
    'version': kBackupVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'activities': [
      for (final a in acts)
        {'id': a.id, 'name': a.name, 'color': a.color, 'icon': a.icon, 'archived': a.archived, 'sort': a.sort},
    ],
    'sessions': [
      for (final s in sess)
        {
          'id': s.id,
          'activityId': s.activityId,
          'note': s.note,
          'startedAt': _iso(s.startedAt),
          'endedAt': _iso(s.endedAt),
          'skinId': s.skinId,
        },
    ],
    'segments': [
      for (final s in segs)
        {
          'id': s.id,
          'sessionId': s.sessionId,
          'isPause': s.isPause,
          'startedAt': _iso(s.startedAt),
          'endedAt': _iso(s.endedAt),
          'deadlineAt': _iso(s.deadlineAt),
          'deadlineKind': s.deadlineKind,
        },
    ],
    'purchases': [
      for (final p in buys) {'id': p.id, 'skinId': p.skinId, 'price': p.price, 'purchasedAt': _iso(p.purchasedAt)},
    ],
    'todoCategories': [
      for (final c in cats) {'id': c.id, 'name': c.name, 'color': c.color, 'sort': c.sort},
    ],
    'todos': [
      for (final t in todos)
        {
          'id': t.id,
          'parentId': t.parentId,
          'categoryId': t.categoryId,
          'title': t.title,
          'notes': t.notes,
          'due': _iso(t.due),
          'hasTime': t.hasTime,
          'priority': t.priority,
          'recurrence': t.recurrence,
          'remindBefore': t.remindBefore,
          'completedAt': _iso(t.completedAt),
          'sort': t.sort,
          'createdAt': _iso(t.createdAt),
        },
    ],
    'prefs': await db.allPrefs(),
  };
}

/// Replaces everything in [db] with [data]. Accepts version 1 and 2 backups.
Future<int> restoreAll(Db db, Map<String, dynamic> data) async {
  final version = (data['version'] as int?) ?? 1;
  final prefs = (data['prefs'] as Map?)?.cast<String, String>() ?? const {};
  final parsed = parsePalette(prefs['palette'] ?? '');
  final palette = parsed.isEmpty ? defaultPalette : parsed;
  List<Map<String, dynamic>> list(String k) => ((data[k] as List?) ?? const []).cast<Map<String, dynamic>>();

  await db.transaction(() async {
    for (final t in <TableInfo<Table, dynamic>>[db.todos, db.todoCategories, db.purchases, db.segments, db.sessions, db.activities, db.prefs]) {
      await db.delete(t).go();
    }
    for (final a in list('activities')) {
      final color = version >= 2
          ? a['color'] as int
          : palette[((a['colorIndex'] as int?) ?? 0) % palette.length];
      await db.into(db.activities).insert(
        ActivitiesCompanion.insert(
          id: Value(a['id'] as int),
          name: a['name'] as String,
          color: color,
          icon: Value(a['icon'] as String? ?? 'circle'),
          archived: Value(a['archived'] as bool? ?? false),
          sort: Value(a['sort'] as int? ?? 0),
        ),
      );
    }
    for (final s in list('sessions')) {
      await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          id: Value(s['id'] as int),
          activityId: s['activityId'] as int,
          note: Value(s['note'] as String? ?? ''),
          startedAt: _parse(s['startedAt'])!,
          endedAt: Value(_parse(s['endedAt'])),
          skinId: Value(s['skinId'] as String?),
        ),
      );
    }
    for (final s in list('segments')) {
      await db.into(db.segments).insert(
        SegmentsCompanion.insert(
          id: Value(s['id'] as int),
          sessionId: s['sessionId'] as int,
          isPause: s['isPause'] as bool,
          startedAt: _parse(s['startedAt'])!,
          endedAt: Value(_parse(s['endedAt'])),
          deadlineAt: Value(_parse(s['deadlineAt'])),
          deadlineKind: Value(s['deadlineKind'] as String?),
        ),
      );
    }
    for (final p in list('purchases')) {
      await db.into(db.purchases).insert(
        PurchasesCompanion.insert(
          id: Value(p['id'] as int),
          skinId: p['skinId'] as String,
          price: p['price'] as int,
          purchasedAt: _parse(p['purchasedAt'])!,
        ),
      );
    }
    for (final c in list('todoCategories')) {
      await db.into(db.todoCategories).insert(
        TodoCategoriesCompanion.insert(
          id: Value(c['id'] as int),
          name: c['name'] as String,
          color: c['color'] as int,
          sort: Value(c['sort'] as int? ?? 0),
        ),
      );
    }
    // Parents before subtasks.
    final todos = [...list('todos')]..sort((a, b) => (a['parentId'] == null ? 0 : 1).compareTo(b['parentId'] == null ? 0 : 1));
    for (final t in todos) {
      await db.into(db.todos).insert(
        TodosCompanion.insert(
          id: Value(t['id'] as int),
          parentId: Value(t['parentId'] as int?),
          categoryId: Value(t['categoryId'] as int?),
          title: t['title'] as String,
          notes: Value(t['notes'] as String? ?? ''),
          due: Value(_parse(t['due'])),
          hasTime: Value(t['hasTime'] as bool? ?? false),
          priority: Value(t['priority'] as int? ?? 4),
          recurrence: Value(t['recurrence'] as String?),
          remindBefore: Value(t['remindBefore'] as int?),
          completedAt: Value(_parse(t['completedAt'])),
          sort: Value(t['sort'] as int? ?? 0),
          createdAt: _parse(t['createdAt']) ?? DateTime.now(),
        ),
      );
    }
    for (final e in prefs.entries) {
      await db.setPref(e.key, e.value);
    }
  });
  return list('sessions').length;
}

Future<File> _write(String name, String content) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsString(content);
  return f;
}

String _stamp() => DateFormat('yyyy-MM-dd').format(DateTime.now());

Future<void> exportJson() async {
  final f = await _write(
    'taime-backup-${_stamp()}.json',
    const JsonEncoder.withIndent('  ').convert(await dumpAll(db)),
  );
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: 'Backup Taime'));
}

Future<void> exportCsv() async {
  final acts = {for (final a in await db.select(db.activities).get()) a.id: a};
  final sess = await db.select(db.sessions).get();
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final rows = <String>['attivita,nota,inizio,fine,minuti_lavoro,minuti_pausa,gattino'];
  String q(String s) => '"${s.replaceAll('"', "'").replaceAll('\n', ' ')}"';
  for (final s in sess) {
    final segs = await db.segmentsOf(s.id);
    Duration sum(bool pause) => segs
        .where((x) => x.isPause == pause && x.endedAt != null)
        .fold(Duration.zero, (a, x) => a + x.endedAt!.difference(x.startedAt));
    rows.add(
      '${q(acts[s.activityId]?.name ?? '')},${q(s.note)},${fmt.format(s.startedAt)},'
      '${s.endedAt == null ? '' : fmt.format(s.endedAt!)},'
      '${sum(false).inMinutes},${sum(true).inMinutes},${q(skinById(s.skinId).name)}',
    );
  }
  final f = await _write('taime-${_stamp()}.csv', rows.join('\n'));
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: 'Taime CSV'));
}

/// Picks a backup file and restores it. Returns a short message.
Future<String> importJson() async {
  final file = (await FilePicker.pickFiles(type: FileType.any)).firstOrNull;
  if (file == null) return 'Importazione annullata';
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(utf8.decode(await file.xFile.readAsBytes())) as Map<String, dynamic>;
  } on FormatException {
    return 'File non valido';
  }
  if (data['app'] != 'taime') return 'Non è un backup di Taime';
  final n = await restoreAll(db, data);
  return 'Importate $n sessioni';
}

/// Once a week, a JSON backup into Download/Taime (the last 4 are kept).
/// Runs when the app opens or comes back; returns true if it wrote one.
Future<bool> maybeAutoBackup({bool force = false}) async {
  try {
    final prefs = await db.allPrefs();
    if (!force && prefs['autoBackup'] == '0') return false;
    final last = DateTime.tryParse(prefs['lastAutoBackup'] ?? '');
    if (!force && last != null && DateTime.now().difference(last) < const Duration(days: 7)) return false;
    final json = const JsonEncoder.withIndent('  ').convert(await dumpAll(db));
    await TaimeNative.saveBackup('taime-auto-${_stamp()}.json', utf8.encode(json));
    await db.setPref('lastAutoBackup', DateTime.now().toIso8601String());
    return true;
  } catch (_) {
    return false;
  }
}
