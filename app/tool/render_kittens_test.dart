// Dev tool: renders kitten contact sheets to PNG for visual review.
// Run: flutter test tool/render_kittens_test.dart  (writes to build/kittens/)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/kitten/painter.dart';
import 'package:time_tracker/kitten/skins.dart';

Future<void> _sheet(
  String name,
  List<({Skin skin, Pose pose, double growth, KittenAnim? anim})> cells, {
  int cols = 6,
  double cell = 220,
}) async {
  final rows = (cells.length / cols).ceil();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final size = Size(cols * cell, rows * cell);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEFF4EE));
  for (var i = 0; i < cells.length; i++) {
    final c = cells[i];
    canvas.save();
    canvas.translate((i % cols) * cell, (i ~/ cols) * cell);
    KittenPainter(skin: c.skin, pose: c.pose, growth: c.growth, anim: c.anim)
        .paint(canvas, Size.square(cell));
    canvas.restore();
  }
  final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  Directory('build/kittens').createSync(recursive: true);
  File('build/kittens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render sheets', () async {
    await _sheet('all_skins', [
      for (final s in kSkins) (skin: s, pose: s.pose, growth: 1.0, anim: KittenAnim()..t = 1.3),
    ], cols: 8);
    KittenAnim act(KittenAction a, double p) => KittenAnim()
      ..action = a
      ..actionT = p
      ..t = 2;
    await _sheet('actions', [
      for (final (a, p) in const [
        (KittenAction.mosca, 0.3),
        (KittenAction.bottiglia, 0.1),
        (KittenAction.bottiglia, 0.3),
        (KittenAction.bottiglia, 0.4),
        (KittenAction.bottiglia, 0.6),
        (KittenAction.bottiglia, 0.8),
        (KittenAction.sbadiglio, 0.5),
        (KittenAction.farfalla, 0.15),
        (KittenAction.farfalla, 0.5),
        (KittenAction.gomitolo, 0.2),
        (KittenAction.gomitolo, 0.42),
        (KittenAction.gomitolo, 0.6),
        (KittenAction.starnuto, 0.5),
        (KittenAction.starnuto, 0.8),
      ])
        (skin: kSkins.first, pose: Pose.seduto, growth: 1.0, anim: act(a, p)),
    ], cols: 5);
    await _sheet('detail', [
      for (final id in const ['biscotto', 'brioche', 'nocciola', 'diavoletto', 'astronauta', 'zenzero', 'wendy', 'minou', 'panda'])
        (skin: kSkinById[id]!, pose: kSkinById[id]!.pose, growth: 1.0, anim: null),
    ], cols: 3, cell: 420);
    final demo = kSkins.first;
    await _sheet('growth_poses', [
      for (final p in Pose.values)
        for (final g in const [0.0, 0.17, 0.42, 0.75, 1.0])
          (skin: demo, pose: p, growth: g, anim: null),
    ], cols: 5);
    final blink = KittenAnim()
      ..blink = 1
      ..ear = 1
      ..tail = 1;
    await _sheet('anim', [
      (skin: demo, pose: Pose.seduto, growth: 1.0, anim: blink),
      (skin: kSkinById['ombra']!, pose: Pose.seduto, growth: 1.0, anim: null),
      (skin: kSkinById['notte']!, pose: Pose.dorme, growth: 1.0, anim: null),
      (skin: kSkinById['pezzetta']!, pose: Pose.pagnotta, growth: 1.0, anim: null),
    ], cols: 4, cell: 300);
  });
}
