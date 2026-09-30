import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../db.dart';
import '../icons.dart';
import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../theme.dart';
import '../tracker.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';
import 'pen.dart';

String dayLabel(DateTime d) {
  final today = DateTime.now();
  final t = DateTime(today.year, today.month, today.day);
  if (d == t) return 'Oggi';
  if (d == t.subtract(const Duration(days: 1))) return 'Ieri';
  final s = DateFormat('EEEE d MMMM', 'it').format(d);
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Cats of each session in a list, flattened.
List<PenCat> catsOf(List<SessionWork> sessions) => [
  for (final s in sessions) ...catsForSession(s.workSeconds ~/ 60, s.session.skinId ?? kSkins.first.id, s.session.id),
];

/// The day in detail: its own fenced tile and every session, all editable
/// (what the Registro was in 1.0).
class DayPage extends StatefulWidget {
  const DayPage({super.key, required this.day});
  final DateTime day;

  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
  late DateTime _day = widget.day;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final next = DateTime(_day.year, _day.month, _day.day + 1);
    return Scaffold(
      backgroundColor: tc.bgTop,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addManualSession(context, day: _day),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Aggiungi'),
      ),
      body: PastelBackground(
        child: SafeArea(
          child: StreamBuilder<List<SessionWork>>(
            stream: db.watchSessionWork(_day, next),
            builder: (context, snap) {
              final sessions = snap.data ?? const <SessionWork>[];
              final total = sessions.fold(0, (a, s) => a + s.workSeconds);
              final cats = catsOf(sessions);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Indietro',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          dayLabel(_day),
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Giorno prima',
                        onPressed: () => setState(() => _day = DateTime(_day.year, _day.month, _day.day - 1)),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        tooltip: 'Giorno dopo',
                        onPressed: () => setState(() => _day = next),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    child: Column(
                      children: [
                        PenView(
                          cols: 1,
                          rows: 1,
                          maxCatsPerTile: 8,
                          catScale: 0.3,
                          animateCats: true,
                          tiles: [
                            PenTile(
                              col: 0,
                              row: 0,
                              minutes: total / 60,
                              cats: cats,
                              seed: _day.millisecondsSinceEpoch ~/ 86400000,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              fmtHm(Duration(seconds: total)),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                            Text(
                              '  ·  ${cats.length} ${cats.length == 1 ? 'gattino' : 'gattini'}',
                              style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  DaySessions(sessions: sessions),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Sessions of a day as soft cards; tap to edit.
class DaySessions extends StatelessWidget {
  const DaySessions({super.key, required this.sessions});
  final List<SessionWork> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return EmptyState(
        art: KittenView(skin: kSkins.first, pose: Pose.dorme, size: 110),
        title: 'Nessuna sessione',
        subtitle: 'Avvia il focus, oppure aggiungine una a mano.',
      );
    }
    final sorted = [...sessions]..sort((a, b) => a.session.startedAt.compareTo(b.session.startedAt));
    return StreamBuilder<List<Activity>>(
      stream: db.watchActivities(includeArchived: true),
      builder: (context, aSnap) {
        final acts = {for (final a in aSnap.data ?? const <Activity>[]) a.id: a};
        return Column(
          children: [
            for (var i = 0; i < sorted.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StaggeredIn(
                  index: i,
                  child: _SessionCard(session: sorted[i].session, activity: acts[sorted[i].session.activityId]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.activity});
  final Session session;
  final Activity? activity;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return StreamBuilder<List<Segment>>(
      stream: db.watchSegmentsOf(session.id),
      builder: (context, snap) {
        final segs = snap.data ?? const <Segment>[];
        final act = activity;
        return Builder(
          builder: (context) {
            final color = activityColor(act?.color ?? 0xFF93C4A0, dark: tc.dark);
            final work = Tracker.worked(segs);
            final pause = Tracker.paused(segs);
            final running = session.endedAt == null;
            return SoftCard(
              onTap: () => showSoftSheet<void>(context, builder: (_) => _EditSheet(sessionId: session.id)),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: activitySoft(act?.color ?? 0xFF93C4A0, dark: tc.dark),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconFor(act?.icon ?? 'circle'), color: color, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act?.name ?? 'Attività',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                            ),
                            Text(
                              '${DateFormat.Hm().format(session.startedAt)} – '
                              '${running ? 'in corso' : DateFormat.Hm().format(session.endedAt!)}'
                              '${pause.inMinutes > 0 ? ' · pausa ${fmtHm(pause)}' : ''}',
                              style: TextStyle(color: tc.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Text(fmtHm(work), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(width: 4),
                      KittenView(skin: skinById(session.skinId), size: 34, animate: false),
                    ],
                  ),
                  if (segs.length > 1) ...[
                    const SizedBox(height: 12),
                    _Timeline(segments: segs, color: color, pause: tc.pause),
                  ],
                  if (session.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(session.note, style: TextStyle(color: tc.muted, fontSize: 13)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.segments, required this.color, required this.pause});
  final List<Segment> segments;
  final Color color, pause;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (final s in segments)
              Expanded(
                flex: ((s.endedAt ?? now).difference(s.startedAt).inSeconds).clamp(1, 1 << 30),
                child: Container(
                  margin: const EdgeInsets.only(right: 2),
                  color: s.isPause ? pause.withValues(alpha: 0.6) : color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditSheet extends StatelessWidget {
  const _EditSheet({required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      builder: (context, controller) => StreamBuilder<Session?>(
        stream: db.watchSession(sessionId),
        builder: (context, sSnap) {
          final session = sSnap.data;
          if (session == null) return const SizedBox.shrink();
          return StreamBuilder<List<Segment>>(
            stream: db.watchSegmentsOf(sessionId),
            builder: (context, snap) {
              final segs = snap.data ?? const <Segment>[];
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  Text('Modifica sessione', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  StreamBuilder<List<Activity>>(
                    stream: db.watchActivities(),
                    builder: (context, aSnap) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final a in aSnap.data ?? const <Activity>[])
                          ChoiceChip(
                            avatar: Icon(iconFor(a.icon), size: 16, color: activityColor(a.color, dark: tc.dark)),
                            label: Text(a.name),
                            showCheckmark: false,
                            shape: const StadiumBorder(),
                            selected: a.id == session.activityId,
                            onSelected: (_) async {
                              await (db.update(db.sessions)..where((s) => s.id.equals(sessionId))).write(
                                SessionsCompanion(activityId: Value(a.id)),
                              );
                              await tracker.sync();
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: session.note,
                    decoration: const InputDecoration(hintText: 'Nota'),
                    onChanged: (v) => db.updateSessionNote(sessionId, v),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('Blocchi', style: Theme.of(context).textTheme.titleSmall),
                      const Spacer(),
                      Text('tocca l\'ora per correggerla', style: TextStyle(color: tc.muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final seg in segs) _SegmentRow(segment: seg, sessionId: sessionId),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PillButton(
                      label: 'Aggiungi blocco',
                      icon: Icons.add_rounded,
                      kind: PillKind.soft,
                      onTap: () => _addSegment(session, segs),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PillButton(
                      label: 'Elimina sessione',
                      icon: Icons.delete_outline_rounded,
                      kind: PillKind.ghost,
                      color: tc.danger,
                      onTap: () => _delete(context, session, segs),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addSegment(Session session, List<Segment> segs) async {
    final start = segs.isEmpty ? session.startedAt : (segs.last.endedAt ?? DateTime.now());
    await db
        .into(db.segments)
        .insert(
          SegmentsCompanion.insert(
            sessionId: session.id,
            isPause: false,
            startedAt: start,
            endedAt: Value(start.add(const Duration(minutes: 15))),
          ),
        );
    await db.reshapeSession(session.id);
  }

  /// Deletes, with an "Annulla" that puts everything back.
  Future<void> _delete(BuildContext context, Session session, List<Segment> segs) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await db.deleteSession(session.id);
    await tracker.sync();
    nav.pop();
    Haptic.medium();
    showUndo(messenger, 'Sessione eliminata', () async {
      await db.into(db.sessions).insert(session);
      for (final s in segs) {
        await db.into(db.segments).insert(s);
      }
      await tracker.sync();
    });
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.segment, required this.sessionId});
  final Segment segment;
  final int sessionId;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: segment.isPause ? tc.pauseSoft : tc.raised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: segment.isPause ? 'Pausa (tocca per lavoro)' : 'Lavoro (tocca per pausa)',
            icon: Icon(
              segment.isPause ? Icons.local_cafe_rounded : Icons.spa_rounded,
              size: 20,
              color: segment.isPause ? tc.pause : tc.accent,
            ),
            onPressed: () async {
              await (db.update(
                db.segments,
              )..where((s) => s.id.equals(segment.id))).write(SegmentsCompanion(isPause: Value(!segment.isPause)));
              await tracker.sync();
            },
          ),
          _TimeButton(
            time: segment.startedAt,
            label: 'Inizio del blocco',
            onChanged: (v) async {
              // A start after the end means the block began the day before.
              final end = segment.endedAt;
              final start = end != null && v.isAfter(end) ? v.subtract(const Duration(days: 1)) : v;
              await (db.update(
                db.segments,
              )..where((s) => s.id.equals(segment.id))).write(SegmentsCompanion(startedAt: Value(start)));
              await db.reshapeSession(sessionId);
              await tracker.sync();
            },
          ),
          Text('–', style: TextStyle(color: tc.muted)),
          _TimeButton(
            time: segment.endedAt,
            label: 'Fine del blocco',
            onChanged: (v) async {
              // An end before the start means it crossed midnight.
              final end = v.isBefore(segment.startedAt) ? v.add(const Duration(days: 1)) : v;
              await (db.update(
                db.segments,
              )..where((s) => s.id.equals(segment.id))).write(SegmentsCompanion(endedAt: Value(end)));
              await db.reshapeSession(sessionId);
              await tracker.sync();
            },
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Rimuovi blocco',
            icon: Icon(Icons.close_rounded, size: 18, color: tc.muted),
            onPressed: () async {
              await db.deleteSegment(segment.id);
              await db.reshapeSession(sessionId);
              await tracker.sync();
            },
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.time, required this.onChanged, required this.label});
  final DateTime? time;
  final ValueChanged<DateTime> onChanged;

  /// For screen readers: which time this is.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: TextButton(
        onPressed: () async {
          final base = time ?? DateTime.now();
          final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
          if (picked == null) return;
          onChanged(DateTime(base.year, base.month, base.day, picked.hour, picked.minute));
        },
        child: Text(
          time == null ? 'in corso' : DateFormat.Hm().format(time!),
          style: TextStyle(color: context.tc.text, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// "Ho dimenticato di avviarlo": a finished session added by hand.
Future<void> addManualSession(BuildContext context, {DateTime? day}) async {
  final acts = await db.watchActivities().first;
  if (acts.isEmpty || !context.mounted) return;
  final prefs = await db.allPrefs();
  var activityId = acts.first.id;
  var d = day ?? DateTime.now();
  var from = const TimeOfDay(hour: 9, minute: 0);
  var to = const TimeOfDay(hour: 10, minute: 0);
  if (!context.mounted) return;

  await showSoftSheet<void>(
    context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final tc = context.tc;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aggiungi sessione', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in acts)
                      ChoiceChip(
                        avatar: Icon(iconFor(a.icon), size: 16, color: activityColor(a.color, dark: tc.dark)),
                        label: Text(a.name),
                        showCheckmark: false,
                        shape: const StadiumBorder(),
                        selected: a.id == activityId,
                        onSelected: (_) => setState(() => activityId = a.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: const Text('Giorno'),
                  trailing: Text(
                    DateFormat('d MMM y', 'it').format(d),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: d,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (p != null) setState(() => d = p);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Dalle'),
                  trailing: Text(from.format(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () async {
                    final p = await showTimePicker(context: context, initialTime: from);
                    if (p != null) setState(() => from = p);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Alle'),
                  trailing: Text(to.format(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () async {
                    final p = await showTimePicker(context: context, initialTime: to);
                    if (p != null) setState(() => to = p);
                  },
                ),
                const SizedBox(height: 12),
                PillButton(
                  label: 'Aggiungi',
                  icon: Icons.check_rounded,
                  expand: true,
                  onTap: () async {
                    final start = DateTime(d.year, d.month, d.day, from.hour, from.minute);
                    var end = DateTime(d.year, d.month, d.day, to.hour, to.minute);
                    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    final clash = await db.segmentsBetween(start, end);
                    await db.addManualSession(
                      activityId: activityId,
                      start: start,
                      end: end,
                      skinId: prefs['activeSkin'] ?? kSkins.first.id,
                    );
                    nav.pop();
                    if (clash.isNotEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Aggiunta, ma si sovrappone a un\'altra sessione')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
