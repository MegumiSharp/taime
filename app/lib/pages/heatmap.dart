import 'package:flutter/material.dart';

import '../app.dart';
import '../db.dart';
import '../theme.dart';
import '../ui/motion.dart';

/// Minutes of work per calendar day in [from, to), splitting segments that
/// cross midnight.
Map<DateTime, double> minutesPerDay(
  Iterable<Segment> segs,
  DateTime from,
  DateTime to, {
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final out = <DateTime, double>{};
  for (final s in segs) {
    if (s.isPause) continue;
    var a = s.startedAt.isBefore(from) ? from : s.startedAt;
    final end = (s.endedAt ?? n).isAfter(to) ? to : (s.endedAt ?? n);
    while (a.isBefore(end)) {
      final day = DateTime(a.year, a.month, a.day);
      final next = DateTime(a.year, a.month, a.day + 1);
      final cut = end.isBefore(next) ? end : next;
      out[day] = (out[day] ?? 0) + cut.difference(a).inSeconds / 60;
      a = cut;
    }
  }
  return out;
}

/// GitHub-style grid of the last [weeks] weeks, greener where you worked more.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, this.weeks = 20});
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day + 1);
    // Start on a Monday so columns are weeks.
    final lastMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final start = DateTime(lastMonday.year, lastMonday.month, lastMonday.day - 7 * (weeks - 1));

    return StreamBuilder<List<({Segment segment, int activityId})>>(
      stream: db.watchRange(start, end),
      builder: (context, snap) {
        final perDay = minutesPerDay(
          (snap.data ?? const []).map((r) => r.segment),
          start,
          end,
        );
        final total = perDay.values.fold(0.0, (a, b) => a + b);
        final maxV = perDay.values.fold(0.0, (a, b) => b > a ? b : a);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tc.surface.withValues(alpha: tc.dark ? 0.6 : 0.75),
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Ultime $weeks settimane', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    fmtHm(Duration(minutes: total.round())),
                    style: TextStyle(color: tc.accent, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  const gap = 4.0;
                  final cell = ((box.maxWidth - gap * (weeks - 1)) / weeks).clamp(6.0, 16.0);
                  return SizedBox(
                    height: cell * 7 + gap * 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var w = 0; w < weeks; w++)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var d = 0; d < 7; d++)
                                _cell(
                                  context,
                                  DateTime(start.year, start.month, start.day + w * 7 + d),
                                  perDay,
                                  maxV,
                                  cell,
                                  today,
                                  w * 7 + d,
                                ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime day,
    Map<DateTime, double> perDay,
    double maxV,
    double size,
    DateTime today,
    int index,
  ) {
    final tc = context.tc;
    final future = day.isAfter(today);
    final v = perDay[day] ?? 0;
    final t = maxV == 0 ? 0.0 : (v / maxV);
    final color = future
        ? Colors.transparent
        : v == 0
        ? tc.outline.withValues(alpha: 0.8)
        : Color.lerp(tc.accentSoft, tc.accent, 0.15 + 0.85 * t)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Duration(milliseconds: 300 + (index % 40) * 12)),
      curve: Motion.curve,
      builder: (context, a, _) => Transform.scale(
        scale: 0.6 + 0.4 * a,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: color.a * a),
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
        ),
      ),
    );
  }
}
