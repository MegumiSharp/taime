import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'painter.dart';
import 'skins.dart';

/// Kitten pictures for the native notification, rendered once per skin by the
/// UI isolate so background code only has to look a file up.
Future<Directory> _dir() async {
  final base = await getApplicationSupportDirectory();
  final d = Directory('${base.path}/kitten_art');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

String _name(String skinId, int stage, bool sleeping) =>
    '${skinId}_${sleeping ? 'sleep' : stage}_v1.png';

Future<String?> kittenArtPath(String skinId, int stage, {bool sleeping = false}) async {
  try {
    final f = File('${(await _dir()).path}/${_name(skinId, stage, sleeping)}');
    return f.existsSync() ? f.path : null;
  } catch (_) {
    return null;
  }
}

/// Forgets the pictures of [skinId] (a kitten you made was changed).
Future<void> clearKittenArt(String skinId) async {
  try {
    for (final f in (await _dir()).listSync().whereType<File>()) {
      if (f.uri.pathSegments.last.startsWith('${skinId}_')) f.deleteSync();
    }
  } catch (_) {}
}

/// Renders the 5 growth stages and the sleeping pose if missing.
Future<void> ensureKittenArt(String skinId) async {
  final dir = await _dir();
  final skin = skinById(skinId);
  for (var stage = 0; stage <= 5; stage++) {
    final sleeping = stage == 5;
    final f = File('${dir.path}/${_name(skinId, stage, sleeping)}');
    if (f.existsSync()) continue;
    final bytes = await renderKittenPng(
      skin,
      pose: sleeping ? Pose.dorme : Pose.seduto,
      growth: sleeping ? 1 : kStageMinutes[stage] / 60,
      size: 320,
    );
    await f.writeAsBytes(bytes);
  }
}
