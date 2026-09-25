import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../theme.dart';
import '../ui/motion.dart';

/// One tile of the pen: a day (or a month in the year view).
class PenTile {
  const PenTile({
    required this.col,
    required this.row,
    required this.minutes,
    required this.cats,
    required this.seed,
    this.label,
    this.payload,
    this.today = false,
  });

  final int col, row;
  final double minutes;
  final List<PenCat> cats;
  final int seed;
  final String? label;
  final Object? payload;
  final bool today;
}

/// Isometric fenced field. Tiles get greener with minutes worked; the cats
/// earned that day sit on them. Positions come from each tile's seed, so they
/// never reshuffle.
class PenView extends StatelessWidget {
  const PenView({
    super.key,
    required this.cols,
    required this.rows,
    required this.tiles,
    this.maxCatsPerTile = 3,
    this.animateCats = false,
    this.onTap,
    this.catScale = 0.62,
  });

  final int cols, rows;
  final List<PenTile> tiles;
  final int maxCatsPerTile;
  final bool animateCats;
  final ValueChanged<PenTile>? onTap;

  /// Cat size relative to the tile width.
  final double catScale;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return LayoutBuilder(
      builder: (context, box) {
        final geo = _PenGeo(cols: cols, rows: rows, width: box.maxWidth);
        final maxMinutes = tiles.fold(0.0, (a, t) => math.max(a, t.minutes));
        final catSize = geo.tw * catScale;

        // Cats sorted back-to-front so nearer ones overlap farther ones.
        final placed = <({Offset at, PenCat cat, int order})>[];
        final extra = <({Offset at, int n})>[];
        for (final t in tiles) {
          final shown = t.cats.take(maxCatsPerTile).toList();
          final rnd = math.Random(t.seed);
          for (var i = 0; i < shown.length; i++) {
            final u = shown.length == 1 ? 0.5 : 0.22 + rnd.nextDouble() * 0.56;
            final v = shown.length == 1 ? 0.5 : 0.22 + rnd.nextDouble() * 0.56;
            placed.add((at: geo.pointOn(t.col, t.row, u, v), cat: shown[i], order: t.col + t.row));
          }
          if (t.cats.length > shown.length) {
            extra.add((at: geo.pointOn(t.col, t.row, 0.85, 0.2), n: t.cats.length - shown.length));
          }
        }
        placed.sort((a, b) => a.at.dy.compareTo(b.at.dy));

        return GestureDetector(
          onTapUp: onTap == null
              ? null
              : (d) {
                  final cell = geo.cellAt(d.localPosition);
                  if (cell == null) return;
                  final hit = tiles.where((t) => t.col == cell.$1 && t.row == cell.$2).firstOrNull;
                  if (hit != null) {
                    Haptic.select();
                    onTap!(hit);
                  }
                },
          child: SizedBox(
            width: box.maxWidth,
            height: geo.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(box.maxWidth, geo.height),
                  painter: _PenPainter(
                    geo: geo,
                    tiles: tiles,
                    maxMinutes: maxMinutes,
                    grass: tc.grass,
                    grassRich: tc.grassRich,
                    earth: tc.earth,
                    labelColor: tc.text.withValues(alpha: 0.45),
                    todayColor: tc.accent,
                    back: true,
                  ),
                ),
                for (var i = 0; i < placed.length; i++)
                  Positioned(
                    left: placed[i].at.dx - catSize / 2,
                    top: placed[i].at.dy - catSize * 0.93,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Motion.of(context, Duration(milliseconds: 350 + (i % 20) * 30)),
                      curve: Motion.spring,
                      builder: (context, a, child) => Transform.scale(
                        scale: a,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                      child: KittenView(
                        skin: skinById(placed[i].cat.skinId),
                        pose: _poseFor(placed[i].cat),
                        growth: placed[i].cat.growth,
                        size: catSize,
                        animate: animateCats,
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: CustomPaint(
                    size: Size(box.maxWidth, geo.height),
                    painter: _PenPainter(
                      geo: geo,
                      tiles: tiles,
                      maxMinutes: maxMinutes,
                      grass: tc.grass,
                      grassRich: tc.grassRich,
                      earth: tc.earth,
                      labelColor: tc.text,
                      todayColor: tc.accent,
                      back: false,
                    ),
                  ),
                ),
                for (final e in extra)
                  Positioned(
                    left: e.at.dx - 14,
                    top: e.at.dy - 26,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tc.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+${e.n}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tc.text),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Most cats sit; some loaf, so a busy pen looks alive.
  Pose _poseFor(PenCat c) => c.seed % 3 == 0 ? Pose.pagnotta : skinById(c.skinId).pose;
}

class _PenGeo {
  _PenGeo({required this.cols, required this.rows, required double width}) {
    const margin = 14.0;
    tw = (width - margin * 2) / ((cols + rows) / 2);
    th = tw / 2;
    depth = th * 0.34;
    originX = margin + rows * tw / 2;
    originY = tw * 0.62 + 8; // headroom for cats on the back row
    height = originY + (cols + rows) * th / 2 + depth + 14;
  }

  final int cols, rows;
  late final double tw, th, depth, originX, originY, height;

  Offset top(int c, int r) => Offset(originX + (c - r) * tw / 2, originY + (c + r) * th / 2);

  /// Point inside tile (c, r): u along its right edge, v along its left edge.
  Offset pointOn(int c, int r, double u, double v) {
    final t = top(c, r);
    return t + Offset(tw / 2, th / 2) * u + Offset(-tw / 2, th / 2) * v;
  }

  (int, int)? cellAt(Offset p) {
    final x = (p.dx - originX) / (tw / 2);
    final y = (p.dy - originY) / (th / 2);
    final c = ((y + x) / 2).floor();
    final r = ((y - x) / 2).floor();
    if (c < 0 || r < 0 || c >= cols || r >= rows) return null;
    return (c, r);
  }
}

class _PenPainter extends CustomPainter {
  _PenPainter({
    required this.geo,
    required this.tiles,
    required this.maxMinutes,
    required this.grass,
    required this.grassRich,
    required this.earth,
    required this.labelColor,
    required this.todayColor,
    required this.back,
  });

  final _PenGeo geo;
  final List<PenTile> tiles;
  final double maxMinutes;
  final Color grass, grassRich, earth, labelColor, todayColor;

  /// Back pass: ground and far fence. Front pass: near fence and labels.
  final bool back;

  static const _wood = Color(0xFFE2C4A2);
  static const _woodLine = Color(0xFF9A7458);

  @override
  void paint(Canvas canvas, Size size) {
    if (back) {
      _fence(canvas, front: false);
      final sorted = [...tiles]..sort((a, b) => (a.col + a.row).compareTo(b.col + b.row));
      for (final t in sorted) {
        _tile(canvas, t);
      }
    } else {
      _fence(canvas, front: true);
      for (final t in tiles) {
        if (t.label == null) continue;
        final p = geo.pointOn(t.col, t.row, 0.08, 0.5);
        final tp = TextPainter(
          text: TextSpan(
            text: t.label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: math.max(9, geo.tw * 0.14),
              fontWeight: t.today ? FontWeight.w900 : FontWeight.w700,
              color: t.today ? todayColor : labelColor.withValues(alpha: 0.55),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height * 0.2));
      }
    }
  }

  void _tile(Canvas canvas, PenTile t) {
    final T = geo.top(t.col, t.row);
    final R = T + Offset(geo.tw / 2, geo.th / 2);
    final B = T + Offset(0, geo.th);
    final L = T + Offset(-geo.tw / 2, geo.th / 2);
    final d = Offset(0, geo.depth);
    final k = maxMinutes <= 0 ? 0.0 : math.sqrt(t.minutes / maxMinutes);
    final top = t.minutes <= 0 ? grass : Color.lerp(grass, grassRich, 0.25 + 0.75 * k)!;

    final left = Path()
      ..moveTo(L.dx, L.dy)
      ..lineTo(B.dx, B.dy)
      ..lineTo(B.dx, B.dy + d.dy)
      ..lineTo(L.dx, L.dy + d.dy)
      ..close();
    final right = Path()
      ..moveTo(B.dx, B.dy)
      ..lineTo(R.dx, R.dy)
      ..lineTo(R.dx, R.dy + d.dy)
      ..lineTo(B.dx, B.dy + d.dy)
      ..close();
    final face = Path()
      ..moveTo(T.dx, T.dy)
      ..lineTo(R.dx, R.dy)
      ..lineTo(B.dx, B.dy)
      ..lineTo(L.dx, L.dy)
      ..close();

    canvas.drawPath(left, Paint()..color = earth);
    canvas.drawPath(right, Paint()..color = Color.lerp(earth, Colors.black, 0.1)!);
    canvas.drawPath(face, Paint()..color = top);
    canvas.drawPath(
      face,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // A few grass tufts, more on busy days.
    final rnd = math.Random(t.seed * 7 + 3);
    final tufts = 2 + (k * 4).round();
    final tuft = Paint()
      ..color = Color.lerp(top, Colors.black, 0.12)!
      ..strokeWidth = math.max(1, geo.tw * 0.018)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < tufts; i++) {
      final p = geo.pointOn(t.col, t.row, 0.15 + rnd.nextDouble() * 0.7, 0.15 + rnd.nextDouble() * 0.7);
      final h = geo.th * 0.12;
      canvas.drawLine(p, p + Offset(-h * 0.4, -h), tuft);
      canvas.drawLine(p, p + Offset(h * 0.4, -h * 0.9), tuft);
    }
    if (t.today) {
      canvas.drawPath(
        face,
        Paint()
          ..color = todayColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// Wooden fence around the whole field: the two far edges in the back
  /// pass, the two near edges (lower) in front.
  void _fence(Canvas canvas, {required bool front}) {
    final c = geo.cols, r = geo.rows;
    final tl = geo.top(0, 0);
    final tr = geo.top(c, 0);
    final bl = geo.top(0, r);
    final br = geo.top(c, r);
    final h = geo.th * (front ? 0.42 : 0.62);
    final edges = front ? [(bl, br, c), (tr, br, r)] : [(tl, tr, c), (tl, bl, r)];
    final rail = Paint()
      ..color = _woodLine
      ..strokeWidth = math.max(2.5, geo.tw * 0.05)
      ..strokeCap = StrokeCap.round;
    final railFill = Paint()
      ..color = _wood
      ..strokeWidth = math.max(1.4, geo.tw * 0.03)
      ..strokeCap = StrokeCap.round;
    for (final (a, b, n) in edges) {
      final steps = math.max(1, n);
      for (final y in [h * 0.35, h * 0.8]) {
        canvas.drawLine(a - Offset(0, y), b - Offset(0, y), rail);
        canvas.drawLine(a - Offset(0, y), b - Offset(0, y), railFill);
      }
      for (var i = 0; i <= steps; i++) {
        final p = Offset.lerp(a, b, i / steps)!;
        final post = RRect.fromRectAndRadius(
          Rect.fromLTWH(p.dx - geo.tw * 0.035, p.dy - h, geo.tw * 0.07, h + geo.depth * 0.3),
          Radius.circular(geo.tw * 0.03),
        );
        canvas.drawRRect(post, Paint()..color = _woodLine);
        canvas.drawRRect(post.deflate(math.max(0.8, geo.tw * 0.012)), Paint()..color = _wood);
      }
    }
  }

  @override
  bool shouldRepaint(_PenPainter old) =>
      old.tiles != tiles || old.grass != grass || old.back != back || old.maxMinutes != maxMinutes;
}
