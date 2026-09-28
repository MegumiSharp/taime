import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'painter.dart';
import 'skins.dart';

/// A kitten on screen: blinks at random, breathes, sways its tail, twitches
/// an ear now and then, glances around, and "pops" when it grows a stage.
class KittenView extends StatefulWidget {
  const KittenView({
    super.key,
    required this.skin,
    this.pose,
    this.growth = 1,
    this.size = 160,
    this.animate = true,
    this.actions = true,
    this.showcase = false,
  });

  final Skin skin;

  /// Defaults to the skin's own pose.
  final Pose? pose;
  final double growth;
  final double size;
  final bool animate;

  /// Random little scenes (fly, bottle, yawn...) now and then.
  final bool actions;

  /// Shop windows: the scenes start soon and come more often, so you see them.
  final bool showcase;

  @override
  State<KittenView> createState() => _KittenViewState();
}

class _KittenViewState extends State<KittenView>
    with SingleTickerProviderStateMixin {
  final _anim = KittenAnim();
  final _rnd = math.Random();
  Ticker? _ticker;

  double _nextBlink = 1.5, _blinkAt = -10;
  double _nextEar = 4, _earAt = -10;
  double _nextLook = 3, _lookTarget = 0;
  double _bumpAt = -10;
  double _nextAction = 12, _actionAt = -100;
  KittenAction _action = KittenAction.none;
  KittenAction _last = KittenAction.none;
  double _now = 0;

  @override
  void initState() {
    super.initState();
    _nextAction = widget.showcase ? 1.5 + _rnd.nextDouble() * 3 : 8 + _rnd.nextDouble() * 14;
    _anim.t = _rnd.nextDouble() * 10; // desync kittens shown together
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(KittenView old) {
    super.didUpdateWidget(old);
    _syncTicker();
    final before = stageOf(old.growth * 60);
    final after = stageOf(widget.growth * 60);
    if (after != before) _bumpAt = _now;
  }

  bool get _shouldAnimate =>
      widget.animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _syncTicker() {
    if (_shouldAnimate) {
      _ticker ??= createTicker(_onTick)..start();
    } else {
      _ticker?.dispose();
      _ticker = null;
    }
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    _now = t;
    final sleeping = (widget.pose ?? widget.skin.pose) == Pose.dorme;
    _anim.t = t;
    _anim.breath = math.sin(2 * math.pi * t / (sleeping ? 5.2 : 3.4));
    _anim.tail = math.sin(2 * math.pi * t / 2.8);

    if (t >= _nextBlink) {
      _blinkAt = t;
      // Now and then a double blink.
      _nextBlink = t + (_rnd.nextDouble() < 0.18 ? 0.32 : 2 + _rnd.nextDouble() * 4);
    }
    final bp = (t - _blinkAt) / 0.2;
    _anim.blink = bp >= 0 && bp < 1 ? math.sin(math.pi * bp) : 0;

    if (t >= _nextEar) {
      _earAt = t;
      _nextEar = t + 5 + _rnd.nextDouble() * 6;
    }
    final ep = (t - _earAt) / 0.5;
    _anim.ear = ep >= 0 && ep < 1 ? math.sin(math.pi * ep) : 0;

    if (t >= _nextLook) {
      _lookTarget = _rnd.nextDouble() < 0.4 ? 0 : _rnd.nextDouble() * 2 - 1;
      _nextLook = t + 3 + _rnd.nextDouble() * 4;
    }
    _anim.look += (_lookTarget - _anim.look) * 0.06;

    // Every 25-70 s (5-11 s in a shop window) a little scene; never asleep.
    if (widget.actions && !sleeping && _action == KittenAction.none && t >= _nextAction) {
      final options = actionsFor(widget.skin);
      // Never the same scene twice in a row.
      final pick = options.where((a) => a != _last).toList();
      _action = pick[_rnd.nextInt(pick.length)];
      _last = _action;
      _actionAt = t;
    }
    if (_action != KittenAction.none) {
      final p = (t - _actionAt) / kActionSeconds[_action]!;
      if (p >= 1) {
        _action = KittenAction.none;
        _nextAction = t + (widget.showcase ? 5 + _rnd.nextDouble() * 6 : 25 + _rnd.nextDouble() * 45);
      }
      _anim.action = _action;
      _anim.actionT = p.clamp(0.0, 1.0);
    } else {
      _anim.action = KittenAction.none;
    }

    final up = (t - _bumpAt) / 0.5;
    _anim.bump = up >= 0 && up < 1 ? up : 0;
    _anim.tick();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: KittenPainter(
          skin: widget.skin,
          pose: widget.pose ?? widget.skin.pose,
          growth: widget.growth,
          anim: _ticker == null ? null : _anim,
        ),
      ),
    );
  }
}
