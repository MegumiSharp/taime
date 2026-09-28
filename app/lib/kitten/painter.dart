import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import 'skins.dart';

/// Sporadic little scenes a kitten plays out on its own.
enum KittenAction { none, mosca, bottiglia, sbadiglio, farfalla, gomitolo, starnuto }

/// How long each scene lasts, in seconds.
const Map<KittenAction, double> kActionSeconds = {
  KittenAction.mosca: 4,
  KittenAction.bottiglia: 3.8,
  KittenAction.sbadiglio: 2.4,
  KittenAction.farfalla: 5,
  KittenAction.gomitolo: 3.8,
  KittenAction.starnuto: 1.6,
};

/// Scenes that make sense for [skin]: floating kittens have no floor to play on.
List<KittenAction> actionsFor(Skin skin) {
  final floats = skin.has(Effect.fluttua) || skin.has(Effect.fantasma);
  return [
    for (final a in KittenAction.values)
      if (a != KittenAction.none && !(floats && (a == KittenAction.bottiglia || a == KittenAction.gomitolo))) a,
  ];
}

/// Everything that moves on a kitten, updated by `KittenView` every frame.
class KittenAnim extends ChangeNotifier {
  double t = 0; // seconds since start, drives effects
  double blink = 0; // 0 open .. 1 closed
  double breath = 0; // -1 .. 1
  double tail = 0; // -1 .. 1
  double ear = 0; // 0 .. 1 twitch
  double look = 0; // -1 .. 1
  double bump = 0; // growth "pop" 0 .. 1
  KittenAction action = KittenAction.none; // a little random scene
  double actionT = 0; // its progress 0 .. 1

  void tick() => notifyListeners();
}

/// Draws one kitten in a 200×200 design space, scaled to fit.
///
/// Style (from the reference sheets, not copied): warm brown outline of even
/// width, chubby round shapes, dot eyes set low, ω mouth, rosy cheeks, flat
/// colours. Growth changes proportions: newborns are mostly head.
class KittenPainter extends CustomPainter {
  KittenPainter({
    required this.skin,
    required this.pose,
    required this.growth,
    this.anim,
  }) : super(repaint: anim);

  final Skin skin;
  final Pose pose;

  /// 0 = newborn, 1 = adult.
  final double growth;
  final KittenAnim? anim;

  static const _ow = 3.4; // outline width on screen, in design units
  static const _brown = Color(0xFF5A3E36);
  static const _darkLine = Color(0xFF2E2426);
  static const _innerEar = Color(0xFFF5B4AC);
  static const _blush = Color(0xFFF49C9C);
  static const _nose = Color(0xFFE98F8F);
  static const _eye = Color(0xFF3B2925);
  static const _white = Color(0xFFFFFAF3);
  static const _gold = Color(0xFFF2C94C);

  @override
  void paint(Canvas canvas, Size size) {
    final a = anim;
    final t = a?.t ?? 0;
    final blink = a?.blink ?? 0;
    final breath = a?.breath ?? 0;
    final tailSway = a?.tail ?? 0;
    final ear = a?.ear ?? 0;
    final look = a?.look ?? 0;
    final bump = a?.bump ?? 0;
    final sleeping = pose == Pose.dorme;
    final act = sleeping ? KittenAction.none : (a?.action ?? KittenAction.none);
    final ap = a?.actionT ?? 0;
    double win(double from, double to) => ap < from || ap > to ? 0 : math.sin(math.pi * (ap - from) / (to - from));
    double ramp(double from, double to) {
      final x = ((ap - from) / (to - from)).clamp(0.0, 1.0);
      return x * x * (3 - 2 * x);
    }

    final yawn = act == KittenAction.sbadiglio ? win(0.1, 0.9) : 0.0;
    final sneezeNod = act == KittenAction.starnuto ? win(0, 0.55) : 0.0;
    final hop = act == KittenAction.starnuto ? win(0.55, 1) * 8 : 0.0;
    final forceClosed = yawn > 0.35 || sneezeNod > 0.4;
    final lookEff = switch (act) {
      KittenAction.mosca => math.cos(ap * math.pi * 2.2) * -0.9,
      KittenAction.bottiglia => ap > 0.06 && ap < 0.9 ? -1.0 : look,
      KittenAction.farfalla => (_butterfly(ap).dx - 100) / 60,
      KittenAction.gomitolo => ap > 0.08 && ap < 0.8 ? 1.0 : look,
      _ => look,
    }.clamp(-1.0, 1.0);
    final lookUp = act == KittenAction.farfalla && ap > 0.25 && ap < 0.75 ? -2.0 : 0.0;

    // A front paw reaching out and back: left for the bottle, right for the yarn.
    final reach = switch (act) {
      KittenAction.bottiglia => ramp(0.16, 0.4) - ramp(0.52, 0.74),
      KittenAction.gomitolo => ramp(0.3, 0.42) - ramp(0.5, 0.66),
      _ => 0.0,
    };
    final reachPaw = act == KittenAction.bottiglia ? 0 : 1;
    Offset pawShift(int i) {
      if (reach <= 0 || i != reachPaw) return Offset.zero;
      final arc = math.sin(math.pi * reach);
      return reachPaw == 0
          ? Offset(-30 * reach, -12 * reach - 10 * arc)
          : Offset(24 * reach, -8 * reach - 8 * arc);
    }

    final floats = skin.has(Effect.fluttua) || skin.has(Effect.fantasma);
    final floatY = floats ? -(12 + 6 * math.sin(t * 1.7)) : 0.0;

    final g = growth.clamp(0.0, 1.0);
    final s = math.min(size.width, size.height) / 200;
    canvas.save();
    canvas.translate((size.width - 200 * s) / 2, (size.height - 200 * s) / 2);
    canvas.scale(s);

    // Whole-cat scale around the feet; newborns are small.
    final overall = _lerp(0.6, 1.0, g) * (1 + 0.12 * math.sin(math.pi * bump));
    canvas.translate(100, 192);
    canvas.scale(overall);
    canvas.translate(-100, -192);

    if (floats) {
      final k = 1 - (-floatY - 6) / 30;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(100, 194), width: 96 * k, height: 10 * k),
        Paint()..color = const Color(0x14000000),
      );
    }
    final ghost = skin.has(Effect.fantasma);
    if (ghost) {
      canvas.saveLayer(const Rect.fromLTWH(-60, -120, 320, 340), Paint()..color = const Color(0xBF000000));
    }
    canvas.save();
    canvas.translate(0, floatY - hop);

    final geo = _Geo.of(pose);
    final sb = _lerp(0.64, 1.0, g);
    final sbY = sb * (1 + (sleeping ? 0.03 : 0.018) * breath);
    final sh = _lerp(1.16, 1.0, g) * geo.headScale;
    final rise = 192 - geo.bodyTop;
    final headDy = rise * (1 - sb) - rise * sb * (sleeping ? 0.03 : 0.018) * breath * 0.9 + sneezeNod * 5;

    final owBody = _ow / (overall * sb);
    final owHead = _ow / (overall * sh);

    final coat = skin.coat;
    final outline = coat.darkOutline ? _darkLine : _brown;
    final base = Color(coat.base);
    final second = Color(coat.second ?? coat.base);
    final third = Color(coat.third ?? coat.base);
    final darkCoat = base.computeLuminance() < 0.12;
    final featureLine = darkCoat ? const Color(0xFFE7D6CE) : outline;
    final panda = coat.pattern == CoatPattern.panda;

    // Transforms --------------------------------------------------------------
    void bodyTf() {
      canvas.translate(100, 192);
      canvas.scale(sb, sbY);
      canvas.translate(-100, -192);
    }

    void headTf() {
      canvas.translate(geo.head.dx, geo.head.dy + headDy);
      canvas.rotate(geo.headRot - yawn * 0.07);
      canvas.scale(sh);
      canvas.translate(-100, -86);
    }

    // Shapes -------------------------------------------------------------------
    final body = geo.body;
    final head = _headPath();
    final earL = _earPath(left: true);
    final earR = _earPath(left: false);
    final paws = geo.paws;
    final tailPath = geo.tail;
    const tailW = 17.0;

    final whiteMuzzle = coat.whiteMuzzle;
    final pawColor = coat.whitePaws
        ? _white
        : (coat.pattern == CoatPattern.point || panda ? second : base);
    final earColor = coat.pattern == CoatPattern.point || panda ? second : base;
    final tailColor = switch (coat.pattern) {
      CoatPattern.point || CoatPattern.panda => second,
      CoatPattern.calico => third,
      _ => base,
    };

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint fill(Color c) => Paint()..color = c;

    void withTf(void Function() tf, void Function() draw) {
      canvas.save();
      tf();
      draw();
      canvas.restore();
    }

    void earTwitch(bool left) {
      // Right ear twitches; left follows a little.
      final pivot = left ? const Offset(66, 58) : const Offset(134, 58);
      final angle = (left ? 0.04 : -0.16) * ear;
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(angle);
      canvas.translate(-pivot.dx, -pivot.dy);
    }

    void drawTail({required bool outlinePass, required bool fillPass}) {
      withTf(bodyTf, () {
        canvas.translate(geo.tailBase.dx, geo.tailBase.dy);
        canvas.rotate((sleeping ? 0.05 : 0.2) * tailSway);
        canvas.translate(-geo.tailBase.dx, -geo.tailBase.dy);
        if (outlinePass) {
          canvas.drawPath(tailPath, stroke(outline, tailW + owBody * 2));
        }
        if (fillPass) {
          if (skin.has(Effect.codaArcobaleno)) {
            _rainbowTail(canvas, tailPath, tailW);
          } else {
            canvas.drawPath(tailPath, stroke(tailColor, tailW));
            _tailPattern(canvas, tailPath, tailW, coat, second);
          }
        }
      });
    }

    // Wings sit behind everything.
    for (final (acc, col) in [(skin.accessory, skin.accessoryColor), (skin.accessory2, skin.accessory2Color)]) {
      if (acc == Accessory.ali || acc == Accessory.aliDrago) {
        withTf(bodyTf, () => _wings(canvas, acc, Color(col), outline, owBody, t));
      }
    }

    // Cape sits behind everything.
    if (skin.accessory2 == Accessory.mantello) {
      withTf(bodyTf, () {
        final cape = Path()
          ..moveTo(56, 108)
          ..quadraticBezierTo(22, 150, 16, 192)
          ..quadraticBezierTo(100, 200, 184, 192)
          ..quadraticBezierTo(178, 150, 144, 108)
          ..close();
        canvas.drawPath(cape, stroke(outline, owBody * 2));
        canvas.drawPath(cape, fill(Color(skin.accessory2Color)));
      });
    }

    if (!sleeping) drawTail(outlinePass: true, fillPass: true);

    // Pass 1: outlines (drawn fat, the fill covers the inner half) --------------
    withTf(bodyTf, () {
      canvas.drawPath(body, stroke(outline, owBody * 2));
      for (var i = 0; i < paws.length; i++) {
        if (pawShift(i) == Offset.zero) canvas.drawPath(paws[i], stroke(outline, owBody * 2));
      }
    });
    if (sleeping) drawTail(outlinePass: true, fillPass: false);
    withTf(headTf, () {
      withTf(() => earTwitch(true), () => canvas.drawPath(earL, stroke(outline, owHead * 2)));
      withTf(() => earTwitch(false), () => canvas.drawPath(earR, stroke(outline, owHead * 2)));
      canvas.drawPath(head, stroke(outline, owHead * 2));
    });

    // Pass 2: fills ------------------------------------------------------------
    withTf(bodyTf, () {
      canvas.drawPath(body, fill(base));
      _bodyPattern(canvas, body, coat, second, third, pose);
      if (skin.has(Effect.pittura)) _paintDots(canvas, body, 0);
      if (skin.has(Effect.stelle)) _stars(canvas, body, t, 0);
      if (coat.whiteBelly && !sleeping) {
        canvas.save();
        canvas.clipPath(body);
        canvas.drawOval(geo.belly, fill(_white));
        canvas.restore();
      }
      if (!sleeping && (skin.accessory == Accessory.casco || skin.accessory2 == Accessory.casco)) {
        _suitPanel(canvas, geo.belly.center + const Offset(0, 8), outline, owBody);
      }
      // A soft shadow under the chin instead of a hard line.
      canvas.save();
      canvas.clipPath(body);
      canvas.translate(100, 192);
      canvas.scale(1 / sb, 1 / sbY);
      canvas.translate(-100, -192);
      headTf();
      canvas.drawPath(
        Path.combine(PathOperation.difference, head.shift(const Offset(0, 8)), head),
        fill(outline.withValues(alpha: darkCoat ? 0.28 : 0.13)),
      );
      canvas.restore();
    });
    if (sleeping) drawTail(outlinePass: false, fillPass: true);
    withTf(bodyTf, () {
      _floorProps(canvas, act, ap, ramp, outline);
      for (var i = 0; i < paws.length; i++) {
        final off = pawShift(i);
        final p = off == Offset.zero ? paws[i] : paws[i].shift(off);
        if (off != Offset.zero) {
          canvas.drawPath(p, stroke(outline.withValues(alpha: (reach * 5).clamp(0.0, 1.0)), owBody * 2));
        }
        canvas.drawPath(p, fill(pawColor));
        // Toe lines make paws read as paws.
        final b = p.getBounds();
        if (b.width < 14) continue;
        final c = b.center;
        final toe = stroke(outline.withValues(alpha: 0.55), owBody * 0.55);
        canvas.drawLine(c + Offset(-3, b.height * 0.1), c + Offset(-3, b.height * 0.42), toe);
        canvas.drawLine(c + Offset(3, b.height * 0.1), c + Offset(3, b.height * 0.42), toe);
      }
    });

    // Collars and scarves wrap the neck: behind the head, in front of the body.
    withTf(headTf, () {
      _neckBack(canvas, skin.accessory, Color(skin.accessoryColor), outline, owHead);
      _neckBack(canvas, skin.accessory2, Color(skin.accessory2Color), outline, owHead);
    });

    withTf(headTf, () {
      withTf(() => earTwitch(true), () {
        canvas.drawPath(earL, fill(earColor));
        _earPatch(canvas, earL, coat, second, third, left: true);
        canvas.drawPath(_innerEarPath(left: true), fill(_innerEar));
      });
      withTf(() => earTwitch(false), () {
        canvas.drawPath(earR, fill(earColor));
        _earPatch(canvas, earR, coat, second, third, left: false);
        canvas.drawPath(_innerEarPath(left: false), fill(_innerEar));
      });
      canvas.drawPath(head, fill(base));
      canvas.save();
      canvas.clipPath(head);
      _headPattern(canvas, coat, second, third);
      if (whiteMuzzle) {
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(100, 112), width: 54, height: 36),
          fill(_white),
        );
      }
      if (coat.blaze) {
        final blaze = Path()
          ..moveTo(93, 100)
          ..lineTo(97, 62)
          ..quadraticBezierTo(100, 55, 103, 62)
          ..lineTo(107, 100)
          ..close();
        canvas.drawPath(blaze, fill(_white));
      }
      if (skin.has(Effect.stelle)) _stars(canvas, head, t, 1);
      canvas.restore();
    });

    // Face --------------------------------------------------------------------
    withTf(headTf, () {
      final eyeScale = _lerp(1.18, 1.0, g);
      final dx = lookEff * 2.4;
      final eyeY = 95.0 + lookUp;
      for (final ex in const [75.0, 125.0]) {
        final c = Offset(ex + dx, eyeY);
        final lineColor = panda ? const Color(0xFFE7D6CE) : featureLine;
        if (sleeping || forceClosed) {
          _closedEye(canvas, c, lineColor, owHead);
        } else if (blink > 0.6) {
          final p = Path()
            ..moveTo(c.dx - 6.5, c.dy)
            ..quadraticBezierTo(c.dx, c.dy + 3.5, c.dx + 6.5, c.dy);
          canvas.drawPath(p, stroke(lineColor, owHead * 0.9));
        } else {
          final open = (1 - blink * 1.3).clamp(0.12, 1.0);
          if (skin.eyes != EyeStyle.puntini) {
            final r = 7.4 * eyeScale;
            final iris = switch (skin.eyes) {
              EyeStyle.dorati => const Color(0xFFF0CD6A),
              EyeStyle.verdi => const Color(0xFFA9D39A),
              _ => const Color(0xFFA9CFEF),
            };
            canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: r * 2 * open), fill(iris));
            canvas.drawOval(
              Rect.fromCenter(center: c, width: r * 2, height: r * 2 * open),
              stroke(_darkLine, owHead * 0.6),
            );
            canvas.drawOval(
              Rect.fromCenter(center: c, width: 3.6, height: r * 1.5 * open),
              fill(_eye),
            );
          } else {
            final r = 6.3 * eyeScale;
            canvas.drawOval(
              Rect.fromCenter(center: c, width: r * 2, height: r * 2 * open),
              fill(darkCoat || panda ? const Color(0xFF1E1718) : _eye),
            );
          }
          if (open > 0.5) {
            canvas.drawCircle(c + Offset(2.2, -2.4 * open), 2.1 * eyeScale, fill(const Color(0xFFFFFFFF)));
            canvas.drawCircle(c + Offset(-2.2, 2.2 * open), 0.9 * eyeScale, fill(const Color(0xFFFFFFFF).withValues(alpha: 0.8)));
          }
        }
      }
      // Cheeks.
      for (final bx in const [58.0, 142.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(bx, 109), width: 19, height: 11),
          fill(_blush.withValues(alpha: darkCoat ? 0.45 : 0.6)),
        );
      }
      // Nose and ω mouth.
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(100, 102.5), width: 6.5, height: 4.4),
        fill(_nose),
      );
      final mouth = Path()
        ..moveTo(92.5, 105.5)
        ..quadraticBezierTo(96, 111, 100, 106)
        ..quadraticBezierTo(104, 111, 107.5, 105.5);
      if (yawn > 0.12) {
        final r = Rect.fromCenter(center: Offset(100, 109 + yawn * 2), width: 8 + yawn * 7, height: 4 + yawn * 12);
        canvas.drawOval(r, fill(const Color(0xFFB9616B)));
        canvas.drawOval(
          Rect.fromCenter(center: r.bottomCenter - Offset(0, r.height * 0.28), width: r.width * 0.6, height: r.height * 0.35),
          fill(const Color(0xFFEE9AA3)),
        );
        canvas.drawOval(r, stroke(featureLine, owHead * 0.8));
      } else {
        canvas.drawPath(mouth, stroke(featureLine, owHead * 0.8));
      }

      _accessory(canvas, skin.accessory, Color(skin.accessoryColor), outline, owHead, t);
      if (skin.accessory2 != Accessory.mantello) {
        _accessory(canvas, skin.accessory2, Color(skin.accessory2Color), outline, owHead, t);
      } else {
        canvas.drawCircle(const Offset(100, 140), 5.5, fill(_gold));
        canvas.drawCircle(const Offset(100, 140), 5.5, stroke(outline, owHead * 0.7));
      }
      _headProps(canvas, act, ap, ramp, win, outline, t);
    });

    canvas.restore(); // float / hop
    if (ghost) canvas.restore();
    _frontEffect(canvas, t, skin.effect);
    if (skin.effect2 != skin.effect) _frontEffect(canvas, t, skin.effect2);
    if (sleeping) _zzz(canvas, t, geo.head.dx - 20, geo.head.dy - 40);

    canvas.restore();
  }

  // --- Geometry ---------------------------------------------------------------

  Path _headPath() => Path()
    ..moveTo(100, 40)
    ..cubicTo(140, 40, 162, 60, 162, 92)
    ..cubicTo(162, 120, 136, 134, 100, 134)
    ..cubicTo(64, 134, 38, 120, 38, 92)
    ..cubicTo(38, 60, 60, 40, 100, 40)
    ..close();

  Path _earPath({required bool left}) {
    final p = Path()
      ..moveTo(44, 72)
      ..lineTo(47, 32)
      ..quadraticBezierTo(49, 17, 61, 25)
      ..lineTo(88, 48)
      ..close();
    return left ? p : p.transform(_mirror);
  }

  Path _innerEarPath({required bool left}) {
    final p = Path()
      ..moveTo(53, 62)
      ..lineTo(54, 38)
      ..quadraticBezierTo(55, 31, 61, 35)
      ..lineTo(79, 51)
      ..close();
    return left ? p : p.transform(_mirror);
  }

  static final _mirror = Float64List.fromList([
    -1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    200, 0, 0, 1, //
  ]);

  // --- Patterns ---------------------------------------------------------------

  void _headPattern(Canvas c, Coat coat, Color second, Color third) {
    final p = Paint()..style = PaintingStyle.fill;
    final s = Paint()
      ..color = second
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const cheeks = [
      (Offset(38, 90), Offset(52, 92)),
      (Offset(39, 101), Offset(51, 100.5)),
      (Offset(162, 90), Offset(148, 92)),
      (Offset(161, 101), Offset(149, 100.5)),
    ];
    switch (coat.pattern) {
      case CoatPattern.tigrato:
        c.drawLine(const Offset(90, 47), const Offset(92.5, 60), s);
        c.drawLine(const Offset(100, 45), const Offset(100, 61), s);
        c.drawLine(const Offset(110, 47), const Offset(107.5, 60), s);
        for (final (a, b) in cheeks) {
          c.drawLine(a, b, s);
        }
      case CoatPattern.soriano:
        // The tabby "M" on the forehead, cheek stripes and a few light flecks.
        c.drawPath(
          Path()
            ..moveTo(86, 60)
            ..quadraticBezierTo(87, 52, 90, 49)
            ..quadraticBezierTo(94, 54, 95, 57)
            ..quadraticBezierTo(98, 50, 100, 46)
            ..quadraticBezierTo(102, 50, 105, 57)
            ..quadraticBezierTo(106, 54, 110, 49)
            ..quadraticBezierTo(113, 52, 114, 60),
          s..strokeWidth = 3.8,
        );
        s.strokeWidth = 5;
        for (final (a, b) in cheeks) {
          c.drawLine(a, b, s);
        }
        for (final o in const [Offset(76, 60), Offset(126, 58), Offset(66, 116), Offset(136, 118)]) {
          c.drawOval(Rect.fromCenter(center: o, width: 7, height: 4), p..color = third);
        }
      case CoatPattern.calico:
        c.drawCircle(const Offset(58, 56), 31, p..color = second);
        c.drawCircle(const Offset(148, 66), 21, p..color = third);
      case CoatPattern.point:
        c.drawOval(
          Rect.fromCenter(center: const Offset(100, 114), width: 64, height: 42),
          p..color = second.withValues(alpha: 0.8),
        );
      case CoatPattern.macchie:
        c.drawCircle(const Offset(62, 62), 11, p..color = second);
        c.drawCircle(const Offset(140, 58), 8, p..color = second);
      case CoatPattern.panda:
        for (final (o, rot) in const [(Offset(75, 96), -0.5), (Offset(125, 96), 0.5)]) {
          c.save();
          c.translate(o.dx, o.dy);
          c.rotate(rot);
          c.drawOval(Rect.fromCenter(center: Offset.zero, width: 27, height: 21), p..color = second);
          c.restore();
        }
      case CoatPattern.tintaUnita:
        break;
    }
  }

  void _earPatch(Canvas c, Path ear, Coat coat, Color second, Color third, {required bool left}) {
    if (coat.pattern != CoatPattern.calico) return;
    c.save();
    c.clipPath(ear);
    c.drawCircle(
      left ? const Offset(58, 56) : const Offset(148, 66),
      left ? 31 : 21,
      Paint()..color = left ? second : third,
    );
    c.restore();
  }

  void _bodyPattern(Canvas c, Path body, Coat coat, Color second, Color third, Pose pose) {
    c.save();
    c.clipPath(body);
    final p = Paint();
    switch (coat.pattern) {
      case CoatPattern.tigrato:
      case CoatPattern.soriano:
        final s = Paint()
          ..color = second
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round;
        final lines = switch (pose) {
          Pose.seduto => const [
            (Offset(44, 140), Offset(58, 145)),
            (Offset(42, 156), Offset(56, 160)),
            (Offset(44, 172), Offset(57, 174)),
            (Offset(156, 140), Offset(142, 145)),
            (Offset(158, 156), Offset(144, 160)),
            (Offset(156, 172), Offset(143, 174)),
          ],
          Pose.pagnotta => const [
            (Offset(66, 120), Offset(71, 134)),
            (Offset(134, 120), Offset(129, 134)),
            (Offset(40, 158), Offset(54, 161)),
            (Offset(160, 158), Offset(146, 161)),
            (Offset(42, 174), Offset(55, 176)),
            (Offset(158, 174), Offset(145, 176)),
          ],
          Pose.dorme => const [
            (Offset(92, 132), Offset(94, 146)),
            (Offset(112, 131), Offset(112, 145)),
            (Offset(132, 133), Offset(130, 147)),
            (Offset(151, 139), Offset(147, 151)),
          ],
        };
        for (final (a, b) in lines) {
          c.drawLine(a, b, s);
        }
        if (coat.pattern == CoatPattern.soriano) {
          final flecks = switch (pose) {
            Pose.seduto => const [Offset(64, 128), Offset(138, 124), Offset(60, 184), Offset(142, 182)],
            Pose.pagnotta => const [Offset(84, 128), Offset(118, 126), Offset(56, 146), Offset(146, 144)],
            Pose.dorme => const [Offset(102, 140), Offset(122, 140), Offset(140, 146)],
          };
          for (final o in flecks) {
            c.drawOval(Rect.fromCenter(center: o, width: 8, height: 4.5), p..color = third);
          }
        }
      case CoatPattern.calico:
        final spots = switch (pose) {
          Pose.seduto => const [(Offset(150, 146), 27.0, 0), (Offset(54, 178), 19.0, 1)],
          Pose.pagnotta => const [(Offset(152, 146), 27.0, 0), (Offset(56, 150), 21.0, 1)],
          Pose.dorme => const [(Offset(142, 148), 25.0, 0), (Offset(98, 138), 18.0, 1)],
        };
        for (final (o, r, k) in spots) {
          c.drawCircle(o, r, p..color = k == 0 ? second : third);
        }
      case CoatPattern.point:
        c.drawOval(
          Rect.fromCenter(center: const Offset(100, 196), width: 120, height: 40),
          p..color = second.withValues(alpha: 0.35),
        );
      case CoatPattern.macchie:
        final spots = switch (pose) {
          Pose.seduto => const [(Offset(66, 142), 11.0), (Offset(136, 162), 13.0), (Offset(118, 124), 7.0)],
          Pose.pagnotta => const [(Offset(62, 140), 12.0), (Offset(142, 136), 10.0), (Offset(112, 122), 7.0)],
          Pose.dorme => const [(Offset(92, 146), 11.0), (Offset(138, 150), 12.0)],
        };
        for (final (o, r) in spots) {
          c.drawCircle(o, r, p..color = second);
        }
      case CoatPattern.panda:
        // The dark shoulder band.
        final band = switch (pose) {
          Pose.seduto => Rect.fromCenter(center: const Offset(100, 118), width: 140, height: 34),
          Pose.pagnotta => Rect.fromCenter(center: const Offset(100, 128), width: 170, height: 30),
          Pose.dorme => Rect.fromCenter(center: const Offset(70, 150), width: 40, height: 70),
        };
        c.drawRect(band, p..color = second);
      case CoatPattern.tintaUnita:
        break;
    }
    c.restore();
  }

  void _tailPattern(Canvas c, Path tail, double w, Coat coat, Color second) {
    final metric = tail.computeMetrics().firstOrNull;
    if (metric == null) return;
    if (coat.pattern == CoatPattern.tigrato || coat.pattern == CoatPattern.soriano) {
      final s = Paint()
        ..color = second
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      for (final f in const [0.45, 0.68, 0.88]) {
        final tg = metric.getTangentForOffset(metric.length * f);
        if (tg == null) continue;
        final n = Offset(-tg.vector.dy, tg.vector.dx) * (w * 0.36);
        c.drawLine(tg.position - n, tg.position + n, s);
      }
    } else if (coat.pattern == CoatPattern.macchie) {
      final tip = metric.extractPath(metric.length * 0.72, metric.length);
      c.drawPath(
        tip,
        Paint()
          ..color = second
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _rainbowTail(Canvas c, Path tail, double w) {
    final metric = tail.computeMetrics().firstOrNull;
    if (metric == null) return;
    const colors = [
      Color(0xFFFFFAF3),
      Color(0xFFF7C1CF),
      Color(0xFFF8D7A6),
      Color(0xFFBFE3C0),
      Color(0xFFB9D3F3),
      Color(0xFFD5C1F2),
    ];
    for (var i = 0; i < colors.length; i++) {
      final seg = metric.extractPath(
        metric.length * i / colors.length,
        metric.length * (i + 1) / colors.length + 0.5,
      );
      c.drawPath(
        seg,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = i == 0 || i == colors.length - 1 ? StrokeCap.round : StrokeCap.butt,
      );
    }
  }

  void _closedEye(Canvas c, Offset e, Color color, double ow) {
    final p = Path()
      ..moveTo(e.dx - 7, e.dy - 1)
      ..quadraticBezierTo(e.dx, e.dy + 6, e.dx + 7, e.dy - 1);
    c.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ow * 0.9
        ..strokeCap = StrokeCap.round,
    );
  }

  /// The chest panel of the space suit (body space).
  void _suitPanel(Canvas c, Offset o, Color outline, double ow) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 34, height: 22), const Radius.circular(6));
    c.drawRRect(r, Paint()..color = const Color(0xFFE9EEF3));
    c.drawRRect(
      r,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = ow * 0.8,
    );
    const lights = [Color(0xFFE88A8A), Color(0xFF9DC7EA), Color(0xFFF6D46E)];
    for (var i = 0; i < 3; i++) {
      c.drawCircle(o + Offset(-9.0 + i * 9, 0), 3.2, Paint()..color = lights[i]);
    }
  }

  // --- Accessories (head space) -----------------------------------------------

  /// The parts of neck accessories that go behind the chin.
  void _neckBack(Canvas c, Accessory acc, Color color, Color outline, double ow) {
    Paint band(Color col, double w) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    switch (acc) {
      case Accessory.campanella:
        final collar = Path()
          ..moveTo(58, 120)
          ..quadraticBezierTo(100, 158, 142, 120);
        c.drawPath(collar, band(outline, 9 + ow * 2));
        c.drawPath(collar, band(color, 9));
      case Accessory.sciarpa:
        final scarf = Path()
          ..moveTo(50, 114)
          ..quadraticBezierTo(100, 152, 150, 114)
          ..lineTo(153, 128)
          ..quadraticBezierTo(100, 170, 47, 128)
          ..close();
        c.drawPath(scarf, Paint()..color = color);
        c.drawPath(
          scarf,
          Paint()
            ..color = outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = ow * 0.8
            ..strokeJoin = StrokeJoin.round,
        );
        c.drawPath(
          Path()
            ..moveTo(52, 122)
            ..quadraticBezierTo(100, 162, 150, 122),
          band(const Color(0xFFFFFFFF).withValues(alpha: 0.5), 2.4),
        );
      default:
        break;
    }
  }

  void _accessory(Canvas c, Accessory acc, Color color, Color outline, double ow, double t) {
    final line = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = ow * 0.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final f = Paint()..color = color;
    void both(Path p, [Paint? fillPaint]) {
      c.drawPath(p, fillPaint ?? f);
      c.drawPath(p, line);
    }

    switch (acc) {
      case Accessory.nessuno:
      case Accessory.mantello:
      case Accessory.ali:
      case Accessory.aliDrago:
        return;
      case Accessory.cappelloMago:
      case Accessory.cappelloStrega:
        final witch = acc == Accessory.cappelloStrega;
        final cone = Path()
          ..moveTo(62, 50)
          ..quadraticBezierTo(84, 10, 96, -14)
          ..quadraticBezierTo(102, -24, 112, -18)
          ..quadraticBezierTo(104, -10, 106, 2)
          ..quadraticBezierTo(116, 30, 138, 50)
          ..close();
        both(Path()..addOval(Rect.fromCenter(center: const Offset(100, 50), width: 112, height: 20)));
        both(cone);
        if (witch) {
          final band = Path()
            ..moveTo(68, 42)
            ..quadraticBezierTo(100, 50, 132, 42)
            ..lineTo(134, 48)
            ..quadraticBezierTo(100, 57, 66, 48)
            ..close();
          c.drawPath(band, Paint()..color = const Color(0xFFB89BE3));
          c.drawPath(band, line);
          c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(100, 48), width: 11, height: 9), const Radius.circular(2)),
            Paint()..color = _gold,
          );
        } else {
          for (final (o, r) in const [(Offset(90, 30), 3.4), (Offset(106, 12), 2.6), (Offset(116, 38), 2.8), (Offset(82, 44), 2.2)]) {
            _sparkle(c, o, r, const Color(0xFFF6DB7A));
          }
          c.drawCircle(const Offset(113, -20), 4, Paint()..color = const Color(0xFFF6DB7A));
        }
      case Accessory.aureola:
        final y = 14 + math.sin(t * 2) * 2.5;
        final ring = Rect.fromCenter(center: Offset(100, y), width: 66, height: 16);
        c.drawOval(ring, Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 + ow);
        c.drawOval(ring, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7);
      case Accessory.cornine:
        // Two little curved horns on the crown, between the ears.
        final horn = Path()
          ..moveTo(83, 47)
          ..quadraticBezierTo(77, 36, 80, 21)
          ..quadraticBezierTo(89, 30, 97, 44)
          ..quadraticBezierTo(90, 49, 83, 47)
          ..close();
        both(horn);
        both(horn.transform(_mirror));
        final shine = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.45)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(84, 38), const Offset(83, 30), shine);
        c.drawLine(const Offset(116, 38), const Offset(117, 30), shine);
      case Accessory.cappelloChef:
        both(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(68, 30, 132, 54), const Radius.circular(6))));
        final puff = Path()
          ..addOval(Rect.fromCircle(center: const Offset(78, 20), radius: 17))
          ..addOval(Rect.fromCircle(center: const Offset(100, 10), radius: 20))
          ..addOval(Rect.fromCircle(center: const Offset(122, 20), radius: 17));
        c.drawPath(puff, Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = ow * 1.6);
        c.drawPath(puff, Paint()..color = color);
        final pleat = Paint()
          ..color = outline.withValues(alpha: 0.3)
          ..strokeWidth = ow * 0.7;
        c.drawLine(const Offset(84, 36), const Offset(84, 50), pleat);
        c.drawLine(const Offset(100, 36), const Offset(100, 50), pleat);
        c.drawLine(const Offset(116, 36), const Offset(116, 50), pleat);
      case Accessory.bandana:
        final band = Path()
          ..moveTo(46, 66)
          ..quadraticBezierTo(100, 30, 154, 66)
          ..lineTo(150, 54)
          ..quadraticBezierTo(100, 18, 50, 54)
          ..close();
        both(band);
        for (final (dx, dy) in const [(0.0, 0.0), (6.0, 10.0)]) {
          both(Path()
            ..moveTo(154, 62)
            ..quadraticBezierTo(170 + dx, 64 + dy, 176 + dx, 76 + dy)
            ..quadraticBezierTo(164 + dx, 74 + dy, 152, 66)
            ..close());
        }
        for (final o in const [Offset(80, 46), Offset(100, 40), Offset(120, 46)]) {
          c.drawCircle(o, 2.4, Paint()..color = const Color(0xFFFFFAF3));
        }
      case Accessory.cappelloFesta:
        c.save();
        c.translate(122, 44);
        c.rotate(0.35);
        final cone = Path()
          ..moveTo(-16, 0)
          ..lineTo(0, -44)
          ..lineTo(16, 0)
          ..quadraticBezierTo(0, 6, -16, 0)
          ..close();
        c.drawPath(cone, f);
        c.save();
        c.clipPath(cone);
        for (var i = 0; i < 4; i++) {
          c.drawLine(Offset(-20, -8.0 - i * 11), Offset(20, -14.0 - i * 11),
              Paint()
                ..color = const Color(0xFFFFFAF3)
                ..strokeWidth = 4);
        }
        c.restore();
        c.drawPath(cone, line);
        both(Path()..addOval(Rect.fromCircle(center: const Offset(0, -46), radius: 6)));
        c.restore();
      case Accessory.girasole:
        const o = Offset(136, 50);
        for (var k = 0; k < 10; k++) {
          c.save();
          c.translate(o.dx, o.dy);
          c.rotate(k * math.pi / 5);
          final petal = Path()..addOval(Rect.fromCenter(center: const Offset(0, -10), width: 8, height: 13));
          c.drawPath(petal, f);
          c.drawPath(petal, line);
          c.restore();
        }
        c.drawCircle(o, 7.5, Paint()..color = const Color(0xFF8C6150));
        c.drawCircle(o, 7.5, line);
      case Accessory.casco:
        // A real space helmet: glass dome, thick rim, neck ring and antenna.
        const center = Offset(100, 86);
        const r = 76.0;
        c.save();
        c.clipRect(const Rect.fromLTRB(-40, -60, 240, 140));
        c.drawCircle(
          center,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              center - const Offset(24, 30),
              r * 1.2,
              [const Color(0x40DDF1FB), const Color(0x1FA9D3EA)],
            ),
        );
        c.drawCircle(center, r, Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9 + ow * 2);
        c.drawCircle(center, r, Paint()
          ..color = const Color(0xFFF1F4F8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9);
        c.restore();
        c.drawArc(Rect.fromCircle(center: center, radius: r - 13), 3.55, 0.8, false, Paint()
          ..color = const Color(0xDDFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
        c.drawCircle(center + const Offset(-50, -30), 3.2, Paint()..color = const Color(0xCCFFFFFF));
        // Antenna on the rim.
        c.drawLine(const Offset(136, 22), const Offset(146, 2), Paint()
          ..color = outline
          ..strokeWidth = 3.4 + ow
          ..strokeCap = StrokeCap.round);
        c.drawLine(const Offset(136, 22), const Offset(146, 2), Paint()
          ..color = const Color(0xFFD5DDE5)
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round);
        final glow = 0.6 + 0.4 * math.sin(t * 3);
        c.drawCircle(const Offset(146, 1), 5, Paint()..color = const Color(0xFFE88A8A).withValues(alpha: glow));
        c.drawCircle(const Offset(146, 1), 5, line);
        // Neck ring.
        final ring = RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(100, 144), width: 118, height: 18), const Radius.circular(9));
        both(Path()..addRRect(ring), Paint()..color = const Color(0xFFE9EEF3));
        for (final x in const [64.0, 100.0, 136.0]) {
          c.drawCircle(Offset(x, 144), 2.6, Paint()..color = const Color(0xFFB7C3CE));
        }
      case Accessory.fiocco:
        c.save();
        c.translate(136, 50);
        c.rotate(0.35);
        both(Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-10, -16, -19, -6)
          ..quadraticBezierTo(-22, 6, 0, 0)
          ..close());
        both(Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(10, -16, 19, -6)
          ..quadraticBezierTo(22, 6, 0, 0)
          ..close());
        both(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 4.6)));
        c.restore();
      case Accessory.sciarpa:
        // The band is behind the chin (see _neckBack); the loose end hangs in front.
        final flutter = skin.has(Effect.sciarpaVento) ? math.sin(t * 3.2) * 0.22 : 0.0;
        c.save();
        c.translate(126, 140);
        c.rotate(0.12 + flutter);
        both(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -2, 15, 32), const Radius.circular(5))));
        final fringe = Paint()
          ..color = outline
          ..strokeWidth = ow * 0.55
          ..strokeCap = StrokeCap.round;
        for (final x in const [-3.0, 0.5, 4.0]) {
          c.drawLine(Offset(x, 30), Offset(x, 35), fringe);
        }
        c.restore();
      case Accessory.campanella:
        final bell = Path()..addOval(Rect.fromCircle(center: const Offset(100, 147), radius: 8));
        c.drawPath(bell, Paint()..color = _gold);
        c.drawPath(bell, line);
        c.drawLine(const Offset(100, 149), const Offset(100, 154), line);
        c.drawCircle(const Offset(97.5, 144.5), 1.8, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8));
      case Accessory.papillon:
        final wing = Path()
          ..moveTo(100, 140)
          ..quadraticBezierTo(90, 128, 81, 131)
          ..quadraticBezierTo(76, 140, 81, 149)
          ..quadraticBezierTo(90, 152, 100, 140)
          ..close();
        both(wing);
        both(wing.transform(_mirror));
        both(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(100, 140), width: 9, height: 11), const Radius.circular(3))));
      case Accessory.cuffie:
        final bandPath = Path()
          ..moveTo(42, 92)
          ..cubicTo(36, 18, 164, 18, 158, 92);
        c.drawPath(
          bandPath,
          Paint()
            ..color = outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8 + ow * 1.6
            ..strokeCap = StrokeCap.round,
        );
        c.drawPath(
          bandPath,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round,
        );
        for (final x in const [40.0, 160.0]) {
          both(Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, 98), width: 18, height: 32),
              const Radius.circular(9),
            )));
        }
      case Accessory.berretto:
        // A snug beanie on the crown; the ears stay out on both sides.
        both(Path()
          ..moveTo(62, 56)
          ..cubicTo(60, 22, 140, 22, 138, 56)
          ..close());
        final cuff = RRect.fromRectAndRadius(const Rect.fromLTRB(58, 48, 142, 61), const Radius.circular(6.5));
        both(Path()..addRRect(cuff));
        final rib = Paint()
          ..color = outline.withValues(alpha: 0.3)
          ..strokeWidth = 1.5;
        for (var x = 66.0; x < 138; x += 9) {
          c.drawLine(Offset(x, 51), Offset(x, 58), rib);
        }
        both(Path()..addOval(Rect.fromCircle(center: const Offset(100, 26), radius: 7)));
      case Accessory.basco:
        c.save();
        c.translate(112, 48);
        c.rotate(-0.2);
        both(Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 76, height: 26)));
        both(Path()..addOval(Rect.fromCircle(center: const Offset(0, -14), radius: 3.6)));
        c.restore();
      case Accessory.coronaFiori:
        const spots = [Offset(60, 58), Offset(78, 47), Offset(100, 43), Offset(122, 47), Offset(140, 58)];
        for (var i = 0; i < spots.length; i++) {
          final petal = i.isEven ? color : const Color(0xFFFFF6EE);
          for (var k = 0; k < 5; k++) {
            final ang = k * 2 * math.pi / 5 - math.pi / 2;
            final o = spots[i] + Offset(math.cos(ang), math.sin(ang)) * 5.2;
            c.drawCircle(o, 4.8, Paint()..color = outline);
            c.drawCircle(o, 3.9, Paint()..color = petal);
          }
          c.drawCircle(spots[i], 3.1, Paint()..color = const Color(0xFFF6D46E));
        }
      case Accessory.occhiali:
        final rim = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2;
        for (final x in const [75.0, 125.0]) {
          c.drawCircle(Offset(x, 95), 13.5, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.22));
          c.drawCircle(Offset(x, 95), 13.5, rim);
        }
        c.drawPath(
          Path()
            ..moveTo(88.5, 93)
            ..quadraticBezierTo(100, 87, 111.5, 93),
          rim,
        );
      case Accessory.germoglio:
        final stem = Paint()
          ..color = const Color(0xFF6E9B5E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round;
        final sway = math.sin(t * 1.6) * 0.08;
        c.save();
        c.translate(100, 44);
        c.rotate(sway);
        c.drawPath(
          Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(-4, -10, 0, -20),
          stem,
        );
        for (final (dx, rot) in const [(-9.0, -0.5), (9.0, 0.5)]) {
          c.save();
          c.translate(dx, -22);
          c.rotate(rot);
          both(Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 18, height: 10)));
          c.restore();
        }
        c.restore();
      case Accessory.corona:
        final crown = Path()
          ..moveTo(80, 50)
          ..lineTo(82, 28)
          ..lineTo(91, 38)
          ..lineTo(100, 22)
          ..lineTo(109, 38)
          ..lineTo(118, 28)
          ..lineTo(120, 50)
          ..close();
        both(crown);
        c.drawCircle(const Offset(100, 42), 3, Paint()..color = const Color(0xFFE88AA6));
        c.drawCircle(const Offset(88, 44), 2.2, Paint()..color = const Color(0xFF9DC7EA));
        c.drawCircle(const Offset(112, 44), 2.2, Paint()..color = const Color(0xFF9DC7EA));
      case Accessory.tiara:
        final tiara = Path()
          ..moveTo(74, 52)
          ..quadraticBezierTo(80, 46, 84, 44)
          ..lineTo(88, 38)
          ..lineTo(92, 42)
          ..lineTo(100, 28)
          ..lineTo(108, 42)
          ..lineTo(112, 38)
          ..lineTo(116, 44)
          ..quadraticBezierTo(120, 46, 126, 52)
          ..quadraticBezierTo(100, 44, 74, 52)
          ..close();
        both(tiara);
        for (final o in const [Offset(88, 37), Offset(112, 37)]) {
          c.drawCircle(o, 2.8, Paint()..color = const Color(0xFFFFFFFF));
          c.drawCircle(o, 2.8, line);
        }
        c.drawCircle(const Offset(100, 27), 3.4, Paint()..color = const Color(0xFFFFFFFF));
        c.drawCircle(const Offset(100, 27), 3.4, line);
        c.drawCircle(const Offset(100, 44), 3.2, Paint()..color = const Color(0xFFE88AA6));
      case Accessory.lunaFermaglio:
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: const Offset(138, 52), radius: 11)),
          Path()..addOval(Rect.fromCircle(center: const Offset(144, 47), radius: 9.5)),
        );
        both(moon);
      case Accessory.coronaFoglie:
        const spots = [
          (Offset(56, 62), -1.0),
          (Offset(70, 50), -0.6),
          (Offset(86, 44), -0.25),
          (Offset(100, 42), 0.0),
          (Offset(114, 44), 0.25),
          (Offset(130, 50), 0.6),
          (Offset(144, 62), 1.0),
        ];
        for (var i = 0; i < spots.length; i++) {
          c.save();
          c.translate(spots[i].$1.dx, spots[i].$1.dy);
          c.rotate(spots[i].$2 * 0.9 + (i.isEven ? -0.55 : 0.55));
          final leaf = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 19, height: 9.5));
          both(leaf, Paint()..color = i.isEven ? color : Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!);
          c.restore();
        }
      case Accessory.antennine:
        for (final side in const [-1.0, 1.0]) {
          final stalk = Path()
            ..moveTo(100 + side * 11, 45)
            ..quadraticBezierTo(100 + side * 10, 26, 100 + side * 24, 12);
          c.drawPath(stalk, Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..strokeCap = StrokeCap.round);
          final tip = Offset(100 + side * 24, 12 + math.sin(t * 2.4 + side) * 1.5);
          c.drawCircle(tip, 5.5, Paint()..color = color);
          c.drawCircle(tip + const Offset(-1.6, -1.6), 1.6, Paint()..color = const Color(0x99FFFFFF));
        }
      case Accessory.cappuccioRana:
        final outer = Path.combine(
          PathOperation.union,
          Path()..addOval(Rect.fromCenter(center: const Offset(100, 76), width: 146, height: 122)),
          Path()
            ..addOval(Rect.fromCircle(center: const Offset(64, 26), radius: 18))
            ..addOval(Rect.fromCircle(center: const Offset(136, 26), radius: 18)),
        );
        final hood = Path.combine(
          PathOperation.difference,
          outer,
          Path()..addOval(Rect.fromCenter(center: const Offset(100, 101), width: 104, height: 70)),
        );
        both(hood);
        for (final x in const [64.0, 136.0]) {
          c.drawCircle(Offset(x, 25), 10, Paint()..color = const Color(0xFFFFFAF3));
          c.drawCircle(Offset(x, 25), 10, line);
          c.drawCircle(Offset(x + 1.5, 26), 5, Paint()..color = const Color(0xFF3B2925));
          c.drawCircle(Offset(x + 3, 24), 1.6, Paint()..color = const Color(0xFFFFFFFF));
        }
        c.drawCircle(const Offset(50, 90), 4, Paint()..color = const Color(0xFFF49C9C).withValues(alpha: 0.7));
        c.drawCircle(const Offset(150, 90), 4, Paint()..color = const Color(0xFFF49C9C).withValues(alpha: 0.7));
      case Accessory.cappelloCowboy:
        both(Path()..addOval(Rect.fromCenter(center: const Offset(100, 44), width: 128, height: 22)));
        final crown = Path()
          ..moveTo(76, 46)
          ..lineTo(79, 16)
          ..quadraticBezierTo(90, 9, 100, 17)
          ..quadraticBezierTo(110, 9, 121, 16)
          ..lineTo(124, 46)
          ..quadraticBezierTo(100, 51, 76, 46)
          ..close();
        both(crown);
        final band = Path()
          ..moveTo(77.5, 34)
          ..quadraticBezierTo(100, 39, 122.5, 34)
          ..lineTo(123.2, 41)
          ..quadraticBezierTo(100, 46, 76.8, 41)
          ..close();
        c.drawPath(band, Paint()..color = Color.lerp(color, const Color(0xFF5A3E36), 0.45)!);
      case Accessory.cappelloFragola:
        final berry = Path()
          ..moveTo(66, 54)
          ..cubicTo(60, 24, 84, 12, 100, 12)
          ..cubicTo(116, 12, 140, 24, 134, 54)
          ..quadraticBezierTo(100, 62, 66, 54)
          ..close();
        both(berry);
        for (final o in const [Offset(82, 30), Offset(100, 24), Offset(118, 30), Offset(76, 44), Offset(92, 40), Offset(108, 40), Offset(124, 44)]) {
          c.drawOval(Rect.fromCenter(center: o, width: 3, height: 4.5), Paint()..color = const Color(0xFFFFF1B8));
        }
        for (var k = 0; k < 5; k++) {
          c.save();
          c.translate(100, 13);
          c.rotate(-math.pi / 2 + (k - 2) * 0.62);
          both(Path()..addOval(Rect.fromCenter(center: const Offset(8, 0), width: 16, height: 7)), Paint()..color = const Color(0xFF8FC98A));
          c.restore();
        }
        c.drawLine(const Offset(100, 10), const Offset(102, 0), line..strokeWidth = ow * 1.1);
      case Accessory.ciliegie:
        final stem = Paint()
          ..color = const Color(0xFF6E9B5E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        c.drawPath(Path()
          ..moveTo(130, 58)
          ..quadraticBezierTo(132, 44, 140, 38), stem);
        c.drawPath(Path()
          ..moveTo(144, 60)
          ..quadraticBezierTo(142, 46, 140, 38), stem);
        c.save();
        c.translate(146, 38);
        c.rotate(-0.4);
        both(Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 13, height: 7)), Paint()..color = const Color(0xFF8FC98A));
        c.restore();
        for (final o in const [Offset(130, 60), Offset(144, 62)]) {
          both(Path()..addOval(Rect.fromCircle(center: o, radius: 6.5)));
          c.drawCircle(o + const Offset(-2, -2), 1.7, Paint()..color = const Color(0xBBFFFFFF));
        }
      case Accessory.cornoUnicorno:
        final horn = Path()
          ..moveTo(92, 46)
          ..lineTo(100, 2)
          ..lineTo(108, 46)
          ..quadraticBezierTo(100, 50, 92, 46)
          ..close();
        c.drawPath(horn, f);
        c.save();
        c.clipPath(horn);
        final swirl = Paint()
          ..color = const Color(0xFFFFF6D8)
          ..strokeWidth = 2.6;
        for (var i = 0; i < 4; i++) {
          final y = 40.0 - i * 10;
          c.drawLine(Offset(88, y), Offset(112, y - 7), swirl);
        }
        c.restore();
        c.drawPath(horn, line);
    }
  }

  // --- Effects ----------------------------------------------------------------

  void _stars(Canvas c, Path clip, double t, int layer) {
    c.save();
    c.clipPath(clip);
    const pts = [
      [Offset(70, 140), Offset(130, 156), Offset(100, 176), Offset(58, 168), Offset(146, 130)],
      [Offset(66, 70), Offset(132, 62), Offset(112, 120), Offset(84, 124)],
    ];
    for (var i = 0; i < pts[layer].length; i++) {
      final a = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 2.2 + i * 1.7));
      _sparkle(c, pts[layer][i], 3.4, const Color(0xFFFFF2C4).withValues(alpha: a));
    }
    c.restore();
  }

  void _paintDots(Canvas c, Path clip, int layer) {
    c.save();
    c.clipPath(clip);
    const dots = [
      (Offset(66, 150), Color(0xFFF2A7C3)),
      (Offset(132, 166), Color(0xFF9DC7EA)),
      (Offset(120, 136), Color(0xFFF6D46E)),
      (Offset(78, 176), Color(0xFFA9D18E)),
    ];
    for (final (o, col) in dots) {
      c.drawCircle(o, 5.5, Paint()..color = col);
    }
    c.restore();
  }

  void _sparkle(Canvas c, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r * 2)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r * 2, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r * 2)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r * 2, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r * 2)
      ..close();
    c.drawPath(p, Paint()..color = color);
  }

  void _frontEffect(Canvas c, double t, Effect effect) {
    switch (effect) {
      case Effect.scintille:
        const pts = [Offset(26, 70), Offset(174, 58), Offset(20, 150), Offset(180, 140)];
        for (var i = 0; i < pts.length; i++) {
          final k = 0.5 + 0.5 * math.sin(t * 2.4 + i * 1.9);
          _sparkle(c, pts[i], 2.4 + 2.4 * k, const Color(0xFFF6D77A).withValues(alpha: 0.35 + 0.6 * k));
        }
      case Effect.codaArcobaleno:
        const pts = [Offset(30, 60), Offset(172, 76), Offset(24, 132)];
        const cols = [Color(0xFFF7C1CF), Color(0xFFB9D3F3), Color(0xFFF8D7A6)];
        for (var i = 0; i < pts.length; i++) {
          final k = 0.5 + 0.5 * math.sin(t * 2 + i * 2.1);
          _sparkle(c, pts[i], 2 + 2.5 * k, cols[i].withValues(alpha: 0.4 + 0.6 * k));
        }
      case Effect.petali:
        for (var i = 0; i < 4; i++) {
          final y = (t * 16 + i * 52) % 210 - 10;
          final x = 30.0 + i * 46 + math.sin(t * 1.3 + i) * 10;
          c.save();
          c.translate(x, y);
          c.rotate(t * 1.2 + i);
          c.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 9, height: 6),
            Paint()..color = const Color(0xFFF7B8CC).withValues(alpha: 0.9),
          );
          c.restore();
        }
      case Effect.foglie:
        const cols = [Color(0xFFE59A5B), Color(0xFFD9744F), Color(0xFFE9C46A), Color(0xFFB9825C)];
        for (var i = 0; i < 5; i++) {
          final y = (t * 15 + i * 43) % 214 - 12;
          final x = 22.0 + i * 38 + math.sin(t * 1.1 + i * 1.7) * 12;
          c.save();
          c.translate(x, y);
          c.rotate(math.sin(t * 1.6 + i) * 0.9 + i);
          final leaf = Path()
            ..moveTo(-7, 0)
            ..quadraticBezierTo(0, -6, 7, 0)
            ..quadraticBezierTo(0, 6, -7, 0)
            ..close();
          c.drawPath(leaf, Paint()..color = cols[i % cols.length].withValues(alpha: 0.92));
          c.drawLine(const Offset(-6, 0), const Offset(6, 0), Paint()
            ..color = const Color(0x55000000)
            ..strokeWidth = 0.8);
          c.restore();
        }
      case Effect.lucciole:
        for (var i = 0; i < 5; i++) {
          final o = Offset(
            100 + math.cos(t * 0.6 + i * 1.3) * (60 + i * 6),
            100 + math.sin(t * 0.8 + i * 2.1) * 44 - 20,
          );
          final a = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 3 + i));
          c.drawCircle(o, 6, Paint()..color = const Color(0xFFF3E28A).withValues(alpha: 0.18 * a));
          c.drawCircle(o, 2.6, Paint()..color = const Color(0xFFF7E9A0).withValues(alpha: a));
        }
      case Effect.note:
        for (var i = 0; i < 2; i++) {
          final p = ((t * 0.5 + i * 0.5) % 1.0);
          final o = Offset(160 + i * 10 + math.sin(t * 2 + i) * 4, 70 - p * 50);
          final col = const Color(0xFF9C86C9).withValues(alpha: (1 - p) * 0.9);
          c.drawOval(Rect.fromCenter(center: o, width: 8, height: 6), Paint()..color = col);
          c.drawLine(
            o + const Offset(3.6, 0),
            o + const Offset(3.6, -13),
            Paint()
              ..color = col
              ..strokeWidth = 2,
          );
          c.drawLine(
            o + const Offset(3.6, -13),
            o + const Offset(8.5, -10),
            Paint()
              ..color = col
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      case Effect.magia:
        for (var i = 0; i < 4; i++) {
          final ang = t * 1.4 + i * math.pi / 2;
          final o = Offset(100 + math.cos(ang) * 78, 100 + math.sin(ang) * 30 - 10);
          final k = 0.5 + 0.5 * math.sin(t * 3 + i);
          _sparkle(c, o, 2 + 2.4 * k,
              (i.isEven ? const Color(0xFFC6A8F2) : const Color(0xFFF6DB7A)).withValues(alpha: 0.5 + 0.5 * k));
        }
      case Effect.bolle:
        for (var i = 0; i < 4; i++) {
          final p = (t * 0.22 + i / 4) % 1.0;
          final o = Offset(30.0 + i * 46 + math.sin(t * 1.6 + i) * 6, 196 - p * 190);
          final r = 4.0 + (i % 3) * 2.5;
          final a = math.sin(p * math.pi);
          c.drawCircle(o, r, Paint()..color = const Color(0xFFBFE3F5).withValues(alpha: 0.35 * a));
          c.drawCircle(
            o,
            r,
            Paint()
              ..color = const Color(0xFF8FC3DE).withValues(alpha: 0.8 * a)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
          c.drawCircle(o + Offset(-r * 0.35, -r * 0.35), r * 0.25,
              Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a));
        }
      case Effect.neve:
        for (var i = 0; i < 7; i++) {
          final y = (t * 14 + i * 31) % 210 - 8;
          final x = 14.0 + i * 28 + math.sin(t * 0.9 + i) * 8;
          final r = 2.2 + (i % 3) * 0.8;
          c.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFFFFFFFF));
          c.drawCircle(
            Offset(x, y),
            r,
            Paint()
              ..color = const Color(0x5591A7C0)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        }
      case Effect.cuori:
        for (var i = 0; i < 3; i++) {
          final p = (t * 0.3 + i / 3) % 1.0;
          final o = Offset(150.0 + i * 8 + math.sin(t * 2 + i) * 6, 90 - p * 70);
          _heart(c, o, 6 + p * 3, const Color(0xFFF08BA8).withValues(alpha: math.sin(p * math.pi)));
        }
      case Effect.stelleCadenti:
        final p = (t % 4.0) / 1.2;
        if (p < 1) {
          final head = const Offset(20, 20) + Offset(160 * p, 50 * p);
          final tail = head - const Offset(34, 10.6);
          c.drawLine(
            tail,
            head,
            Paint()
              ..shader = ui.Gradient.linear(tail, head, [const Color(0x00F6DB7A), const Color(0xFFF6DB7A)])
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
          _sparkle(c, head, 3, const Color(0xFFFFF2C4));
        }
        const spots = [Offset(28, 150), Offset(172, 110), Offset(160, 30)];
        for (var i = 0; i < 3; i++) {
          final k = 0.5 + 0.5 * math.sin(t * 2.6 + i * 2);
          _sparkle(c, spots[i], 1.6 + 1.8 * k, const Color(0xFFF6DB7A).withValues(alpha: 0.3 + 0.7 * k));
        }
      case Effect.coriandoli:
        const cols = [Color(0xFFF2A7C3), Color(0xFF9DC7EA), Color(0xFFF6D46E), Color(0xFFA9D18E), Color(0xFFC6A8F2)];
        for (var i = 0; i < 8; i++) {
          final y = (t * 22 + i * 27) % 215 - 10;
          final x = 12.0 + i * 24 + math.sin(t * 1.4 + i) * 7;
          c.save();
          c.translate(x, y);
          c.rotate(t * 2 + i);
          c.drawRect(const Rect.fromLTWH(-3, -1.8, 6, 3.6), Paint()..color = cols[i % cols.length]);
          c.restore();
        }
      case Effect.fuochiFatui:
        for (var i = 0; i < 3; i++) {
          final ang = t * 0.8 + i * 2.1;
          final o = Offset(100 + math.cos(ang) * 82, 110 + math.sin(ang * 1.3) * 40 - 20);
          final a = 0.5 + 0.5 * math.sin(t * 2.2 + i);
          c.drawCircle(o, 9, Paint()..color = const Color(0xFF9FE3D0).withValues(alpha: 0.15 * a));
          c.drawCircle(o, 4.2, Paint()..color = const Color(0xFFBDF0E1).withValues(alpha: 0.85 * a));
        }
      case Effect.pioggia:
        // A small cloud of its own, drizzling beside the kitten.
        final cloudY = 14 + math.sin(t * 1.2) * 2;
        for (var i = 0; i < 4; i++) {
          final p = (t * 0.9 + i / 4) % 1.0;
          final o = Offset(148.0 + (i - 1.5) * 10, cloudY + 14 + p * 62);
          c.drawLine(o, o + const Offset(-1.5, 7), Paint()
            ..color = const Color(0xFF8FC3DE).withValues(alpha: 0.9 * (1 - p))
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round);
        }
        final cloud = Path()
          ..addOval(Rect.fromCircle(center: Offset(136, cloudY + 4), radius: 9))
          ..addOval(Rect.fromCircle(center: Offset(149, cloudY - 2), radius: 12))
          ..addOval(Rect.fromCircle(center: Offset(162, cloudY + 4), radius: 9))
          ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(128, cloudY, 170, cloudY + 13), const Radius.circular(6.5)));
        c.drawPath(cloud, Paint()
          ..color = const Color(0xFFB8C6D6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
        c.drawPath(cloud, Paint()..color = const Color(0xFFF4F7FB));
      case Effect.fulmini:
        const spots = [Offset(28, 58), Offset(172, 76), Offset(30, 140)];
        for (var i = 0; i < spots.length; i++) {
          final k = (t * 0.55 + i * 0.37) % 1.0;
          if (k > 0.22) continue;
          final a = math.sin(k / 0.22 * math.pi);
          final o = spots[i];
          final bolt = Path()
            ..moveTo(o.dx + 2, o.dy - 12)
            ..lineTo(o.dx - 5, o.dy + 1)
            ..lineTo(o.dx + 1, o.dy + 1)
            ..lineTo(o.dx - 3, o.dy + 13)
            ..lineTo(o.dx + 7, o.dy - 3)
            ..lineTo(o.dx + 1, o.dy - 3)
            ..lineTo(o.dx + 5, o.dy - 12)
            ..close();
          c.drawPath(bolt, Paint()..color = const Color(0xFFF6D46E).withValues(alpha: a));
          c.drawPath(bolt, Paint()
            ..color = const Color(0xFFD9A93A).withValues(alpha: a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeJoin = StrokeJoin.round);
        }
      case Effect.braci:
        for (var i = 0; i < 7; i++) {
          final p = (t * 0.28 + i / 7) % 1.0;
          final o = Offset(24.0 + i * 25 + math.sin(t * 1.8 + i * 1.3) * 8, 192 - p * 180);
          final a = math.sin(p * math.pi) * (0.6 + 0.4 * math.sin(t * 9 + i));
          final col = i.isEven ? const Color(0xFFF4A261) : const Color(0xFFF6D46E);
          c.drawCircle(o, 5.5, Paint()..color = col.withValues(alpha: 0.18 * a));
          c.drawCircle(o, 2.2 + (i % 3) * 0.6, Paint()..color = col.withValues(alpha: a));
        }
      default:
        break;
    }
  }

  void _zzz(Canvas c, double t, double x, double y) {
    for (var i = 0; i < 3; i++) {
      final p = ((t * 0.35 + i / 3) % 1.0);
      final s = 5 + i * 1.5 + p * 3;
      final o = Offset(x + 20 + p * 22 + i * 4, y - p * 34);
      final path = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(o.dx + s, o.dy)
        ..lineTo(o.dx, o.dy + s)
        ..lineTo(o.dx + s, o.dy + s);
      c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF8E7A8E).withValues(alpha: math.sin(p * math.pi) * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _heart(Canvas c, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy + r * 0.9)
      ..cubicTo(o.dx - r * 1.6, o.dy - r * 0.2, o.dx - r * 0.6, o.dy - r * 1.3, o.dx, o.dy - r * 0.4)
      ..cubicTo(o.dx + r * 0.6, o.dy - r * 1.3, o.dx + r * 1.6, o.dy - r * 0.2, o.dx, o.dy + r * 0.9)
      ..close();
    c.drawPath(p, Paint()..color = color);
  }

  /// Angel or dragon wings at the shoulders, flapping gently.
  void _wings(Canvas c, Accessory kind, Color color, Color outline, double ow, double t) {
    final flap = math.sin(t * 3) * 0.12;
    for (final side in const [-1.0, 1.0]) {
      c.save();
      c.translate(100 + side * 40, 128);
      c.rotate(side * (-0.25 + flap));
      c.scale(side, 1);
      final Path wing;
      if (kind == Accessory.ali) {
        wing = Path()
          ..moveTo(0, 0)
          ..cubicTo(18, -34, 52, -40, 64, -26)
          ..quadraticBezierTo(58, -18, 62, -12)
          ..quadraticBezierTo(50, -6, 52, 2)
          ..quadraticBezierTo(36, 4, 34, 12)
          ..quadraticBezierTo(16, 12, 0, 0)
          ..close();
      } else {
        wing = Path()
          ..moveTo(0, 0)
          ..lineTo(24, -40)
          ..lineTo(66, -34)
          ..quadraticBezierTo(56, -22, 60, -12)
          ..quadraticBezierTo(46, -14, 44, -2)
          ..quadraticBezierTo(30, -6, 26, 8)
          ..quadraticBezierTo(12, 6, 0, 0)
          ..close();
      }
      c.drawPath(
        wing,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = ow * 2
          ..strokeJoin = StrokeJoin.round,
      );
      c.drawPath(wing, Paint()..color = color);
      final vein = Paint()
        ..color = outline.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ow * 0.6
        ..strokeCap = StrokeCap.round;
      if (kind == Accessory.ali) {
        c.drawPath(Path()
          ..moveTo(14, -6)
          ..quadraticBezierTo(34, -18, 52, -22), vein);
        c.drawPath(Path()
          ..moveTo(12, 2)
          ..quadraticBezierTo(28, -4, 44, -6), vein);
      } else {
        c.drawLine(const Offset(4, -2), const Offset(24, -38), vein);
        c.drawLine(const Offset(6, 0), const Offset(58, -14), vein);
        c.drawLine(const Offset(5, 1), const Offset(42, -2), vein);
      }
      c.restore();
    }
  }

  /// Floor props of a scene, in body space: a bottle to knock over on the
  /// left, a ball of yarn rolling in from the right.
  void _floorProps(Canvas c, KittenAction act, double ap, double Function(double, double) ramp, Color outline) {
    final line = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    switch (act) {
      case KittenAction.bottiglia:
        final alpha = ramp(0, 0.1) * (1 - ramp(0.84, 1));
        final tip = Curves.bounceOut.transform(((ap - 0.36) / 0.22).clamp(0.0, 1.0));
        c.save();
        c.translate(26, 192);
        c.rotate(-tip * math.pi / 2);
        final body = RRect.fromRectAndRadius(const Rect.fromLTWH(0, -26, 14, 26), const Radius.circular(5));
        c.drawRRect(body, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha));
        c.drawRect(const Rect.fromLTWH(0, -16, 14, 6), Paint()..color = const Color(0xFF9DC7EA).withValues(alpha: alpha));
        c.drawRRect(body, line..color = outline.withValues(alpha: alpha));
        final cap = RRect.fromRectAndRadius(const Rect.fromLTWH(3, -32, 8, 6), const Radius.circular(2));
        c.drawRRect(cap, Paint()..color = const Color(0xFF7F93C9).withValues(alpha: alpha));
        c.drawRRect(cap, line);
        c.restore();
      case KittenAction.gomitolo:
        final double x;
        if (ap < 0.3) {
          x = 214 - 52 * Curves.easeOut.transform(ap / 0.3);
        } else if (ap < 0.44) {
          x = 162;
        } else {
          x = 162 + 56 * Curves.easeIn.transform(((ap - 0.44) / 0.4).clamp(0.0, 1.0));
        }
        final alpha = ramp(0, 0.1) * (1 - ramp(0.72, 0.86));
        c.save();
        c.translate(x, 181);
        c.rotate(x / 11);
        final ball = Rect.fromCircle(center: Offset.zero, radius: 11);
        c.drawOval(ball, Paint()..color = const Color(0xFFF29FB5).withValues(alpha: alpha));
        final thread = Paint()
          ..color = const Color(0xFFD9738F).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;
        c.drawArc(ball.deflate(3), 0.2, 2.4, false, thread);
        c.drawArc(ball.deflate(5), 3.4, 2.2, false, thread);
        c.drawLine(const Offset(-8, 4), const Offset(7, -6), thread);
        c.drawOval(ball, line..color = outline.withValues(alpha: alpha)..strokeWidth = 2.2);
        c.restore();
      default:
        break;
    }
  }

  /// Props of a scene that live around the head: a fly, a butterfly, a sneeze.
  void _headProps(
    Canvas c,
    KittenAction act,
    double ap,
    double Function(double, double) ramp,
    double Function(double, double) win,
    Color outline,
    double t,
  ) {
    final line = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    switch (act) {
      case KittenAction.mosca:
        final o = Offset(100 - math.cos(ap * math.pi * 2.2) * 92, 24 + math.sin(ap * math.pi * 6) * 12);
        final a = ramp(0, 0.1) * (1 - ramp(0.9, 1));
        final flap = math.sin(t * 60) * 0.5 + 0.5;
        final wing = Paint()..color = const Color(0xFFD9ECF7).withValues(alpha: 0.9 * a);
        c.drawOval(Rect.fromCenter(center: o + const Offset(-2, -3), width: 6, height: 4 + flap * 3), wing);
        c.drawOval(Rect.fromCenter(center: o + const Offset(2, -3), width: 6, height: 4 + flap * 3), wing);
        c.drawCircle(o, 3, Paint()..color = const Color(0xFF3B3236).withValues(alpha: a));
      case KittenAction.farfalla:
        final o = _butterfly(ap);
        final a = ramp(0, 0.08) * (1 - ramp(0.92, 1));
        final resting = ap > 0.3 && ap < 0.7;
        final flap = resting ? (math.sin(t * 4) * 0.5 + 0.5) * 0.6 + 0.2 : math.sin(t * 22) * 0.5 + 0.5;
        for (final side in const [-1.0, 1.0]) {
          c.save();
          c.translate(o.dx, o.dy);
          c.scale(side * (0.35 + 0.65 * flap), 1);
          final w = Path()
            ..addOval(Rect.fromCenter(center: const Offset(6, -4), width: 12, height: 10))
            ..addOval(Rect.fromCenter(center: const Offset(5, 5), width: 8, height: 8));
          c.drawPath(w, Paint()..color = const Color(0xFFF7B8CC).withValues(alpha: a));
          c.drawPath(w, line..color = outline.withValues(alpha: a)..strokeWidth = 1.6);
          c.restore();
        }
        c.drawLine(o + const Offset(0, -6), o + const Offset(0, 6), line..strokeWidth = 2.4);
      case KittenAction.starnuto:
        final puff = win(0.35, 0.8);
        if (puff > 0) {
          for (var i = 0; i < 3; i++) {
            final o = Offset(112 + i * 7 + puff * 10, 104 - i * 5 + (i == 1 ? 2 : 0));
            c.drawCircle(o, 2 + puff * 2.5, Paint()..color = const Color(0xFFE3EAF0).withValues(alpha: puff));
          }
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(KittenPainter old) =>
      old.skin != skin || old.pose != pose || old.growth != growth || old.anim != anim;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Butterfly flight in head space: flutters in, rests on the head, flies off.
Offset _butterfly(double p) {
  if (p < 0.3) {
    final k = p / 0.3;
    return Offset(_lerp(-30, 100, k), _lerp(10, 33, k) + math.sin(k * math.pi * 3) * 10);
  }
  if (p < 0.7) return const Offset(100, 33);
  final k = (p - 0.7) / 0.3;
  return Offset(_lerp(100, 230, k), _lerp(33, -20, k) + math.sin(k * math.pi * 3) * 8);
}

/// Pose layouts in design space (adult proportions).
class _Geo {
  const _Geo({
    required this.body,
    required this.bodyTop,
    required this.head,
    required this.headRot,
    required this.headScale,
    required this.paws,
    required this.tail,
    required this.tailBase,
    required this.belly,
  });

  final Path body;
  final double bodyTop;
  final Offset head;
  final double headRot;
  final double headScale;
  final List<Path> paws;
  final Path tail;
  final Offset tailBase;
  final Rect belly;

  static _Geo of(Pose pose) => switch (pose) {
    Pose.seduto => _sit,
    Pose.pagnotta => _loaf,
    Pose.dorme => _sleep,
  };

  static final _sit = _Geo(
    body: Path()
      ..moveTo(100, 100)
      ..cubicTo(138, 100, 158, 132, 156, 162)
      ..cubicTo(154, 186, 132, 192, 100, 192)
      ..cubicTo(68, 192, 46, 186, 44, 162)
      ..cubicTo(42, 132, 62, 100, 100, 100)
      ..close(),
    bodyTop: 100,
    head: const Offset(100, 86),
    headRot: 0,
    headScale: 1,
    paws: [
      Path()..addOval(Rect.fromCenter(center: const Offset(80, 187), width: 30, height: 18)),
      Path()..addOval(Rect.fromCenter(center: const Offset(120, 187), width: 30, height: 18)),
    ],
    tailBase: const Offset(148, 176),
    tail: Path()
      ..moveTo(148, 176)
      ..cubicTo(178, 180, 194, 156, 182, 126),
    belly: Rect.fromCenter(center: const Offset(100, 158), width: 60, height: 70),
  );

  static final _loaf = _Geo(
    body: Path()
      ..moveTo(100, 112)
      ..cubicTo(146, 112, 172, 140, 170, 170)
      ..cubicTo(169, 188, 156, 192, 138, 192)
      ..lineTo(62, 192)
      ..cubicTo(44, 192, 31, 188, 30, 170)
      ..cubicTo(28, 140, 54, 112, 100, 112)
      ..close(),
    bodyTop: 112,
    head: const Offset(100, 104),
    headRot: 0,
    headScale: 1,
    paws: [
      Path()..addOval(Rect.fromCenter(center: const Offset(84, 189), width: 22, height: 12)),
      Path()..addOval(Rect.fromCenter(center: const Offset(116, 189), width: 22, height: 12)),
    ],
    tailBase: const Offset(160, 180),
    tail: Path()
      ..moveTo(160, 180)
      ..cubicTo(184, 186, 180, 198, 150, 196),
    belly: Rect.fromCenter(center: const Offset(100, 176), width: 76, height: 36),
  );

  static final _sleep = _Geo(
    body: Path()
      ..addOval(Rect.fromCenter(center: const Offset(112, 156), width: 132, height: 64)),
    bodyTop: 124,
    head: const Offset(72, 132),
    headRot: -0.2,
    headScale: 0.84,
    paws: [
      Path()..addOval(Rect.fromCenter(center: const Offset(98, 182), width: 22, height: 12)),
    ],
    tailBase: const Offset(166, 162),
    tail: Path()
      ..moveTo(166, 162)
      ..cubicTo(180, 184, 134, 192, 90, 184),
    belly: Rect.fromCenter(center: const Offset(108, 176), width: 80, height: 20),
  );
}

/// Renders a still kitten to PNG bytes (notifications, share cards).
Future<Uint8List> renderKittenPng(
  Skin skin, {
  Pose? pose,
  double growth = 1,
  int size = 256,
  Color? background,
}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final sz = Size.square(size.toDouble());
  if (background != null) {
    canvas.drawRect(Offset.zero & sz, Paint()..color = background);
  }
  KittenPainter(skin: skin, pose: pose ?? skin.pose, growth: growth).paint(canvas, sz);
  final image = await rec.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
