import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../db.dart';
import '../icons.dart';
import '../settings.dart';
import '../theme.dart';
import '../tracker.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key, required this.settings});
  final Settings settings;

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  late final Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Session?>(
      stream: db.watchOpenSession(),
      builder: (context, sessionSnap) {
        final session = sessionSnap.data;
        return StreamBuilder<List<Segment>>(
          stream: session == null
              ? Stream.value(const <Segment>[])
              : db.watchSegmentsOf(session.id),
          builder: (context, segSnap) {
            final segs = segSnap.data ?? const <Segment>[];
            return _body(context, session, segs);
          },
        );
      },
    );
  }

  Widget _body(BuildContext context, Session? session, List<Segment> segs) {
    final theme = Theme.of(context);
    final s = widget.settings;
    final open = segs.where((x) => x.endedAt == null).firstOrNull;
    final onPause = open?.isPause ?? false;
    final worked = Tracker.worked(segs, now: _now);
    final pausedFor = onPause
        ? _now.difference(open!.startedAt)
        : Duration.zero;

    return StreamBuilder<List<Activity>>(
      stream: db.watchActivities(),
      builder: (context, actSnap) {
        final acts = actSnap.data ?? const <Activity>[];
        final current = session == null
            ? null
            : acts.where((a) => a.id == session.activityId).firstOrNull;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Taime', style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
                _TodayTotal(now: _now),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: _Dial(
                worked: worked,
                paused: pausedFor,
                onPause: onPause,
                running: session != null,
                progress: _progress(s, segs, open, worked),
                countdown: _countdown(s, open),
                color: current == null
                    ? theme.colorScheme.primary
                    : activityColor(
                        current.colorIndex,
                        s.palette,
                        dark: theme.brightness == Brightness.dark,
                      ),
                label: current?.name ?? 'Nessuna attività',
                onTap: () => _primaryAction(session, onPause, acts),
              ),
            ),
            const SizedBox(height: 20),
            if (session != null)
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: onPause
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      label: onPause ? 'Riprendi' : 'Pausa',
                      onTap: () => onPause ? tracker.resume() : tracker.pause(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.stop_rounded,
                      label: 'Stop',
                      filled: true,
                      onTap: () => tracker.stop(),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Text(
              session == null ? 'Su cosa lavori?' : 'Cambia attività',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _ActivityGrid(
              activities: acts,
              settings: s,
              currentId: session?.activityId,
              onTap: (a) async {
                if (session == null) {
                  await tracker.start(a.id);
                } else if (a.id == session.activityId) {
                  await tracker.stop();
                } else {
                  await _askSwitch(context, session, a);
                }
              },
            ),
            if (session != null) ...[
              const SizedBox(height: 20),
              _NoteField(session: session),
            ],
          ],
        );
      },
    );
  }

  /// 0..1 ring fill: toward the next break, the pomodoro end, or the hour.
  double _progress(Settings s, List<Segment> segs, Segment? open, Duration worked) {
    if (open == null) return 0;
    final elapsed = _now.difference(open.startedAt);
    if (open.isPause) {
      final mins = s.pomodoro ? s.pomoBreakMin : s.pauseReminderMin;
      if (mins <= 0) return 0;
      return (elapsed.inSeconds / (mins * 60)).clamp(0, 1);
    }
    final target = s.pomodoro
        ? s.pomoWorkMin
        : (s.breakAfterMin > 0 ? s.breakAfterMin : 60);
    return (elapsed.inSeconds / (target * 60)).clamp(0, 1);
  }

  Duration? _countdown(Settings s, Segment? open) {
    if (!s.pomodoro || open == null) return null;
    final mins = open.isPause ? s.pomoBreakMin : s.pomoWorkMin;
    final left = open.startedAt
        .add(Duration(minutes: mins))
        .difference(_now);
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _primaryAction(
    Session? session,
    bool onPause,
    List<Activity> acts,
  ) async {
    if (session != null) {
      await tracker.stop();
      return;
    }
    if (acts.isEmpty) return;
    final last = acts
        .where((a) => a.id == widget.settings.lastActivityId)
        .firstOrNull;
    await tracker.start((last ?? acts.first).id);
  }

  Future<void> _askSwitch(
    BuildContext context,
    Session session,
    Activity target,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: Text('Passa a ${target.name}'),
              subtitle: const Text('Chiude la sessione e ne apre una nuova'),
              onTap: () => Navigator.pop(context, 'switch'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text('Correggi in ${target.name}'),
              subtitle: const Text('Avevo avviato l\'attività sbagliata'),
              onTap: () => Navigator.pop(context, 'fix'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (choice == 'switch') await tracker.start(target.id);
    if (choice == 'fix') await tracker.reassign(target.id);
  }
}

class _Dial extends StatelessWidget {
  const _Dial({
    required this.worked,
    required this.paused,
    required this.onPause,
    required this.running,
    required this.progress,
    required this.countdown,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final Duration worked;
  final Duration paused;
  final bool onPause;
  final bool running;
  final double progress;
  final Duration? countdown;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = math.min(MediaQuery.sizeOf(context).width - 80, 300.0);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress,
            color: onPause ? theme.colorScheme.onSurfaceVariant : color,
            track: theme.colorScheme.outline,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!running)
                  Text(
                    'Start',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  )
                else ...[
                  Text(
                    onPause ? 'In pausa' : label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmtHms(countdown ?? (onPause ? paused : worked)),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    onPause
                        ? 'Lavoro: ${fmtHm(worked)}'
                        : (countdown != null
                              ? 'Lavorato ${fmtHm(worked)}'
                              : 'Tocca per fermare'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );
    canvas.drawCircle(center, radius - 8, Paint()..color = color.withValues(alpha: 0.06));
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = filled ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return Material(
      color: filled ? theme.colorScheme.primary : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(
              color: filled ? Colors.transparent : theme.colorScheme.outline,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid({
    required this.activities,
    required this.settings,
    required this.currentId,
    required this.onTap,
  });
  final List<Activity> activities;
  final Settings settings;
  final int? currentId;
  final ValueChanged<Activity> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final a in activities)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 40 - 12) / 2,
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(kRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(kRadius),
                onTap: () => onTap(a),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(
                      color: a.id == currentId
                          ? activityColor(a.colorIndex, settings.palette, dark: dark)
                          : theme.colorScheme.outline,
                      width: a.id == currentId ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        iconFor(a.icon),
                        size: 24,
                        color: activityColor(
                          a.colorIndex,
                          settings.palette,
                          dark: dark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          a.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoteField extends StatefulWidget {
  const _NoteField({required this.session});
  final Session session;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.session.note,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      decoration: const InputDecoration(hintText: 'Nota (facoltativa)'),
      onChanged: (v) => db.updateSessionNote(widget.session.id, v),
    );
  }
}

class _TodayTotal extends StatelessWidget {
  const _TodayTotal({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = DateTime(now.year, now.month, now.day);
    return StreamBuilder<List<Segment>>(
      stream: db.watchSegmentsBetween(start, start.add(const Duration(days: 1))),
      builder: (context, snap) {
        final total = clippedWork(
          snap.data ?? const [],
          start,
          start.add(const Duration(days: 1)),
          now: now,
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Text(
            'Oggi ${fmtHm(total)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}

/// Work time inside [from, to), clipping segments that cross the edges.
Duration clippedWork(
  List<Segment> segs,
  DateTime from,
  DateTime to, {
  DateTime? now,
  bool pause = false,
}) {
  final n = now ?? DateTime.now();
  var total = Duration.zero;
  for (final s in segs) {
    if (s.isPause != pause) continue;
    final start = s.startedAt.isBefore(from) ? from : s.startedAt;
    final rawEnd = s.endedAt ?? n;
    final end = rawEnd.isAfter(to) ? to : rawEnd;
    if (end.isAfter(start)) total += end.difference(start);
  }
  return total;
}
