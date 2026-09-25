import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../db.dart';
import '../icons.dart';
import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../settings.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';
import 'day_page.dart';
import 'heatmap.dart';
import 'pen.dart';

/// Lets other screens open the Panoramica on a given period
/// ('giorno' | 'settimana' | 'mese' | 'anno').
final overviewRequest = ValueNotifier<String?>(null);

enum Period { giorno, settimana, mese, anno }

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.settings});
  final Settings settings;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Period _period = Period.settimana;
  DateTime _anchor = DateTime.now();

  @override
  void initState() {
    super.initState();
    _consumeRequest();
    overviewRequest.addListener(_consumeRequest);
  }

  @override
  void dispose() {
    overviewRequest.removeListener(_consumeRequest);
    super.dispose();
  }

  void _consumeRequest() {
    final r = overviewRequest.value;
    if (r == null) return;
    overviewRequest.value = null;
    final p = Period.values.where((p) => p.name == r).firstOrNull;
    if (p == null) return;
    if (mounted) {
      setState(() {
        _period = p;
        _anchor = DateTime.now();
      });
    } else {
      _period = p;
    }
  }

  (DateTime, DateTime) _rangeOf(Period p, DateTime anchor) {
    final a = DateTime(anchor.year, anchor.month, anchor.day);
    switch (p) {
      case Period.giorno:
        return (a, DateTime(a.year, a.month, a.day + 1));
      case Period.settimana:
        final shift = (a.weekday - widget.settings.weekStart + 7) % 7;
        final start = DateTime(a.year, a.month, a.day - shift);
        return (start, DateTime(start.year, start.month, start.day + 7));
      case Period.mese:
        return (DateTime(a.year, a.month), DateTime(a.year, a.month + 1));
      case Period.anno:
        return (DateTime(a.year), DateTime(a.year + 1));
    }
  }

  DateTime _shifted(int dir, [DateTime? from]) {
    final a = from ?? _anchor;
    return switch (_period) {
      Period.giorno => DateTime(a.year, a.month, a.day + dir),
      Period.settimana => DateTime(a.year, a.month, a.day + 7 * dir),
      Period.mese => DateTime(a.year, a.month + dir, 1),
      Period.anno => DateTime(a.year + dir, 1, 1),
    };
  }

  String _label(DateTime from, DateTime to) {
    switch (_period) {
      case Period.giorno:
        return dayLabel(from);
      case Period.settimana:
        final last = DateTime(to.year, to.month, to.day - 1);
        return '${DateFormat('d MMM', 'it').format(from)} – ${DateFormat('d MMM', 'it').format(last)}';
      case Period.mese:
        final s = DateFormat('MMMM y', 'it').format(from);
        return '${s[0].toUpperCase()}${s.substring(1)}';
      case Period.anno:
        return '${from.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final (from, to) = _rangeOf(_period, _anchor);
    return PastelBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Row(
              children: [
                Expanded(child: Text('Panoramica', style: Theme.of(context).textTheme.headlineMedium)),
                IconButton(
                  tooltip: 'Calendario',
                  onPressed: () => showCalendarSheet(context),
                  icon: Icon(Icons.calendar_month_rounded, color: tc.text),
                  style: IconButton.styleFrom(backgroundColor: tc.surface.withValues(alpha: 0.7)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PillSelector<Period>(
              values: Period.values,
              labels: const ['Giorno', 'Settimana', 'Mese', 'Anno'],
              selected: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _anchor = _shifted(-1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.medium),
                    child: Text(
                      _label(from, to),
                      key: ValueKey('$_period$from'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _anchor = _shifted(1)),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _PenCard(
              period: _period,
              from: from,
              to: to,
              weekStart: widget.settings.weekStart,
              onOpenMonth: (m) => setState(() {
                _period = Period.mese;
                _anchor = m;
              }),
            ),
            const SizedBox(height: 14),
            if (_period == Period.giorno)
              StreamBuilder<List<SessionWork>>(
                stream: db.watchSessionWork(from, to),
                builder: (context, snap) => Column(
                  children: [
                    DaySessions(sessions: snap.data ?? const []),
                    const SizedBox(height: 4),
                    PillButton(
                      label: 'Aggiungi sessione',
                      icon: Icons.add_rounded,
                      kind: PillKind.soft,
                      onTap: () => addManualSession(context, day: from),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            _Stats(
              period: _period,
              from: from,
              to: to,
              prevFrom: _rangeOf(_period, _shifted(-1, from)).$1,
              prev2From: _rangeOf(_period, _shifted(-2, from)).$1,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Pen -----------------------------------------------------------------------

class _PenCard extends StatelessWidget {
  const _PenCard({
    required this.period,
    required this.from,
    required this.to,
    required this.weekStart,
    required this.onOpenMonth,
  });

  final Period period;
  final DateTime from, to;
  final int weekStart;
  final ValueChanged<DateTime> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return StreamBuilder<List<SessionWork>>(
      stream: db.watchSessionWork(from, to),
      builder: (context, snap) {
        final sessions = snap.data ?? const <SessionWork>[];
        final byDay = <DateTime, List<SessionWork>>{};
        for (final s in sessions) {
          final d = DateTime(s.session.startedAt.year, s.session.startedAt.month, s.session.startedAt.day);
          byDay.putIfAbsent(d, () => []).add(s);
        }
        final today = DateTime.now();
        final todayKey = DateTime(today.year, today.month, today.day);
        List<PenCat> cats(DateTime d) => catsOf(byDay[d] ?? const []);
        double mins(DateTime d) => (byDay[d] ?? const []).fold(0.0, (a, s) => a + s.workSeconds / 60);
        final allCats = catsOf(sessions);

        late final Widget pen;
        switch (period) {
          case Period.giorno:
            pen = PenView(
              cols: 1,
              rows: 1,
              maxCatsPerTile: 8,
              catScale: 0.3,
              animateCats: true,
              tiles: [
                PenTile(col: 0, row: 0, minutes: mins(from), cats: cats(from), seed: from.millisecondsSinceEpoch ~/ 86400000),
              ],
            );
          case Period.settimana:
            final names = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
            pen = PenView(
              cols: 7,
              rows: 1,
              maxCatsPerTile: 3,
              catScale: 0.56,
              onTap: (t) => _openDay(context, t.payload as DateTime),
              tiles: [
                for (var i = 0; i < 7; i++)
                  () {
                    final d = DateTime(from.year, from.month, from.day + i);
                    return PenTile(
                      col: i,
                      row: 0,
                      minutes: mins(d),
                      cats: cats(d),
                      seed: d.millisecondsSinceEpoch ~/ 86400000,
                      label: names[d.weekday - 1],
                      payload: d,
                      today: d == todayKey,
                    );
                  }(),
              ],
            );
          case Period.mese:
            final lead = (from.weekday - weekStart + 7) % 7;
            final days = DateTime(from.year, from.month + 1, 0).day;
            final rows = ((lead + days) / 7).ceil();
            pen = PenView(
              cols: 7,
              rows: rows,
              maxCatsPerTile: 2,
              catScale: 0.5,
              onTap: (t) => _openDay(context, t.payload as DateTime),
              tiles: [
                for (var i = 0; i < days; i++)
                  () {
                    final d = DateTime(from.year, from.month, i + 1);
                    final cell = lead + i;
                    return PenTile(
                      col: cell % 7,
                      row: cell ~/ 7,
                      minutes: mins(d),
                      cats: cats(d),
                      seed: d.millisecondsSinceEpoch ~/ 86400000,
                      label: '${i + 1}',
                      payload: d,
                      today: d == todayKey,
                    );
                  }(),
              ],
            );
          case Period.anno:
            final names = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
            final byMonth = <int, List<SessionWork>>{};
            for (final s in sessions) {
              byMonth.putIfAbsent(s.session.startedAt.month, () => []).add(s);
            }
            pen = PenView(
              cols: 4,
              rows: 3,
              maxCatsPerTile: 3,
              catScale: 0.42,
              onTap: (t) => onOpenMonth(t.payload as DateTime),
              tiles: [
                for (var m = 1; m <= 12; m++)
                  PenTile(
                    col: (m - 1) % 4,
                    row: (m - 1) ~/ 4,
                    minutes: (byMonth[m] ?? const []).fold(0.0, (a, s) => a + s.workSeconds / 60),
                    cats: catsOf(byMonth[m] ?? const []),
                    seed: from.year * 12 + m,
                    label: names[m - 1],
                    payload: DateTime(from.year, m),
                    today: from.year == today.year && m == today.month,
                  ),
              ],
            );
        }

        return SoftCard(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.slow),
                child: KeyedSubtree(key: ValueKey('$period$from'), child: pen),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets_rounded, size: 16, color: tc.accent),
                  const SizedBox(width: 6),
                  AnimatedCount(
                    allCats.length,
                    format: (n) => n == 1 ? '1 gattino nel recinto' : '$n gattini nel recinto',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (period != Period.giorno)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    period == Period.anno ? 'Tocca un mese per aprirlo' : 'Tocca un giorno per i dettagli',
                    style: TextStyle(color: tc.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

void _openDay(BuildContext context, DateTime day) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayPage(day: day)));
}

// --- Stats -----------------------------------------------------------------------

class _Stats extends StatelessWidget {
  const _Stats({
    required this.period,
    required this.from,
    required this.to,
    required this.prevFrom,
    required this.prev2From,
  });

  final Period period;
  final DateTime from, to, prevFrom, prev2From;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return StreamBuilder<List<Activity>>(
      stream: db.watchActivities(includeArchived: true),
      builder: (context, aSnap) {
        final acts = {for (final a in aSnap.data ?? <Activity>[]) a.id: a};
        return StreamBuilder<List<({Segment segment, int activityId})>>(
          stream: db.watchRange(prev2From, to),
          builder: (context, snap) {
            final rows = snap.data ?? const [];
            Duration sumIn(DateTime a, DateTime b, {bool pause = false}) {
              var t = Duration.zero;
              for (final r in rows) {
                if (r.segment.isPause != pause) continue;
                t += overlap(r.segment, a, b);
              }
              return t;
            }

            final total = sumIn(from, to);
            final pauseTotal = sumIn(from, to, pause: true);
            final prev = sumIn(prevFrom, from);
            final prev2 = sumIn(prev2From, prevFrom);

            final perActivity = <int, Duration>{};
            for (final r in rows) {
              if (r.segment.isPause) continue;
              final d = overlap(r.segment, from, to);
              if (d > Duration.zero) perActivity[r.activityId] = (perActivity[r.activityId] ?? Duration.zero) + d;
            }
            final sorted = perActivity.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            Color colorOf(int id) => activityColor(acts[id]?.color ?? 0xFF93C4A0, dark: tc.dark);

            final buckets = _buckets(period, from);
            final perBucket = <int, List<Duration>>{};
            for (final r in rows) {
              if (r.segment.isPause) continue;
              final list = perBucket.putIfAbsent(r.activityId, () => List.filled(buckets.length - 1, Duration.zero));
              for (var i = 0; i < buckets.length - 1; i++) {
                final d = overlap(r.segment, buckets[i], buckets[i + 1]);
                if (d > Duration.zero) list[i] += d;
              }
            }

            return Column(
              children: [
                SoftCard(
                  child: Row(
                    children: [
                      Expanded(child: _Big(label: 'Concentrazione', value: fmtHm(total))),
                      Expanded(child: _Big(label: 'Pausa', value: fmtHm(pauseTotal), muted: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (total == Duration.zero)
                  SoftCard(
                    child: EmptyState(
                      art: KittenView(skin: kSkins[1], pose: Pose.dorme, size: 100),
                      title: 'Ancora niente qui',
                      subtitle: 'Il tempo che dedichi apparirà in questo periodo.',
                    ),
                  )
                else ...[
                  _Card(
                    title: 'Distribuzione del tempo',
                    child: SizedBox(
                      height: 170,
                      child: _Bars(period: period, buckets: buckets, perBucket: perBucket, colorOf: colorOf),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'Per attività',
                    child: Column(
                      children: [
                        SizedBox(
                          height: 150,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 44,
                              sections: [
                                for (final e in sorted)
                                  PieChartSectionData(
                                    value: e.value.inSeconds.toDouble(),
                                    color: colorOf(e.key),
                                    radius: 24,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final e in sorted)
                          _ActivityRow(
                            activity: acts[e.key],
                            color: colorOf(e.key),
                            value: e.value,
                            share: e.value.inSeconds / total.inSeconds,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Card(
                  title: 'Trend',
                  child: _Trend(period: period, now: total, prev: prev, prev2: prev2),
                ),
                const SizedBox(height: 12),
                const _Habits(),
                const SizedBox(height: 12),
                _FavoriteCats(from: from, to: to),
                const SizedBox(height: 12),
                const _AllTime(),
              ],
            );
          },
        );
      },
    );
  }

  List<DateTime> _buckets(Period p, DateTime from) {
    switch (p) {
      case Period.giorno:
        return [for (var h = 0; h <= 24; h++) DateTime(from.year, from.month, from.day, h)];
      case Period.settimana:
        return [for (var d = 0; d <= 7; d++) DateTime(from.year, from.month, from.day + d)];
      case Period.mese:
        final days = DateTime(from.year, from.month + 1, 0).day;
        return [for (var d = 0; d <= days; d++) DateTime(from.year, from.month, 1 + d)];
      case Period.anno:
        return [for (var m = 0; m <= 12; m++) DateTime(from.year, 1 + m)];
    }
  }
}

Duration overlap(Segment s, DateTime from, DateTime to) {
  final start = s.startedAt.isBefore(from) ? from : s.startedAt;
  final raw = s.endedAt ?? DateTime.now();
  final end = raw.isAfter(to) ? to : raw;
  return end.isAfter(start) ? end.difference(start) : Duration.zero;
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value, this.muted = false});
  final String label, value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: tc.muted, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium),
          child: Text(
            value,
            key: ValueKey(value),
            style: timerStyle(context, size: 34).copyWith(
              color: muted ? tc.pause : tc.text,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.color, required this.value, required this.share});
  final Activity? activity;
  final Color color;
  final Duration value;
  final double share;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Icon(iconFor(activity?.icon ?? 'circle'), size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(activity?.name ?? 'Attività', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('${(share * 100).round()}%', style: TextStyle(color: tc.muted)),
              const SizedBox(width: 10),
              Text(fmtHm(value), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: share),
              duration: Motion.of(context, Motion.slower),
              curve: Motion.curve,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 7,
                color: color,
                backgroundColor: tc.raised,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.period, required this.buckets, required this.perBucket, required this.colorOf});
  final Period period;
  final List<DateTime> buckets;
  final Map<int, List<Duration>> perBucket;
  final Color Function(int) colorOf;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final n = buckets.length - 1;
    double maxY = 0;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < n; i++) {
      var acc = 0.0;
      final stack = <BarChartRodStackItem>[];
      for (final e in perBucket.entries) {
        final h = e.value[i].inSeconds / 3600;
        if (h <= 0) continue;
        stack.add(BarChartRodStackItem(acc, acc + h, colorOf(e.key)));
        acc += h;
      }
      maxY = math.max(maxY, acc);
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: acc,
              rodStackItems: stack,
              width: n > 20 ? 6 : 14,
              borderRadius: BorderRadius.circular(6),
              color: tc.raised,
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
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: tc.outline, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, meta) => Text(
                v == 0 || v != v.roundToDouble() ? '' : '${v.round()}h',
                style: TextStyle(fontSize: 10, color: tc.muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= n) return const SizedBox.shrink();
                final d = buckets[i];
                final text = switch (period) {
                  Period.giorno => i % 6 == 0 ? '${d.hour}' : '',
                  Period.settimana => const ['L', 'M', 'M', 'G', 'V', 'S', 'D'][d.weekday - 1],
                  Period.mese => d.day % 5 == 1 ? '${d.day}' : '',
                  Period.anno => const ['G', 'F', 'M', 'A', 'M', 'G', 'L', 'A', 'S', 'O', 'N', 'D'][d.month - 1],
                };
                return Text(text, style: TextStyle(fontSize: 10, color: tc.muted));
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.period, required this.now, required this.prev, required this.prev2});
  final Period period;
  final Duration now, prev, prev2;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final names = switch (period) {
      Period.giorno => ('Oggi', 'Ieri', 'L\'altro ieri'),
      Period.settimana => ('Questa settimana', 'Settimana scorsa', 'Due settimane fa'),
      Period.mese => ('Questo mese', 'Mese scorso', 'Due mesi fa'),
      Period.anno => ('Quest\'anno', 'Anno scorso', 'Due anni fa'),
    };
    final maxV = [now, prev, prev2].map((d) => d.inSeconds).fold(1, math.max);
    final diff = now - prev;
    final up = diff >= Duration.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prev > Duration.zero || now > Duration.zero)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: up ? tc.accent : tc.pause),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${fmtHm(Duration(seconds: diff.inSeconds.abs()))} ${up ? 'in più' : 'in meno'} rispetto al periodo precedente',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        for (final (label, v) in [(names.$1, now), (names.$2, prev), (names.$3, prev2)])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: TextStyle(color: tc.muted, fontSize: 13))),
                    Text(fmtHm(v), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: v.inSeconds / maxV),
                    duration: Motion.of(context, Motion.slower),
                    curve: Motion.curve,
                    builder: (context, x, _) => LinearProgressIndicator(
                      value: x,
                      minHeight: 8,
                      color: label == names.$1 ? tc.accent : tc.accent.withValues(alpha: 0.45),
                      backgroundColor: tc.raised,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Best weekday and best time of day, over the last 12 weeks.
class _Habits extends StatelessWidget {
  const _Habits();

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day + 1);
    final from = DateTime(to.year, to.month, to.day - 84);
    return StreamBuilder<List<Segment>>(
      stream: db.watchSegmentsBetween(from, to),
      builder: (context, snap) {
        final segs = snap.data ?? const <Segment>[];
        final perDay = minutesPerDay(segs, from, to);
        final weekday = List<double>.filled(7, 0);
        perDay.forEach((d, m) => weekday[d.weekday - 1] += m / 12);
        final hours = List<double>.filled(24, 0);
        for (final s in segs) {
          if (s.isPause) continue;
          var a = s.startedAt.isBefore(from) ? from : s.startedAt;
          final end = s.endedAt ?? now;
          while (a.isBefore(end)) {
            final next = DateTime(a.year, a.month, a.day, a.hour + 1);
            final cut = end.isBefore(next) ? end : next;
            hours[a.hour] += cut.difference(a).inSeconds / 60;
            a = cut;
          }
        }
        if (weekday.every((v) => v == 0)) return const SizedBox.shrink();
        final bestDay = weekday.indexOf(weekday.reduce(math.max));
        var bestHour = 0;
        var bestWindow = 0.0;
        for (var h = 0; h < 24; h++) {
          final w = hours[h] + hours[(h + 1) % 24] + hours[(h + 2) % 24];
          if (w > bestWindow) {
            bestWindow = w;
            bestHour = h;
          }
        }
        const days = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];
        final maxW = weekday.reduce(math.max);
        final maxH = hours.reduce(math.max);
        return _Card(
          title: 'Le tue abitudini',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Ti concentri di più il '),
                    TextSpan(text: days[bestDay], style: TextStyle(color: tc.accent, fontWeight: FontWeight.w800)),
                    const TextSpan(text: ', soprattutto tra le '),
                    TextSpan(
                      text: '$bestHour e le ${(bestHour + 3) % 24}',
                      style: TextStyle(color: tc.accent, fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 70,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: Motion.of(context, Motion.slow),
                              height: 6 + 44 * (maxW == 0 ? 0 : weekday[i] / maxW),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: i == bestDay ? tc.accent : tc.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(days[i][0].toUpperCase(), style: TextStyle(fontSize: 11, color: tc.muted)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var h = 0; h < 24; h++)
                      Expanded(
                        child: Container(
                          height: 4 + 36 * (maxH == 0 ? 0 : hours[h] / maxH),
                          margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          decoration: BoxDecoration(
                            color: (h - bestHour) % 24 < 3 ? tc.accent : tc.accentSoft,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final t in const ['0', '6', '12', '18', '24'])
                    Text(t, style: TextStyle(fontSize: 10, color: tc.muted)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FavoriteCats extends StatelessWidget {
  const _FavoriteCats({required this.from, required this.to});
  final DateTime from, to;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return StreamBuilder<List<SessionWork>>(
      stream: db.watchSessionWork(from, to),
      builder: (context, snap) {
        final count = <String, int>{};
        for (final s in snap.data ?? const <SessionWork>[]) {
          final id = s.session.skinId ?? kSkins.first.id;
          count[id] = (count[id] ?? 0) + 1;
        }
        if (count.isEmpty) return const SizedBox.shrink();
        final top = count.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return _Card(
          title: 'Gattini preferiti',
          child: Row(
            children: [
              for (final e in top.take(3))
                Expanded(
                  child: Column(
                    children: [
                      KittenView(skin: skinById(e.key), size: 76, animate: false),
                      Text(skinById(e.key).name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('${e.value} ${e.value == 1 ? 'sessione' : 'sessioni'}',
                          style: TextStyle(color: tc.muted, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AllTime extends StatelessWidget {
  const _AllTime();

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return StreamBuilder<List<Activity>>(
      stream: db.watchActivities(includeArchived: true),
      builder: (context, aSnap) {
        final acts = {for (final a in aSnap.data ?? <Activity>[]) a.id: a};
        return StreamBuilder<List<({Segment segment, int activityId})>>(
          stream: db.watchRange(DateTime(2000), DateTime(2200)),
          builder: (context, snap) {
            final totals = <int, Duration>{};
            for (final r in snap.data ?? const []) {
              if (r.segment.isPause) continue;
              totals[r.activityId] = (totals[r.activityId] ?? Duration.zero) +
                  (r.segment.endedAt ?? DateTime.now()).difference(r.segment.startedAt);
            }
            if (totals.isEmpty) return const SizedBox.shrink();
            final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            return _Card(
              title: 'Totale di sempre',
              child: Column(
                children: [
                  for (final e in sorted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(iconFor(acts[e.key]?.icon ?? 'circle'),
                              size: 18, color: activityColor(acts[e.key]?.color ?? 0xFF93C4A0, dark: tc.dark)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(acts[e.key]?.name ?? 'Attività')),
                          Text(fmtHm(e.value), style: const TextStyle(fontWeight: FontWeight.w800)),
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

// --- Calendar ---------------------------------------------------------------------

/// A light month view: a soft dot per day, bigger when you worked more.
Future<void> showCalendarSheet(BuildContext context) {
  return showSoftSheet<void>(context, builder: (_) => const _CalendarSheet());
}

class _CalendarSheet extends StatefulWidget {
  const _CalendarSheet();

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  static const _base = 600; // page index of the current month
  final _pages = PageController(initialPage: _base);
  int _page = _base;

  DateTime _monthOf(int page) {
    final now = DateTime.now();
    return DateTime(now.year, now.month + (page - _base));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _monthOf(_page);
    final title = DateFormat('MMMM y', 'it').format(m);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _pages.previousPage(duration: Motion.medium, curve: Motion.curve),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${title[0].toUpperCase()}${title.substring(1)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => _pages.nextPage(duration: Motion.medium, curve: Motion.curve),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 330,
              child: PageView.builder(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, p) => _Month(month: _monthOf(p)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Month extends StatelessWidget {
  const _Month({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final to = DateTime(month.year, month.month + 1);
    return StreamBuilder<Map<String, String>>(
      stream: db.watchPrefs(),
      builder: (context, pSnap) {
        final weekStart = Settings(pSnap.data ?? const {}).weekStart;
        return StreamBuilder<List<Segment>>(
          stream: db.watchSegmentsBetween(month, to),
          builder: (context, snap) {
            final perDay = minutesPerDay(snap.data ?? const [], month, to);
            final maxV = perDay.values.fold(0.0, math.max);
            final lead = (month.weekday - weekStart + 7) % 7;
            final days = DateTime(month.year, month.month + 1, 0).day;
            final names = weekStart == 1
                ? const ['L', 'M', 'M', 'G', 'V', 'S', 'D']
                : const ['D', 'L', 'M', 'M', 'G', 'V', 'S'];
            final today = DateTime.now();
            return Column(
              children: [
                Row(
                  children: [
                    for (final n in names)
                      Expanded(
                        child: Center(
                          child: Text(n, style: TextStyle(color: tc.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                    itemCount: lead + days,
                    itemBuilder: (context, i) {
                      if (i < lead) return const SizedBox.shrink();
                      final d = DateTime(month.year, month.month, i - lead + 1);
                      final v = perDay[d] ?? 0;
                      final k = maxV == 0 ? 0.0 : math.sqrt(v / maxV);
                      final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                      return GestureDetector(
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.pop();
                          nav.push(MaterialPageRoute(builder: (_) => DayPage(day: d)));
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (v > 0)
                              AnimatedContainer(
                                duration: Motion.of(context, Motion.slow),
                                width: 14 + 24 * k,
                                height: 14 + 24 * k,
                                decoration: BoxDecoration(
                                  color: Color.lerp(tc.accentSoft, tc.accent, 0.2 + 0.6 * k),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                                color: v > 0 && k > 0.5 ? tc.onAccent : (isToday ? tc.accent : tc.text),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
