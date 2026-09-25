import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'skins.dart';

/// Everything that moves on a kitten, updated by `KittenView` every frame.
class KittenAnim extends ChangeNotifier {
  double t = 0; // seconds since start, drives effects
  double blink = 0; // 0 open .. 1 closed
  double breath = 0; // -1 .. 1
  double tail = 0; // -1 .. 1
  double ear = 0; // 0 .. 1 twitch
  double look = 0; // -1 .. 1
  double bump = 0; // growth "pop" 0 .. 1

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

    final geo = _Geo.of(pose);
    final sb = _lerp(0.64, 1.0, g);
    final sleeping = pose == Pose.dorme;
    final sbY = sb * (1 + (sleeping ? 0.03 : 0.018) * breath);
    final sh = _lerp(1.16, 1.0, g) * geo.headScale;
    final rise = 192 - geo.bodyTop;
    final headDy = rise * (1 - sb) - rise * sb * (sleeping ? 0.03 : 0.018) * breath * 0.9;

    final owBody = _ow / (overall * sb);
    final owHead = _ow / (overall * sh);

    final coat = skin.coat;
    final outline = coat.darkOutline ? _darkLine : _brown;
    final base = Color(coat.base);
    final second = Color(coat.second ?? coat.base);
    final third = Color(coat.third ?? coat.base);
    final darkCoat = base.computeLuminance() < 0.12;
    final featureLine = darkCoat ? const Color(0xFFE7D6CE) : outline;

    // Transforms --------------------------------------------------------------
    void bodyTf() {
      canvas.translate(100, 192);
      canvas.scale(sb, sbY);
      canvas.translate(-100, -192);
    }

    void headTf() {
      canvas.translate(geo.head.dx, geo.head.dy + headDy);
      canvas.rotate(geo.headRot);
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
        : (coat.pattern == CoatPattern.point ? second : base);
    final earColor = coat.pattern == CoatPattern.point ? second : base;
    final tailColor = switch (coat.pattern) {
      CoatPattern.point => second,
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
          if (skin.effect == Effect.codaArcobaleno) {
            _rainbowTail(canvas, tailPath, tailW);
          } else {
            canvas.drawPath(tailPath, stroke(tailColor, tailW));
            _tailPattern(canvas, tailPath, tailW, coat, second);
          }
        }
      });
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
      for (final p in paws) {
        canvas.drawPath(p, stroke(outline, owBody * 2));
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
      if (skin.effect == Effect.pittura) _paintDots(canvas, body, 0);
      if (skin.effect == Effect.stelle) _stars(canvas, body, t, 0);
      if (coat.whiteBelly && !sleeping) {
        canvas.save();
        canvas.clipPath(body);
        canvas.drawOval(geo.belly, fill(_white));
        canvas.restore();
      }
    });
    if (sleeping) drawTail(outlinePass: false, fillPass: true);
    withTf(bodyTf, () {
      for (final p in paws) {
        canvas.drawPath(p, fill(pawColor));
      }
      // Toe lines make paws read as paws.
      for (final p in paws) {
        final b = p.getBounds();
        if (b.width < 14) continue;
        final c = b.center;
        final toe = stroke(outline.withValues(alpha: 0.55), owBody * 0.55);
        canvas.drawLine(c + Offset(-3, b.height * 0.1), c + Offset(-3, b.height * 0.42), toe);
        canvas.drawLine(c + Offset(3, b.height * 0.1), c + Offset(3, b.height * 0.42), toe);
      }
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
          Rect.fromCenter(center: const Offset(100, 111), width: 52, height: 34),
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
      if (skin.effect == Effect.stelle) _stars(canvas, head, t, 1);
      canvas.restore();
    });

    // Chin line: where the head sits on the body.
    if (!sleeping) {
      withTf(headTf, () {
        canvas.save();
        final chin = Path()..addRect(const Rect.fromLTRB(20, 112, 180, 150));
        canvas.clipPath(chin);
        canvas.drawPath(head, stroke(outline, owHead * 1.05));
        canvas.restore();
      });
    }

    // Face --------------------------------------------------------------------
    withTf(headTf, () {
      final eyeScale = _lerp(1.18, 1.0, g);
      final dx = look * 2.4;
      const eyeY = 95.0;
      for (final ex in const [75.0, 125.0]) {
        final c = Offset(ex + dx, eyeY);
        if (sleeping) {
          _closedEye(canvas, c, featureLine, owHead);
        } else if (blink > 0.6) {
          final p = Path()
            ..moveTo(c.dx - 6.5, c.dy)
            ..quadraticBezierTo(c.dx, c.dy + 3.5, c.dx + 6.5, c.dy);
          canvas.drawPath(p, stroke(featureLine, owHead * 0.9));
        } else {
          final open = (1 - blink * 1.3).clamp(0.12, 1.0);
          if (skin.eyes != EyeStyle.puntini) {
            final r = 7.4 * eyeScale;
            canvas.drawOval(
              Rect.fromCenter(center: c, width: r * 2, height: r * 2 * open),
              fill(skin.eyes == EyeStyle.dorati ? const Color(0xFFF0CD6A) : const Color(0xFFA9CFEF)),
            );
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
              fill(darkCoat ? const Color(0xFF1E1718) : _eye),
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
      canvas.drawPath(mouth, stroke(featureLine, owHead * 0.8));

      _accessory(canvas, skin.accessory, Color(skin.accessoryColor), outline, owHead, t);
      if (skin.accessory2 != Accessory.mantello) {
        _accessory(canvas, skin.accessory2, Color(skin.accessory2Color), outline, owHead, t);
      } else {
        canvas.drawCircle(const Offset(100, 128), 5.5, fill(_gold));
        canvas.drawCircle(const Offset(100, 128), 5.5, stroke(outline, owHead * 0.7));
      }
    });

    _frontEffect(canvas, t);
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
    switch (coat.pattern) {
      case CoatPattern.tigrato:
        final s = Paint()
          ..color = second
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(90, 47), const Offset(92.5, 60), s);
        c.drawLine(const Offset(100, 45), const Offset(100, 61), s);
        c.drawLine(const Offset(110, 47), const Offset(107.5, 60), s);
        for (final (a, b) in const [
          (Offset(38, 90), Offset(52, 92)),
          (Offset(39, 101), Offset(51, 100.5)),
          (Offset(162, 90), Offset(148, 92)),
          (Offset(161, 101), Offset(149, 100.5)),
        ]) {
          c.drawLine(a, b, s);
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
      case CoatPattern.tintaUnita:
        break;
    }
    c.restore();
  }

  void _tailPattern(Canvas c, Path tail, double w, Coat coat, Color second) {
    final metric = tail.computeMetrics().firstOrNull;
    if (metric == null) return;
    if (coat.pattern == CoatPattern.tigrato) {
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

  // --- Accessories (head space) -----------------------------------------------

  void _accessory(Canvas c, Accessory acc, Color color, Color outline, double ow, double t) {
    final line = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = ow * 0.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final f = Paint()..color = color;
    void both(Path p) {
      c.drawPath(p, f);
      c.drawPath(p, line);
    }

    switch (acc) {
      case Accessory.nessuno:
      case Accessory.mantello:
        return;
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
        final band = Path()
          ..moveTo(54, 117)
          ..quadraticBezierTo(100, 142, 146, 117)
          ..lineTo(148, 130)
          ..quadraticBezierTo(100, 158, 52, 130)
          ..close();
        final flutter = skin.effect == Effect.sciarpaVento ? math.sin(t * 3.2) * 0.22 : 0.0;
        c.save();
        c.translate(128, 132);
        c.rotate(0.12 + flutter);
        final end = Path()
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -2, 15, 34), const Radius.circular(5)));
        both(end);
        final fringe = Paint()
          ..color = outline
          ..strokeWidth = ow * 0.55
          ..strokeCap = StrokeCap.round;
        for (final x in const [-3.0, 0.5, 4.0]) {
          c.drawLine(Offset(x, 32), Offset(x, 37), fringe);
        }
        c.restore();
        both(band);
        final stripe = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        c.drawPath(
          Path()
            ..moveTo(58, 124)
            ..quadraticBezierTo(100, 148, 142, 124),
          stripe,
        );
      case Accessory.campanella:
        c.drawPath(
          Path()
            ..moveTo(60, 121)
            ..quadraticBezierTo(100, 141, 140, 121),
          Paint()
            ..color = outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8 + ow
            ..strokeCap = StrokeCap.round,
        );
        c.drawPath(
          Path()
            ..moveTo(60, 121)
            ..quadraticBezierTo(100, 141, 140, 121),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round,
        );
        final bell = Path()..addOval(Rect.fromCircle(center: const Offset(100, 138), radius: 8));
        c.drawPath(bell, Paint()..color = _gold);
        c.drawPath(bell, line);
        c.drawLine(const Offset(100, 140), const Offset(100, 145), line);
        c.drawCircle(const Offset(97.5, 135.5), 1.8, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8));
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
        final hat = Path()
          ..moveTo(50, 70)
          ..cubicTo(48, 28, 152, 28, 150, 70)
          ..close();
        both(hat);
        both(Path()
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(46, 62, 154, 76), const Radius.circular(7))));
        final rib = Paint()
          ..color = outline.withValues(alpha: 0.35)
          ..strokeWidth = 1.6;
        for (var x = 58.0; x < 150; x += 10) {
          c.drawLine(Offset(x, 64.5), Offset(x, 73.5), rib);
        }
        both(Path()..addOval(Rect.fromCircle(center: const Offset(100, 32), radius: 9)));
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
        c.drawPath(crown, Paint()..color = color);
        c.drawPath(crown, line);
        c.drawCircle(const Offset(100, 42), 3, Paint()..color = const Color(0xFFE88AA6));
        c.drawCircle(const Offset(88, 44), 2.2, Paint()..color = const Color(0xFF9DC7EA));
        c.drawCircle(const Offset(112, 44), 2.2, Paint()..color = const Color(0xFF9DC7EA));
      case Accessory.lunaFermaglio:
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: const Offset(138, 52), radius: 11)),
          Path()..addOval(Rect.fromCircle(center: const Offset(144, 47), radius: 9.5)),
        );
        c.drawPath(moon, Paint()..color = color);
        c.drawPath(moon, line);
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
          c.drawPath(leaf, Paint()..color = i.isEven ? color : Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!);
          c.drawPath(leaf, line);
          c.restore();
        }
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

  void _frontEffect(Canvas c, double t) {
    switch (skin.effect) {
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

  @override
  bool shouldRepaint(KittenPainter old) =>
      old.skin != skin || old.pose != pose || old.growth != growth || old.anim != anim;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

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
