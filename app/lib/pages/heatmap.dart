import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../db.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';

/// Minutes of work per calendar day in [from, to), splitting segments that
/// cross midnight.
Map<DateTime, double> minutesPerDay(Iterable<Segment> segs, DateTime from, DateTime to, {DateTime? now}) {
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

/// Days in a row (ending today, or yesterday if today is not done yet) that
/// reached [goalMinutes].
int goalStreak(Map<DateTime, double> perDay, double goalMinutes, DateTime now) {
  if (goalMinutes <= 0) return 0;
  var d = DateTime(now.year, now.month, now.day);
  if ((perDay[d] ?? 0) < goalMinutes) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while ((perDay[d] ?? 0) >= goalMinutes) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

/// Today at a glance: hours per activity, the daily goal and the streak.
///
/// [hero] is the big card shown under "Inizia" while the timer is stopped or
/// paused; otherwise only a row of dashes, one per half hour of the goal.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.goalMinutes, this.now, this.hero = false});
  final int goalMinutes;
  final DateTime? now;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final from = DateTime(today.year, today.month, today.day - 400);
    return Live<List<Activity>>(
      id: 'activities',
      stream: () => db.watchActivities(includeArchived: true),
      builder: (context, aSnap) {
        final acts = {for (final a in aSnap.data ?? const <Activity>[]) a.id: a};
        return Live<List<Segment>>(
          id: today,
          stream: () => db.watchSegmentsBetween(from, tomorrow),
          builder: (context, snap) => Live<List<({Segment segment, int activityId})>>(
            id: today,
            stream: () => db.watchRange(today, tomorrow),
            builder: (context, tSnap) {
              final perActivity = <int, double>{};
              for (final r in tSnap.data ?? const <({Segment segment, int activityId})>[]) {
                final m = minutesPerDay([r.segment], today, tomorrow, now: n)[today] ?? 0;
                if (m > 0) perActivity[r.activityId] = (perActivity[r.activityId] ?? 0) + m;
              }
              final sorted = perActivity.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final done = perActivity.values.fold(0.0, (a, b) => a + b);
              final perDay = minutesPerDay(snap.data ?? const [], from, tomorrow, now: n);
              final streak = goalStreak(perDay, goalMinutes.toDouble(), n);
              final reached = goalMinutes > 0 && done >= goalMinutes;
              Color colorOf(int id) => activityColor(acts[id]?.color ?? 0xFF93C4A0, dark: tc.dark);
              // The bar is the goal (or the day's total when there is none).
              final whole = goalMinutes > 0 && done < goalMinutes ? goalMinutes.toDouble() : done;
              final doneText = fmtHm(Duration(minutes: done.floor()));
              final goalText = goalMinutes > 0 ? '$doneText / ${fmtHm(Duration(minutes: goalMinutes))}' : null;

              final streakChip = streak > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: tc.pauseSoft, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_rounded, size: 15, color: tc.pause),
                          const SizedBox(width: 3),
                          Text(
                            streak == 1 ? '1 giorno' : '$streak giorni',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: tc.text),
                          ),
                        ],
                      ),
                    )
                  : null;

              final bar = ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: hero ? 10 : 12,
                  color: tc.raised,
                  child: LayoutBuilder(
                    builder: (context, box) => Row(
                      children: [
                        for (final e in sorted)
                          AnimatedContainer(
                            duration: Motion.of(context, Motion.slow),
                            curve: Motion.curve,
                            width: whole <= 0 ? 0 : box.maxWidth * e.value / whole,
                            color: colorOf(e.key),
                          ),
                      ],
                    ),
                  ),
                ),
              );

              final legend = sorted.isEmpty
                  ? Text(
                      goalMinutes > 0
                          ? 'Ancora niente oggi: il primo focus ti avvicina all\'obiettivo.'
                          : 'Ancora niente oggi.',
                      textAlign: hero ? TextAlign.center : TextAlign.start,
                      style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600, fontSize: 13),
                    )
                  : Wrap(
                      alignment: hero ? WrapAlignment.center : WrapAlignment.start,
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        for (final e in sorted)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(color: colorOf(e.key), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                acts[e.key]?.name ?? 'Attività',
                                style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fmtHm(Duration(minutes: e.value.floor())),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ],
                          ),
                      ],
                    );

              final decoration = BoxDecoration(
                color: tc.surface.withValues(alpha: tc.dark ? 0.6 : 0.75),
                borderRadius: BorderRadius.circular(kRadius),
              );

              if (hero) {
                return Semantics(
                  container: true,
                  label:
                      'Oggi $doneText${goalText == null ? '' : ', obiettivo ${fmtHm(Duration(minutes: goalMinutes))}'}',
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    decoration: decoration,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'Oggi',
                              style: TextStyle(color: tc.muted, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            ?streakChip,
                            if (streakChip == null && reached)
                              Icon(Icons.emoji_events_rounded, size: 20, color: tc.accent),
                          ],
                        ),
                        ExcludeSemantics(
                          child: Text(
                            doneText,
                            style: timerStyle(context, size: 52).copyWith(fontWeight: FontWeight.w300, height: 1.15),
                          ),
                        ),
                        const SizedBox(height: 8),
                        bar,
                        if (goalText != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            reached ? '$goalText · obiettivo raggiunto' : goalText,
                            style: TextStyle(color: tc.muted, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 10),
                        legend,
                      ],
                    ),
                  ),
                );
              }

              // While working: only dashes, one per half hour of the goal,
              // coloured by the activity that filled them. No text.
              const slot = 30.0;
              final slots = (math.max(goalMinutes.toDouble(), done) / slot).ceil().clamp(4, 24);
              Color colorAt(double minute) {
                var acc = 0.0;
                for (final e in sorted) {
                  acc += e.value;
                  if (minute < acc) return colorOf(e.key);
                }
                return sorted.isEmpty ? tc.accent : colorOf(sorted.last.key);
              }

              return Semantics(
                label: goalText == null ? 'Oggi $doneText' : 'Oggi $goalText',
                child: Row(
                  children: [
                    for (var i = 0; i < slots; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            height: 6,
                            color: tc.raised,
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: ((done - i * slot) / slot).clamp(0.0, 1.0),
                              child: Container(color: colorAt(i * slot)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
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

    return Live<List<({Segment segment, int activityId})>>(
      id: start,
      stream: () => db.watchRange(start, end),
      builder: (context, snap) {
        final perDay = minutesPerDay((snap.data ?? const []).map((r) => r.segment), start, end);
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
