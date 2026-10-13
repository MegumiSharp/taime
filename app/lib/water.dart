import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taime_native/taime_native.dart';

import 'app.dart';
import 'db.dart';
import 'kitten/art.dart';
import 'pages/water_page.dart';
import 'settings.dart';
import 'theme.dart';
import 'ui/motion.dart';
import 'ui/widgets.dart';

/// "Bevi acqua": glasses counted per day (prefs `water.YYYY-MM-DD`) and
/// reminders that never touch the timer. The plan is computed here and walked
/// by a native alarm, so it works with the app closed.
const kWaterBlue = Color(0xFF5B9BD5);

/// When to remind, from [now] on: within the hours and days, or every
/// [Settings.waterEvery] minutes of the session started at [focusStart]. A
/// glass drunk restarts the count. A week ahead at most; the native side asks
/// for more when it runs low.
List<DateTime> waterPlan(Settings s, DateTime now, {DateTime? focusStart}) {
  if (!s.waterOn || s.waterEvery <= 0) return const [];
  final every = Duration(minutes: s.waterEvery);
  final last = s.waterLast;
  final out = <DateTime>[];
  if (s.waterMode == 'focus') {
    if (focusStart == null) return const [];
    var t = last != null && last.isAfter(focusStart) ? last : focusStart;
    final end = now.add(const Duration(hours: 16));
    while (true) {
      t = t.add(every);
      if (t.isAfter(end)) break;
      if (t.isAfter(now)) out.add(t);
    }
    return out;
  }
  // From yesterday: a window past midnight may have started then.
  for (var d = -1; d <= 7; d++) {
    final start = DateTime(now.year, now.month, now.day + d, 0, s.waterFrom);
    if (!s.waterDays.contains(start.weekday)) continue;
    final to = s.waterTo > s.waterFrom ? s.waterTo : s.waterTo + 24 * 60;
    final end = DateTime(now.year, now.month, now.day + d, 0, to);
    var t = last != null && !last.isBefore(start) && last.isBefore(end) ? last.add(every) : start;
    for (; !t.isAfter(end); t = t.add(every)) {
      if (t.isAfter(now)) out.add(t);
    }
  }
  return out..sort();
}

/// "3 di 8 bicchieri · 0,75 L"
String waterSummary(int count, Settings s) {
  final ml = count * s.waterGlass;
  final l = ml % 1000 == 0
      ? '${ml ~/ 1000}'
      : (ml / 1000).toStringAsFixed(ml % 100 == 0 ? 1 : 2).replaceFirst('.', ',');
  return '$count di ${s.waterGoal} ${s.waterGoal == 1 ? 'bicchiere' : 'bicchieri'} · $l L';
}

/// Sends the plan and today's count to the native alarm. [answered]: a glass
/// was counted in the app, so a reminder on screen is no longer needed.
/// [database]: the tracker's, when called from it.
Future<void> pushWater({bool answered = false, Db? database}) async {
  try {
    final d = database ?? db;
    final s = Settings(await d.allPrefs());
    final now = DateTime.now();
    final session = await d.openSession();
    await TaimeSystem.waterUpdate(
      plan: [for (final t in waterPlan(s, now, focusStart: session?.startedAt)) t.millisecondsSinceEpoch],
      count: s.waterCount(now),
      day: waterKey(now).substring(6),
      goal: s.waterGoal,
      glass: s.waterGlass,
      snooze: s.waterSnooze,
      text: s.waterText,
      sound: s.waterSound,
      art: await kittenArtPath(s.activeSkin, 4),
      drank: answered,
    );
  } catch (_) {}
}

/// One more glass (or one less, to fix a slip). [fromNotification]: "Ho
/// bevuto" on the reminder, which already says "Fatto!".
Future<void> addWater(int delta, {bool fromNotification = false}) async {
  final s = Settings(await db.allPrefs());
  final now = DateTime.now();
  await db.setPref(waterKey(now), '${(s.waterCount(now) + delta).clamp(0, 99)}');
  if (delta > 0) await db.setPref('waterLast', now.toIso8601String());
  await pushWater(answered: delta > 0 && !fromNotification);
}

/// Today's glasses, at the top of Focus.
class WaterChip extends StatelessWidget {
  const WaterChip({super.key, required this.settings, required this.now});
  final Settings settings;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final n = settings.waterCount(now);
    final done = n >= settings.waterGoal;
    return Semantics(
      label: 'Acqua: ${waterSummary(n, settings)}',
      child: TapScale(
        onTap: () => showWaterSheet(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
          decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(done ? Icons.check_circle_rounded : Icons.water_drop_rounded, size: 20, color: kWaterBlue),
              const SizedBox(width: 4),
              AnimatedCount(
                n,
                format: (v) => '$v/${settings.waterGoal}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showWaterSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (_) => StreamBuilder<Map<String, String>>(
    stream: db.watchPrefs(),
    builder: (context, snap) => _WaterSheet(settings: Settings(snap.data ?? const {})),
  ),
);

class _WaterSheet extends StatelessWidget {
  const _WaterSheet({required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final s = settings;
    final now = DateTime.now();
    final n = s.waterCount(now);
    final next = waterPlan(s, now, focusStart: null).firstOrNull;
    final String hint;
    if (!s.waterOn) {
      hint = 'Promemoria spenti';
    } else if (s.waterMode == 'focus') {
      hint = 'Ogni ${fmtHm(Duration(minutes: s.waterEvery))} durante il focus';
    } else if (n >= s.waterGoal) {
      hint = 'Obiettivo raggiunto: niente più promemoria oggi';
    } else if (next == null) {
      hint = 'Nessun promemoria nei prossimi giorni';
    } else {
      final days = DateUtils.dateOnly(next).difference(DateUtils.dateOnly(now)).inDays;
      final day = switch (days) { 0 => '', 1 => 'domani ', _ => '${DateFormat.EEEE('it').format(next)} ' };
      hint = 'Prossimo promemoria ${day}alle ${DateFormat.Hm().format(next)}';
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Acqua di oggi', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            WaterGlasses(count: n, goal: s.waterGoal),
            const SizedBox(height: 10),
            Text(
              waterSummary(n, s),
              textAlign: TextAlign.center,
              style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Togli un bicchiere',
                  onPressed: n > 0 ? () => addWater(-1) : null,
                  icon: const Icon(Icons.remove_rounded),
                  style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  backgroundColor: kWaterBlue.withValues(alpha: 0.16),
                  foregroundColor: kWaterBlue,
                ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PillButton(
                    label: 'Ho bevuto',
                    icon: Icons.water_drop_rounded,
                    expand: true,
                    color: kWaterBlue,
                    onTap: () {
                      Haptic.light();
                      addWater(1);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(hint),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WaterPage())),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of glasses, filled up to [count].
class WaterGlasses extends StatelessWidget {
  const WaterGlasses({super.key, required this.count, required this.goal});
  final int count, goal;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < goal.clamp(1, 20); i++)
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.medium),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Icon(
              i < count ? Icons.local_drink_rounded : Icons.local_drink_outlined,
              key: ValueKey(i < count),
              size: 30,
              color: i < count ? kWaterBlue : tc.muted.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }
}
