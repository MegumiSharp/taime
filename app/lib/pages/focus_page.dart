import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../db.dart';
import '../icons.dart';
import '../kitten/art.dart';
import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../main.dart' show shellTab;
import '../settings.dart';
import '../theme.dart';
import '../tracker.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';
import 'activity_picker.dart';
import 'heatmap.dart';
import 'overview_page.dart' show overviewRequest;
import 'settings_page.dart';
import 'shop_page.dart' show BalanceChip, ownedSkinIds;

/// "Su cosa ti concentri?" lives for the whole app, so switching tab before
/// pressing Inizia does not lose what you typed.
final focusNote = TextEditingController();

class FocusPage extends StatefulWidget {
  const FocusPage({super.key, required this.settings});
  final Settings settings;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  late final Timer _ticker;
  DateTime _now = DateTime.now();
  int? _pendingActivityId;
  int _lastAdults = -1;
  int _lastStage = -1;
  int _celebrate = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
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
      builder: (context, sSnap) {
        final session = sSnap.data;
        return StreamBuilder<List<Segment>>(
          stream: session == null
              ? Stream.value(const <Segment>[])
              : db.watchSegmentsOf(session.id),
          builder: (context, segSnap) => StreamBuilder<List<Activity>>(
            stream: db.watchActivities(),
            builder: (context, aSnap) => _body(
              context,
              session,
              segSnap.data ?? const [],
              aSnap.data ?? const [],
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    Session? session,
    List<Segment> segs,
    List<Activity> acts,
  ) {
    final tc = context.tc;
    final s = widget.settings;
    final open = segs.where((x) => x.endedAt == null).firstOrNull;
    final running = session != null && open != null;
    final paused = open?.isPause ?? false;
    final work = Tracker.worked(segs, now: _now);
    final workMin = work.inSeconds / 60;
    final inHour = workMin % 60;
    final adults = workMin ~/ 60;
    final stage = stageOf(inHour);
    final growth = running ? growthOf(inHour) : 1.0;

    // Little moments: a stage pop and a full hour celebration.
    if (running) {
      if (_lastStage != -1 && stage != _lastStage && !paused) Haptic.light();
      if (_lastAdults != -1 && adults > _lastAdults) {
        _celebrate++;
        Haptic.medium();
      }
      _lastStage = stage;
      _lastAdults = adults;
    } else {
      _lastStage = -1;
      _lastAdults = -1;
    }

    final activity = _currentActivity(session, acts);
    final skin = skinById(session?.skinId ?? s.activeSkin);
    final sinceStart = session == null ? Duration.zero : _now.difference(session.startedAt);
    final canCancel = running && !paused && segs.length == 1 && sinceStart.inSeconds < 10;

    Duration shown;
    String caption;
    if (!running) {
      shown = Duration.zero;
      caption = s.pomodoro
          ? 'Pomodoro da ${s.pomoWorkMin} minuti'
          : 'Il gattino cresce mentre ti concentri';
    } else if (s.pomodoro) {
      final mins = paused ? Tracker.pomoBreakMinutes(s, segs) : s.pomoWorkMin;
      final left = open.startedAt.add(Duration(minutes: mins)).difference(_now);
      shown = left.isNegative ? Duration.zero : left;
      caption = paused ? 'Pausa · lavoro ${fmtHm(work)}' : kStageNames[stage];
    } else if (paused) {
      shown = _now.difference(open.startedAt);
      caption = 'In pausa · lavoro ${fmtHm(work)}';
    } else {
      shown = work;
      caption = kStageNames[stage];
    }

    final progress = !running
        ? 0.0
        : s.pomodoro
        ? (_now.difference(open.startedAt).inSeconds /
                  ((paused ? Tracker.pomoBreakMinutes(s, segs) : s.pomoWorkMin) * 60))
              .clamp(0.0, 1.0)
        : inHour / 60;

    return PastelBackground(
      paused: paused,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
          children: [
            _TopBar(
              extraSeconds: running && !paused ? _now.difference(open.startedAt).inSeconds : 0,
              onSettings: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
            const SizedBox(height: 6),
            _ActivityHeader(
              activity: activity,
              session: session,
              note: focusNote,
              onTap: () => _pickActivity(context, session, acts),
            ),
            const SizedBox(height: 14),
            _Scene(
              skin: skin,
              running: running,
              paused: paused,
              growth: growth,
              progress: progress,
              adults: running ? adults : 0,
              celebrate: _celebrate,
              onTapKitten: running ? null : () => _pickSkin(context),
            ),
            const SizedBox(height: 10),
            Center(
              child: AnimatedDefaultTextStyle(
                duration: Motion.of(context, Motion.slow),
                style: timerStyle(context).copyWith(
                  color: paused ? Color.lerp(tc.pause, tc.text, 0.25) : tc.text,
                ),
                child: Text(running ? fmtClock(shown) : (s.pomodoro ? fmtClock(Duration(minutes: s.pomoWorkMin)) : '00:00')),
              ),
            ),
            Center(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.medium),
                child: Text(
                  caption,
                  key: ValueKey(caption),
                  style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            AnimatedSize(
              duration: Motion.of(context, Motion.slow),
              curve: Motion.curve,
              child: paused
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Center(child: CoffeeCup(color: tc.pause)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 18),
            _Buttons(
              running: running,
              paused: paused,
              canCancel: canCancel,
              cancelLeft: 10 - sinceStart.inSeconds,
              onStart: () => _start(acts),
              onCancel: () {
                Haptic.medium();
                tracker.cancel();
              },
              onPause: () => tracker.pause(),
              onResume: () => tracker.resume(),
              onStop: () => _stop(context, session!, segs),
            ),
            const SizedBox(height: 24),
            TodayCard(goalMinutes: s.dailyGoalMin, now: _now),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.slow),
              child: running
                  ? const SizedBox(height: 12)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              overviewRequest.value = 'anno';
                              shellTab.value = 2;
                            },
                            child: const ActivityHeatmap(weeks: 20),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Activity? _currentActivity(Session? session, List<Activity> acts) {
    if (acts.isEmpty) return null;
    final id = session?.activityId ?? _pendingActivityId ?? widget.settings.lastActivityId;
    return acts.where((a) => a.id == id).firstOrNull ?? acts.first;
  }

  Future<void> _start(List<Activity> acts) async {
    if (acts.isEmpty) return;
    Haptic.medium();
    final activity = _currentActivity(null, acts)!;
    await ensureKittenArt(widget.settings.activeSkin);
    await tracker.start(activity.id, note: focusNote.text.trim());
  }

  Future<void> _stop(BuildContext context, Session session, List<Segment> segs) async {
    Haptic.medium();
    final work = Tracker.worked(segs);
    final skinId = session.skinId ?? widget.settings.activeSkin;
    await tracker.stop();
    focusNote.clear();
    if (!context.mounted) return;
    await showSoftSheet<void>(
      context,
      builder: (_) => SessionSummary(
        work: work,
        cats: catsForSession(work.inMinutes, skinId, session.id),
      ),
    );
  }

  Future<void> _pickActivity(BuildContext context, Session? session, List<Activity> acts) async {
    final picked = await showActivityPicker(
      context,
      currentId: _currentActivity(session, acts)?.id,
    );
    if (picked == null || !context.mounted) return;
    if (session == null) {
      setState(() => _pendingActivityId = picked.id);
      await db.setPref('lastActivityId', '${picked.id}');
      return;
    }
    if (picked.id == session.activityId) return;
    final choice = await showSoftSheet<String>(
      context,
      scrollControlled: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text('Passa a ${picked.name}'),
                subtitle: const Text('Chiude questa sessione e ne apre una nuova'),
                onTap: () => Navigator.pop(context, 'switch'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text('Correggi in ${picked.name}'),
                subtitle: const Text('Avevo avviato l\'attività sbagliata'),
                onTap: () => Navigator.pop(context, 'fix'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == 'switch') await tracker.start(picked.id);
    if (choice == 'fix') await tracker.reassign(picked.id);
  }

  Future<void> _pickSkin(BuildContext context) async {
    final owned = await ownedSkinIds();
    if (!context.mounted) return;
    final picked = await showSoftSheet<String>(
      context,
      builder: (context) => _SkinPicker(
        owned: owned,
        active: widget.settings.activeSkin,
      ),
    );
    if (picked == null) return;
    await db.setPref('activeSkin', picked);
    await ensureKittenArt(picked);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings, required this.extraSeconds});
  final VoidCallback onSettings;
  final int extraSeconds;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Row(
      children: [
        IconButton(
          onPressed: onSettings,
          tooltip: 'Impostazioni',
          icon: Icon(Icons.tune_rounded, color: tc.text),
          style: IconButton.styleFrom(
            backgroundColor: tc.surface.withValues(alpha: 0.7),
            minimumSize: const Size(46, 46),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => shellTab.value = 3,
          child: BalanceChip(extraSeconds: extraSeconds),
        ),
      ],
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({
    required this.activity,
    required this.session,
    required this.note,
    required this.onTap,
  });

  final Activity? activity;
  final Session? session;
  final TextEditingController note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final color = activity == null
        ? tc.accent
        : activityColor(activity!.color, dark: tc.dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TapScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, Motion.medium),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: activitySoft(activity?.color ?? 0xFF93C4A0, dark: tc.dark),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconFor(activity?.icon ?? 'circle'), size: 17, color: color),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.medium),
                    child: Text(
                      activity?.name ?? 'Scegli un\'attività',
                      key: ValueKey(activity?.id),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: tc.muted),
              ],
            ),
          ),
        ),
        _NoteField(session: session, controller: note),
      ],
    );
  }
}

/// "Su cosa ti concentri?": kept locally before start, on the session after.
class _NoteField extends StatefulWidget {
  const _NoteField({required this.session, required this.controller});
  final Session? session;
  final TextEditingController controller;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  int? _boundTo;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final s = widget.session;
    if (s != null && _boundTo != s.id) {
      _boundTo = s.id;
      widget.controller.text = s.note;
    } else if (s == null && _boundTo != null) {
      _boundTo = null;
    }
    return TextField(
      controller: widget.controller,
      style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Su cosa ti concentri?',
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        border: UnderlineInputBorder(borderSide: BorderSide(color: tc.outline)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tc.outline)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tc.accent, width: 1.5)),
      ),
      onChanged: (v) {
        if (s != null) db.updateSessionNote(s.id, v);
      },
    );
  }
}

/// Bubble, cushion, progress ring and the kitten.
class _Scene extends StatelessWidget {
  const _Scene({
    required this.skin,
    required this.running,
    required this.paused,
    required this.growth,
    required this.progress,
    required this.adults,
    required this.celebrate,
    required this.onTapKitten,
  });

  final Skin skin;
  final bool running, paused;
  final double growth, progress;
  final int adults;
  final int celebrate;
  final VoidCallback? onTapKitten;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final size = math.min(MediaQuery.sizeOf(context).width - 40, 330.0);
    final ringColor = paused ? tc.pause : tc.accent;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: running ? 1 : 0),
          duration: Motion.of(context, Motion.slower),
          curve: Motion.emphasized,
          builder: (context, t, _) => Stack(
            alignment: Alignment.center,
            children: [
              // Soft light behind everything.
              Container(
                width: size * 0.95,
                height: size * 0.95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: tc.dark ? 0.06 : 0.55),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              // Progress ring appears as the focus starts.
              Opacity(
                opacity: t,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: ringColor),
                  duration: Motion.of(context, Motion.slow),
                  builder: (context, c, _) => TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: Motion.of(context, Motion.slow),
                    builder: (context, p, _) => CustomPaint(
                      size: Size.square(size),
                      painter: _RingPainter(
                        progress: p,
                        color: c ?? ringColor,
                        track: tc.outline.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
              // Cushion.
              Positioned(
                bottom: size * 0.17,
                child: Container(
                  width: size * 0.56,
                  height: size * 0.12,
                  decoration: BoxDecoration(
                    color: Color.lerp(tc.accentSoft, paused ? tc.pauseSoft : tc.accentSoft, 1),
                    borderRadius: BorderRadius.all(Radius.elliptical(size * 0.28, size * 0.06)),
                  ),
                ),
              ),
              // Glass bubble: sits around the kitten at rest, blows away on start.
              IgnorePointer(
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 + t * 1.2,
                    child: Container(
                      width: size * 0.76,
                      height: size * 0.76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.35, -0.4),
                          colors: [
                            Colors.white.withValues(alpha: tc.dark ? 0.12 : 0.55),
                            Colors.white.withValues(alpha: tc.dark ? 0.04 : 0.14),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: tc.dark ? 0.18 : 0.8),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Kitten.
              Positioned(
                bottom: size * 0.19,
                child: GestureDetector(
                  onTap: onTapKitten,
                  child: _Hop(
                    trigger: celebrate,
                    child: AnimatedSwitcher(
                      duration: Motion.of(context, Motion.slow),
                      child: KittenView(
                        key: ValueKey('${skin.id}-$paused'),
                        skin: skin,
                        pose: paused ? Pose.dorme : skin.pose,
                        growth: growth,
                        size: size * 0.58,
                      ),
                    ),
                  ),
                ),
              ),
              if (onTapKitten != null)
                Positioned(
                  bottom: 0,
                  child: Opacity(
                    opacity: 1 - t,
                    child: Text(
                      'Tocca per cambiare gattino',
                      style: TextStyle(color: tc.muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (adults > 0)
                Positioned(
                  top: size * 0.08,
                  right: size * 0.06,
                  child: _CatsChip(count: adults, skin: skin),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track});
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, base);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// A little hop and a floating heart each time [trigger] changes.
class _Hop extends StatelessWidget {
  const _Hop({required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: trigger == 0 ? 1 : 0, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 1200)),
      builder: (context, t, child) {
        final hop = math.sin(math.min(t * 2, 1) * math.pi) * 22;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.translate(offset: Offset(0, -hop), child: child),
            if (t < 1)
              Positioned(
                top: -10 - t * 50,
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Icon(Icons.favorite_rounded, color: tc.pause, size: 26 + t * 8),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }
}

class _CatsChip extends StatelessWidget {
  const _CatsChip({required this.count, required this.skin});
  final int count;
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KittenView(skin: skin, size: 30, animate: false),
          AnimatedCount(
            count,
            format: (n) => '×$n',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.running,
    required this.paused,
    required this.canCancel,
    required this.cancelLeft,
    required this.onStart,
    required this.onCancel,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final bool running, paused, canCancel;
  final int cancelLeft;
  final VoidCallback onStart, onCancel, onPause, onResume, onStop;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final Widget child;
    if (!running) {
      child = Center(
        key: const ValueKey('start'),
        child: PillButton(
          label: 'Inizia',
          icon: Icons.play_arrow_rounded,
          kind: PillKind.surface,
          big: true,
          onTap: onStart,
        ),
      );
    } else if (canCancel) {
      child = Center(
        key: const ValueKey('cancel'),
        child: PillButton(
          label: 'Annulla ($cancelLeft)',
          kind: PillKind.ghost,
          onTap: onCancel,
        ),
      );
    } else {
      child = Row(
        key: ValueKey('run-$paused'),
        children: [
          Expanded(
            child: paused
                ? PillButton(
                    label: 'Riprendi',
                    icon: Icons.play_arrow_rounded,
                    kind: PillKind.primary,
                    color: tc.pause,
                    expand: true,
                    onTap: onResume,
                  )
                : PillButton(
                    label: 'Pausa',
                    icon: Icons.local_cafe_rounded,
                    kind: PillKind.soft,
                    color: tc.pause,
                    expand: true,
                    onTap: onPause,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PillButton(
              label: 'Termina',
              icon: Icons.stop_rounded,
              kind: PillKind.surface,
              expand: true,
              onTap: onStop,
            ),
          ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.medium),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: c),
      ),
      child: child,
    );
  }
}

/// A cup of coffee with steam curling up: the pause.
class CoffeeCup extends StatefulWidget {
  const CoffeeCup({super.key, required this.color, this.size = 64});
  final Color color;
  final double size;

  @override
  State<CoffeeCup> createState() => _CoffeeCupState();
}

class _CoffeeCupState extends State<CoffeeCup> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _CupPainter(
          anim: context.reduceMotion ? const AlwaysStoppedAnimation(0.3) : _c,
          cup: widget.color,
          line: tc.dark ? tc.text.withValues(alpha: 0.8) : const Color(0xFF6B4A3E),
          steam: tc.muted,
        ),
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter({required this.anim, required this.cup, required this.line, required this.steam})
    : super(repaint: anim);
  final Animation<double> anim;
  final Color cup, line, steam;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    canvas.scale(s);
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Steam: two wisps rising and fading, offset in phase.
    for (var i = 0; i < 2; i++) {
      final p = (anim.value + i * 0.5) % 1.0;
      final x = 26.0 + i * 12;
      final y = 26 - p * 12;
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x - 4, y - 5, x, y - 10)
        ..quadraticBezierTo(x + 4, y - 15, x, y - 20);
      canvas.drawPath(
        path,
        Paint()
          ..color = steam.withValues(alpha: math.sin(p * math.pi) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
    final body = Path()
      ..moveTo(14, 30)
      ..lineTo(46, 30)
      ..lineTo(43, 52)
      ..quadraticBezierTo(42, 58, 36, 58)
      ..lineTo(24, 58)
      ..quadraticBezierTo(18, 58, 17, 52)
      ..close();
    canvas.drawPath(body, Paint()..color = cup);
    canvas.drawPath(body, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(45, 35)
        ..quadraticBezierTo(55, 35, 53, 43)
        ..quadraticBezierTo(51, 49, 43, 48),
      stroke,
    );
    canvas.drawOval(Rect.fromLTRB(15, 27, 45, 33), Paint()..color = const Color(0xFF8A5A40));
    canvas.drawOval(Rect.fromLTRB(15, 27, 45, 33), stroke..strokeWidth = 2);
    canvas.drawLine(const Offset(10, 60), const Offset(50, 60), stroke..strokeWidth = 2.6);
  }

  @override
  bool shouldRepaint(_CupPainter old) => old.cup != cup || old.line != line;
}

/// Shown after "Termina": what the session earned.
class SessionSummary extends StatelessWidget {
  const SessionSummary({super.key, required this.work, required this.cats});
  final Duration work;
  final List<PenCat> cats;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final shownCats = cats.take(6).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sessione completata', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(fmtHm(work), style: timerStyle(context, size: 44)),
            const SizedBox(height: 14),
            if (shownCats.isEmpty)
              Text(
                'Sotto i $kMinKittenMinutes minuti non nasce nessun gattino.',
                textAlign: TextAlign.center,
                style: TextStyle(color: tc.muted),
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  for (var i = 0; i < shownCats.length; i++)
                    StaggeredIn(
                      index: i,
                      child: KittenView(
                        skin: skinById(shownCats[i].skinId),
                        growth: shownCats[i].growth,
                        size: 78,
                      ),
                    ),
                  if (cats.length > shownCats.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Text('+${cats.length - shownCats.length}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Earned(
                  icon: Icons.pets_rounded,
                  value: '${cats.length}',
                  label: cats.length == 1 ? 'gattino nel recinto' : 'gattini nel recinto',
                ),
                const SizedBox(width: 24),
                _Earned(
                  icon: Icons.cookie_rounded,
                  value: '+${work.inMinutes}',
                  label: 'crocchette',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Chiudi',
                    kind: PillKind.soft,
                    expand: true,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PillButton(
                    label: 'Vedi nel recinto',
                    expand: true,
                    onTap: () {
                      Navigator.pop(context);
                      overviewRequest.value = 'giorno';
                      shellTab.value = 2;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Earned extends StatelessWidget {
  const _Earned({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: tc.accent),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        Text(label, style: TextStyle(color: tc.muted, fontSize: 12.5)),
      ],
    );
  }
}

class _SkinPicker extends StatelessWidget {
  const _SkinPicker({required this.owned, required this.active});
  final Set<String> owned;
  final String active;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final skins = [...kSkins.where((s) => owned.contains(s.id)), ...myCustomSkins];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('I tuoi gattini', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Scegli chi ti fa compagnia. Altri nel Negozio.',
              style: TextStyle(color: tc.muted),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
                children: [
                  for (final s in skins)
                    SoftCard(
                      padding: const EdgeInsets.all(6),
                      color: s.id == active ? tc.accentSoft : tc.raised,
                      onTap: () => Navigator.pop(context, s.id),
                      child: Column(
                        children: [
                          Expanded(child: KittenView(skin: s, size: 100, animate: s.id == active)),
                          Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
