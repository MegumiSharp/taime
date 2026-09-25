import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app.dart';
import 'db.dart';

/// JSON backup (re-importable) and CSV export (for spreadsheets).
Future<Map<String, dynamic>> _dump() async {
  final acts = await db.select(db.activities).get();
  final sess = await db.select(db.sessions).get();
  final segs = await db.select(db.segments).get();
  final prefs = await db.allPrefs();
  String? iso(DateTime? d) => d?.toIso8601String();
  return {
    'app': 'taime',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'activities': [
      for (final a in acts)
        {
          'id': a.id,
          'name': a.name,
          'colorIndex': a.colorIndex,
          'icon': a.icon,
          'archived': a.archived,
          'sort': a.sort,
        },
    ],
    'sessions': [
      for (final s in sess)
        {
          'id': s.id,
          'activityId': s.activityId,
          'note': s.note,
          'startedAt': iso(s.startedAt),
          'endedAt': iso(s.endedAt),
        },
    ],
    'segments': [
      for (final s in segs)
        {
          'id': s.id,
          'sessionId': s.sessionId,
          'isPause': s.isPause,
          'startedAt': iso(s.startedAt),
          'endedAt': iso(s.endedAt),
        },
    ],
    'prefs': prefs,
  };
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
    const JsonEncoder.withIndent('  ').convert(await _dump()),
  );
  await SharePlus.instance.share(
    ShareParams(files: [XFile(f.path)], subject: 'Backup Taime'),
  );
}

Future<void> exportCsv() async {
  final acts = {for (final a in await db.select(db.activities).get()) a.id: a};
  final sess = await db.select(db.sessions).get();
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final rows = <String>[
    'attivita,nota,inizio,fine,minuti_lavoro,minuti_pausa',
  ];
  for (final s in sess) {
    final segs = await db.segmentsOf(s.id);
    Duration sum(bool pause) => segs
        .where((x) => x.isPause == pause && x.endedAt != null)
        .fold(Duration.zero, (a, x) => a + x.endedAt!.difference(x.startedAt));
    final name = (acts[s.activityId]?.name ?? '').replaceAll('"', "'");
    final note = s.note.replaceAll('"', "'").replaceAll('\n', ' ');
    rows.add(
      '"$name","$note",${fmt.format(s.startedAt)},'
      '${s.endedAt == null ? '' : fmt.format(s.endedAt!)},'
      '${sum(false).inMinutes},${sum(true).inMinutes}',
    );
  }
  final f = await _write('taime-${_stamp()}.csv', rows.join('\n'));
  await SharePlus.instance.share(
    ShareParams(files: [XFile(f.path)], subject: 'Taime CSV'),
  );
}

/// Replaces everything with the contents of a backup file.
/// Returns a short message for the user.
Future<String> importJson() async {
  final picked = await FilePicker.pickFiles(type: FileType.any);
  final file = picked.firstOrNull;
  if (file == null) return 'Importazione annullata';

  final raw = utf8.decode(await file.xFile.readAsBytes());
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(raw) as Map<String, dynamic>;
  } on FormatException {
    return 'File non valido';
  }
  if (data['app'] != 'taime') return 'Non è un backup di Taime';

  DateTime? parse(Object? v) => v == null ? null : DateTime.parse(v as String);

  await db.transaction(() async {
    await db.delete(db.segments).go();
    await db.delete(db.sessions).go();
    await db.delete(db.activities).go();
    await db.delete(db.prefs).go();

    for (final a in (data['activities'] as List).cast<Map<String, dynamic>>()) {
      await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              id: Value(a['id'] as int),
              name: a['name'] as String,
              colorIndex: a['colorIndex'] as int,
              icon: Value(a['icon'] as String),
              archived: Value(a['archived'] as bool),
              sort: Value(a['sort'] as int),
            ),
          );
    }
    for (final s in (data['sessions'] as List).cast<Map<String, dynamic>>()) {
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              id: Value(s['id'] as int),
              activityId: s['activityId'] as int,
              note: Value(s['note'] as String? ?? ''),
              startedAt: parse(s['startedAt'])!,
              endedAt: Value(parse(s['endedAt'])),
            ),
          );
    }
    for (final s in (data['segments'] as List).cast<Map<String, dynamic>>()) {
      await db
          .into(db.segments)
          .insert(
            SegmentsCompanion.insert(
              id: Value(s['id'] as int),
              sessionId: s['sessionId'] as int,
              isPause: s['isPause'] as bool,
              startedAt: parse(s['startedAt'])!,
              endedAt: Value(parse(s['endedAt'])),
            ),
          );
    }
    for (final e in (data['prefs'] as Map).entries) {
      await db.setPref(e.key as String, e.value as String);
    }
  });
  final n = (data['sessions'] as List).length;
  return 'Importate $n sessioni';
}
