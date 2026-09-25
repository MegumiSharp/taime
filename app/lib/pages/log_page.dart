import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../db.dart';
import '../icons.dart';
import '../settings.dart';
import '../theme.dart';
import '../tracker.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key, required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addManual(context, settings),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Aggiungi'),
      ),
      body: StreamBuilder<List<Session>>(
        stream: db.watchSessionsBetween(
          DateTime(2000),
          DateTime.now().add(const Duration(days: 1)),
        ),
        builder: (context, snap) {
          final sessions = snap.data ?? const <Session>[];
          if (sessions.isEmpty) {
            return const _Empty(
              icon: Icons.checklist_rounded,
              text: 'Nessuna sessione ancora.\nAvvia il timer o aggiungine una a mano.',
            );
          }
          final days = <DateTime, List<Session>>{};
          for (final s in sessions) {
            final d = DateTime(
              s.startedAt.year,
              s.startedAt.month,
              s.startedAt.day,
            );
            days.putIfAbsent(d, () => []).add(s);
          }
          final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            itemCount: keys.length,
            itemBuilder: (context, i) => _DaySection(
              day: keys[i],
              sessions: days[keys[i]]!,
              settings: settings,
            ),
          );
        },
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.sessions,
    required this.settings,
  });
  final DateTime day;
  final List<Session> sessions;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = DateFormat('EEEE d MMMM', 'it').format(day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${label[0].toUpperCase()}${label.substring(1)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              _DayTotal(day: day),
            ],
          ),
        ),
        for (final s in sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SessionCard(session: s, settings: settings),
          ),
      ],
    );
  }
}

class _DayTotal extends StatelessWidget {
  const _DayTotal({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final to = day.add(const Duration(days: 1));
    return StreamBuilder<List<Segment>>(
      stream: db.watchSegmentsBetween(day, to),
      builder: (context, snap) {
        final segs = snap.data ?? const <Segment>[];
        return Text(
          fmtHm(_clip(segs, day, to)),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}

Duration _clip(List<Segment> segs, DateTime from, DateTime to, {bool pause = false}) {
  final now = DateTime.now();
  var total = Duration.zero;
  for (final s in segs) {
    if (s.isPause != pause) continue;
    final start = s.startedAt.isBefore(from) ? from : s.startedAt;
    final rawEnd = s.endedAt ?? now;
    final end = rawEnd.isAfter(to) ? to : rawEnd;
    if (end.isAfter(start)) total += end.difference(start);
  }
  return total;
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.settings});
  final Session session;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return StreamBuilder<List<Segment>>(
      stream: db.watchSegmentsOf(session.id),
      builder: (context, snap) {
        final segs = snap.data ?? const <Segment>[];
        return FutureBuilder<Activity?>(
          future: db.activityById(session.activityId),
          builder: (context, actSnap) {
            final act = actSnap.data;
            final color = act == null
                ? theme.colorScheme.primary
                : activityColor(act.colorIndex, settings.palette, dark: dark);
            final work = Tracker.worked(segs);
            final pause = Tracker.paused(segs);
            final running = session.endedAt == null;
            return Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(kRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(kRadius),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _EditSheet(
                    sessionId: session.id,
                    settings: settings,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              iconFor(act?.icon ?? 'circle'),
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  act?.name ?? 'Attività',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${DateFormat.Hm().format(session.startedAt)} – '
                                  '${running ? 'in corso' : DateFormat.Hm().format(session.endedAt!)}'
                                  '${pause.inMinutes > 0 ? ' · pausa ${fmtHm(pause)}' : ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            fmtHm(work),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (segs.length > 1) ...[
                        const SizedBox(height: 12),
                        _Timeline(segments: segs, color: color),
                      ],
                      if (session.note.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          session.note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.segments, required this.color});
  final List<Segment> segments;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final flexes = segments
        .map((s) => ((s.endedAt ?? now).difference(s.startedAt).inSeconds).clamp(1, 1 << 30))
        .toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++)
              Expanded(
                flex: flexes[i],
                child: Container(
                  color: segments[i].isPause
                      ? theme.colorScheme.outline
                      : color,
                  margin: const EdgeInsets.only(right: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditSheet extends StatelessWidget {
  const _EditSheet({required this.sessionId, required this.settings});
  final int sessionId;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => StreamBuilder<List<Segment>>(
        stream: db.watchSegmentsOf(sessionId),
        builder: (context, snap) {
          final segs = snap.data ?? const <Segment>[];
          return FutureBuilder<Session?>(
            future: db.sessionById(sessionId),
            builder: (context, sSnap) {
              final session = sSnap.data;
              if (session == null) return const SizedBox.shrink();
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Modifica sessione',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<Activity>>(
                    stream: db.watchActivities(),
                    builder: (context, aSnap) {
                      final acts = aSnap.data ?? const <Activity>[];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in acts)
                            ChoiceChip(
                              label: Text(a.name),
                              selected: a.id == session.activityId,
                              onSelected: (_) async {
                                await (db.update(db.sessions)
                                      ..where((s) => s.id.equals(sessionId)))
                                    .write(
                                      SessionsCompanion(
                                        activityId: Value(a.id),
                                      ),
                                    );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: session.note,
                    decoration: const InputDecoration(labelText: 'Nota'),
                    onChanged: (v) => db.updateSessionNote(sessionId, v),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Blocchi',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'tocca l\'ora per correggerla',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final seg in segs)
                    _SegmentRow(segment: seg, sessionId: sessionId),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _addSegment(context, session, segs),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Aggiungi blocco'),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      await db.deleteSession(sessionId);
                      await tracker.sync();
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Sessione eliminata')),
                      );
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Elimina sessione'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
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

  Future<void> _addSegment(
    BuildContext context,
    Session session,
    List<Segment> segs,
  ) async {
    final last = segs.isEmpty ? null : segs.last;
    final start = last?.endedAt ?? session.startedAt;
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
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.segment, required this.sessionId});
  final Segment segment;
  final int sessionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: segment.isPause ? 'Pausa' : 'Lavoro',
            icon: Icon(
              segment.isPause
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 18,
              color: segment.isPause
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
            ),
            onPressed: () async {
              await (db.update(db.segments)
                    ..where((s) => s.id.equals(segment.id)))
                  .write(SegmentsCompanion(isPause: Value(!segment.isPause)));
            },
          ),
          _TimeButton(
            time: segment.startedAt,
            onChanged: (v) async {
              await (db.update(db.segments)
                    ..where((s) => s.id.equals(segment.id)))
                  .write(SegmentsCompanion(startedAt: Value(v)));
              await db.reshapeSession(sessionId);
            },
          ),
          const Text('–'),
          _TimeButton(
            time: segment.endedAt,
            onChanged: (v) async {
              await (db.update(db.segments)
                    ..where((s) => s.id.equals(segment.id)))
                  .write(SegmentsCompanion(endedAt: Value(v)));
              await db.reshapeSession(sessionId);
              await tracker.sync();
            },
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
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
  const _TimeButton({required this.time, required this.onChanged});
  final DateTime? time;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        final base = time ?? DateTime.now();
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(base),
        );
        if (picked == null) return;
        onChanged(
          DateTime(
            base.year,
            base.month,
            base.day,
            picked.hour,
            picked.minute,
          ),
        );
      },
      child: Text(
        time == null ? 'in corso' : DateFormat.Hm().format(time!),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _addManual(BuildContext context, Settings settings) async {
  final acts = await db.watchActivities().first;
  if (acts.isEmpty || !context.mounted) return;
  var activityId = acts.first.id;
  var day = DateTime.now();
  var from = const TimeOfDay(hour: 9, minute: 0);
  var to = const TimeOfDay(hour: 10, minute: 0);

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Aggiungi sessione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final a in acts)
                  ChoiceChip(
                    label: Text(a.name),
                    selected: a.id == activityId,
                    onSelected: (_) => setState(() => activityId = a.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Giorno'),
              trailing: Text(DateFormat('d MMM y', 'it').format(day)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => day = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dalle'),
              trailing: Text(from.format(context)),
              onTap: () async {
                final p = await showTimePicker(context: context, initialTime: from);
                if (p != null) setState(() => from = p);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alle'),
              trailing: Text(to.format(context)),
              onTap: () async {
                final p = await showTimePicker(context: context, initialTime: to);
                if (p != null) setState(() => to = p);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              final start = DateTime(
                day.year,
                day.month,
                day.day,
                from.hour,
                from.minute,
              );
              var end = DateTime(day.year, day.month, day.day, to.hour, to.minute);
              if (!end.isAfter(start)) {
                end = end.add(const Duration(days: 1)); // crossed midnight
              }
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final clash = await db.segmentsBetween(start, end);
              await db.addManualSession(
                activityId: activityId,
                start: start,
                end: end,
              );
              navigator.pop();
              if (clash.isNotEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Aggiunta, ma si sovrappone a un\'altra sessione'),
                  ),
                );
              }
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    ),
  );
}
