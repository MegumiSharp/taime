// Dev tool: draws the app icon (a white kitten silhouette with empty eyes)
// and writes every Android size. Run: flutter test tool/make_icon_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sage background, a little lighter at the top.
const _bgTop = Color(0xFF94C9A5);
const _bgBottom = Color(0xFF6FAE88);

/// The silhouette in a 200×200 box: the same shapes as the kittens in the app.
void _kitten(Canvas c, Rect box, Color color) {
  final s = box.width / 200;
  c.saveLayer(box.inflate(box.width), Paint());
  c.translate(box.left, box.top);
  c.scale(s);
  final fill = Paint()..color = color;
  final round = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 8;

  // Tail, curling up on the right.
  c.drawPath(
    Path()
      ..moveTo(146, 178)
      ..cubicTo(178, 182, 196, 156, 182, 124),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 20,
  );
  // Body.
  final body = Path()
    ..moveTo(100, 100)
    ..cubicTo(138, 100, 158, 132, 156, 162)
    ..cubicTo(154, 188, 132, 194, 100, 194)
    ..cubicTo(68, 194, 46, 188, 44, 162)
    ..cubicTo(42, 132, 62, 100, 100, 100)
    ..close();
  c.drawPath(body, fill);
  // Ears, with softened tips.
  final ear = Path()
    ..moveTo(44, 72)
    ..lineTo(47, 30)
    ..quadraticBezierTo(49, 15, 62, 23)
    ..lineTo(90, 48)
    ..close();
  final mirror = Matrix4.identity()
    ..translateByDouble(200, 0, 0, 1)
    ..scaleByDouble(-1, 1, 1, 1);
  for (final e in [ear, ear.transform(mirror.storage)]) {
    c.drawPath(e, fill);
    c.drawPath(e, round);
  }
  // Head.
  final head = Path()
    ..moveTo(100, 38)
    ..cubicTo(141, 38, 164, 59, 164, 92)
    ..cubicTo(164, 121, 137, 136, 100, 136)
    ..cubicTo(63, 136, 36, 121, 36, 92)
    ..cubicTo(36, 59, 59, 38, 100, 38)
    ..close();
  c.drawPath(head, fill);

  // Empty spaces: eyes, a small nose, and a thin gap under the chin.
  final hole = Paint()..blendMode = BlendMode.clear;
  c.drawOval(Rect.fromCenter(center: const Offset(74, 94), width: 19, height: 23), hole);
  c.drawOval(Rect.fromCenter(center: const Offset(126, 94), width: 19, height: 23), hole);
  c.drawPath(
    Path()
      ..moveTo(93, 108)
      ..quadraticBezierTo(100, 104, 107, 108)
      ..quadraticBezierTo(100, 118, 93, 108)
      ..close(),
    hole,
  );
  c.drawPath(
    Path()
      ..moveTo(62, 131)
      ..quadraticBezierTo(100, 146, 138, 131),
    Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round,
  );
  c.restore();
}

Future<void> _png(String path, int size, void Function(Canvas, double) draw) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  draw(canvas, size.toDouble());
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _background(Canvas c, Rect r, {double radius = 0}) {
  final paint = Paint()
    ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [_bgTop, _bgBottom]);
  if (radius == 0) {
    c.drawRect(r, paint);
  } else {
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), paint);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app icon', () async {
    const res = 'android/app/src/main/res';
    const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
    for (final e in densities.entries) {
      // Legacy icon (Android 7): rounded square with the kitten.
      final legacy = (48 * e.value).round();
      await _png('$res/mipmap-${e.key}/ic_launcher.png', legacy, (c, s) {
        final r = Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92);
        _background(c, r, radius: s * 0.22);
        _kitten(c, Rect.fromCenter(center: Offset(s / 2, s * 0.5), width: s * 0.66, height: s * 0.66), Colors.white);
      });
      // Adaptive foreground (108 dp, safe zone 66 dp) and themed icon.
      final fg = (108 * e.value).round();
      await _png('$res/mipmap-${e.key}/ic_launcher_foreground.png', fg, (c, s) {
        _kitten(c, Rect.fromCenter(center: Offset(s / 2, s * 0.5), width: s * 0.54, height: s * 0.54), Colors.white);
      });
      // Status-bar icon: white on transparent, as Android wants.
      final small = (24 * e.value).round();
      await _png('packages/taime_native/android/src/main/res/drawable-${e.key}/ic_taime_notif.png', small, (c, s) {
        _kitten(c, Rect.fromLTWH(s * 0.02, s * 0.02, s * 0.96, s * 0.96), Colors.white);
      });
    }
    // A big preview for the README and for checking by eye.
    await _png('build/icon_preview.png', 512, (c, s) {
      _background(c, Offset.zero & Size(s, s), radius: s * 0.22);
      _kitten(c, Rect.fromCenter(center: Offset(s / 2, s * 0.5), width: s * 0.66, height: s * 0.66), Colors.white);
    });
  });
}
