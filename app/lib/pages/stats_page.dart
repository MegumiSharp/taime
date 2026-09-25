import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../db.dart';
import '../settings.dart';
import '../theme.dart';

enum Period { giorno, settimana, mese, anno }

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.settings});
  final Settings settings;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Period _period = Period.settimana;
  DateTime _anchor = DateTime.now();

  (DateTime, DateTime) get _range {
    final a = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case Period.giorno:
        return (a, a.add(const Duration(days: 1)));
      case Period.settimana:
        final shift = (a.weekday - widget.settings.weekStart + 7) % 7;
        final start = a.subtract(Duration(days: shift));
        return (start, start.add(const Duration(days: 7)));
      case Period.mese:
        final start = DateTime(a.year, a.month);
        return (start, DateTime(a.year, a.month + 1));
      case Period.anno:
        return (DateTime(a.year), DateTime(a.year + 1));
    }
  }

  void _shift(int dir) {
    setState(() {
      switch (_period) {
        case Period.giorno:
          _anchor = _anchor.add(Duration(days: dir));
        case Period.settimana:
          _anchor = _anchor.add(Duration(days: 7 * dir));
        case Period.mese:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
        case Period.anno:
          _anchor = DateTime(_anchor.year + dir, 1, 1);
      }
    });
  }

  String get _label {
    final (from, _) = _range;
    switch (_period) {
      case Period.giorno:
        return DateFormat('EEEE d MMMM', 'it').format(from);
      case Period.settimana:
        final to = from.add(const Duration(days: 6));
        return '${DateFormat('d MMM', 'it').format(from)} – '
            '${DateFormat('d MMM', 'it').format(to)}';
      case Period.mese:
        return DateFormat('MMMM y', 'it').format(from);
      case Period.anno:
        return DateFormat('y').format(from);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (from, to) = _range;

    return StreamBuilder<List<Activity>>(
      stream: db.watchActivities(includeArchived: true),
      builder: (context, actSnap) {
        final acts = {for (final a in actSnap.data ?? <Activity>[]) a.id: a};
        return StreamBuilder<List<({Segment segment, int activityId})>>(
          stream: db.watchRange(from, to),
          builder: (context, snap) {
            final rows = snap.data ?? const [];
            final buckets = _buckets(from, to);
            final perActivity = <int, Duration>{};
            final perBucket = <int, List<Duration>>{};
            var pauseTotal = Duration.zero;

            for (final r in rows) {
              if (r.segment.isPause) {
                pauseTotal += _overlap(r.segment, from, to);
                continue;
              }
              perActivity[r.activityId] =
                  (perActivity[r.activityId] ?? Duration.zero) +
                  _overlap(r.segment, from, to);
              final list = perBucket.putIfAbsent(
                r.activityId,
                () => List.filled(buckets.length - 1, Duration.zero),
              );
              for (var i = 0; i < buckets.length - 1; i++) {
                final d = _overlap(r.segment, buckets[i], buckets[i + 1]);
                if (d > Duration.zero) list[i] = list[i] + d;
              }
            }

            final total = perActivity.values.fold(
              Duration.zero,
              (a, b) => a + b,
            );
            final sorted = perActivity.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Statistiche',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<Period>(
                  segments: const [
                    ButtonSegment(value: Period.giorno, label: Text('Giorno')),
                    ButtonSegment(value: Period.settimana, label: Text('Sett.')),
                    ButtonSegment(value: Period.mese, label: Text('Mese')),
                    ButtonSegment(value: Period.anno, label: Text('Anno')),
                  ],
                  selected: {_period},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => _period = v.first),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _shift(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(
                      _label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _shift(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _Card(
                  child: Row(
                    children: [
                      _Stat(label: 'Lavoro', value: fmtHm(total), big: true),
                      const SizedBox(width: 24),
                      _Stat(label: 'Pausa', value: fmtHm(pauseTotal)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (total > Duration.zero) ...[
                  _Card(
                    child: SizedBox(
                      height: 180,
                      child: _Bars(
                        buckets: buckets,
                        perBucket: perBucket,
                        activities: acts,
                        settings: widget.settings,
                        period: _period,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 160,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 46,
                              sections: [
                                for (final e in sorted)
                                  PieChartSectionData(
                                    value: e.value.inSeconds.toDouble(),
                                    color: _color(e.key, acts, context),
                                    radius: 26,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final e in sorted)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _color(e.key, acts, context),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(acts[e.key]?.name ?? 'Attività'),
                                ),
                                Text(
                                  '${(e.value.inSeconds / total.inSeconds * 100).round()}%',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  fmtHm(e.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  _Card(
                    child: SizedBox(
                      height: 80,
                      child: Center(
                        child: Text(
                          'Nessun tempo registrato in questo periodo',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_period == Period.anno) ...[
                  const SizedBox(height: 12),
                  _Card(
                    child: _Heatmap(
                      year: from.year,
                      settings: widget.settings,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _AllTime(settings: widget.settings),
              ],
            );
          },
        );
      },
    );
  }

  Color _color(int id, Map<int, Activity> acts, BuildContext context) {
    final a = acts[id];
    return a == null
        ? Theme.of(context).colorScheme.primary
        : activityColor(
            a.colorIndex,
            widget.settings.palette,
            dark: Theme.of(context).brightness == Brightness.dark,
          );
  }

  List<DateTime> _buckets(DateTime from, DateTime to) {
    switch (_period) {
      case Period.giorno:
        return [for (var h = 0; h <= 24; h++) from.add(Duration(hours: h))];
      case Period.settimana:
        return [for (var d = 0; d <= 7; d++) from.add(Duration(days: d))];
      case Period.mese:
        final days = DateTime(from.year, from.month + 1, 0).day;
        return [for (var d = 0; d <= days; d++) DateTime(from.year, from.month, 1 + d)];
      case Period.anno:
        return [for (var m = 0; m <= 12; m++) DateTime(from.year, 1 + m)];
    }
  }
}

Duration _overlap(Segment s, DateTime from, DateTime to) {
  final now = DateTime.now();
  final start = s.startedAt.isBefore(from) ? from : s.startedAt;
  final rawEnd = s.endedAt ?? now;
  final end = rawEnd.isAfter(to) ? to : rawEnd;
  return end.isAfter(start) ? end.difference(start) : Duration.zero;
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.buckets,
    required this.perBucket,
    required this.activities,
    required this.settings,
    required this.period,
  });
  final List<DateTime> buckets;
  final Map<int, List<Duration>> perBucket;
  final Map<int, Activity> activities;
  final Settings settings;
  final Period period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final n = buckets.length - 1;
    final ids = perBucket.keys.toList();

    double maxY = 0;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < n; i++) {
      var acc = 0.0;
      final stack = <BarChartRodStackItem>[];
      for (final id in ids) {
        final h = perBucket[id]![i].inSeconds / 3600;
        if (h <= 0) continue;
        final a = activities[id];
        stack.add(
          BarChartRodStackItem(
            acc,
            acc + h,
            a == null
                ? theme.colorScheme.primary
                : activityColor(a.colorIndex, settings.palette, dark: dark),
          ),
        );
        acc += h;
      }
      maxY = acc > maxY ? acc : maxY;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: acc,
              rodStackItems: stack,
              width: n > 20 ? 6 : 16,
              borderRadius: BorderRadius.circular(6),
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.15,
        barGroups: groups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: theme.colorScheme.outline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, meta) => Text(
                v == 0 ? '' : '${v.round()}h',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= n) return const SizedBox.shrink();
                final d = buckets[i];
                final text = switch (period) {
                  Period.giorno => i % 6 == 0 ? '${d.hour}' : '',
                  Period.settimana => DateFormat.E('it').format(d).substring(0, 3),
                  Period.mese => d.day % 5 == 1 ? '${d.day}' : '',
                  Period.anno => DateFormat.MMM('it').format(d).substring(0, 1),
                };
                return Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// GitHub-style year grid.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.year, required this.settings});
  final int year;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = DateTime(year);
    final to = DateTime(year + 1);
    return StreamBuilder<List<({Segment segment, int activityId})>>(
      stream: db.watchRange(from, to),
      builder: (context, snap) {
        final perDay = <int, Duration>{};
        for (final r in snap.data ?? const []) {
          if (r.segment.isPause) continue;
          var d = DateTime(
            r.segment.startedAt.year,
            r.segment.startedAt.month,
            r.segment.startedAt.day,
          );
          final end = r.segment.endedAt ?? DateTime.now();
          while (d.isBefore(end)) {
            final next = d.add(const Duration(days: 1));
            final o = _overlap(r.segment, d, next);
            if (o > Duration.zero) {
              perDay[d.difference(from).inDays] =
                  (perDay[d.difference(from).inDays] ?? Duration.zero) + o;
            }
            d = next;
          }
        }
        final maxD = perDay.values.fold(
          Duration.zero,
          (a, b) => b > a ? b : a,
        );
        final days = to.difference(from).inDays;
        final firstWeekday = (from.weekday - settings.weekStart + 7) % 7;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attività $year',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var w = 0; w * 7 < days + firstWeekday; w++)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Column(
                        children: [
                          for (var wd = 0; wd < 7; wd++)
                            Builder(
                              builder: (context) {
                                final index = w * 7 + wd - firstWeekday;
                                final d = perDay[index] ?? Duration.zero;
                                final t = maxD.inSeconds == 0
                                    ? 0.0
                                    : d.inSeconds / maxD.inSeconds;
                                return Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(bottom: 3),
                                  decoration: BoxDecoration(
                                    color: index < 0 || index >= days
                                        ? Colors.transparent
                                        : Color.lerp(
                                            theme.colorScheme.outline,
                                            theme.colorScheme.primary,
                                            t == 0 ? 0 : 0.25 + 0.75 * t,
                                          ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AllTime extends StatelessWidget {
  const _AllTime({required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return StreamBuilder<List<Activity>>(
      stream: db.watchActivities(includeArchived: true),
      builder: (context, actSnap) {
        final acts = {for (final a in actSnap.data ?? <Activity>[]) a.id: a};
        return StreamBuilder<List<({Segment segment, int activityId})>>(
          stream: db.watchRange(DateTime(2000), DateTime(2100)),
          builder: (context, snap) {
            final totals = <int, Duration>{};
            for (final r in snap.data ?? const []) {
              if (r.segment.isPause) continue;
              totals[r.activityId] =
                  (totals[r.activityId] ?? Duration.zero) +
                  (r.segment.endedAt ?? DateTime.now()).difference(
                    r.segment.startedAt,
                  );
            }
            final sorted = totals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            if (sorted.isEmpty) return const SizedBox.shrink();
            return _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Totale di sempre',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final e in sorted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: acts[e.key] == null
                                  ? theme.colorScheme.primary
                                  : activityColor(
                                      acts[e.key]!.colorIndex,
                                      settings.palette,
                                      dark: dark,
                                    ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(acts[e.key]?.name ?? 'Attività')),
                          Text(
                            fmtHm(e.value),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: child,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.big = false});
  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: (big ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
