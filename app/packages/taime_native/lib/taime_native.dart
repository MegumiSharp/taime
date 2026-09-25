import 'package:flutter/services.dart';

/// Dart side of Taime's native plugin (see TaimeNativePlugin.kt).
abstract final class TaimeNative {
  static const _ch = MethodChannel('taime_native');

  /// Marks this engine as the UI one: notification buttons are delivered to
  /// [onAction] instead of booting a background engine.
  static Future<void> registerUi(Future<void> Function(String action) onAction) async {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'action') await onAction(call.arguments as String);
    });
    await _ch.invokeMethod('registerUi');
  }

  /// Shows or refreshes the focus notification. The native side keeps it up
  /// to date by itself (every 30 s) from these numbers.
  static Future<void> liveUpdate({
    required String title,
    required bool paused,
    required bool pomodoro,
    required int color,
    required int workedMs,
    required int stampMs,
    required int pauseStartMs,
    required int segmentStartMs,
    required int pomoMs,
    required int deadlineMs,
    required List<String?> art,
    required List<String> stageNames,
    required List<int> stageMinutes,
  }) => _ch.invokeMethod('live.update', {
    'title': title,
    'paused': paused,
    'pomodoro': pomodoro,
    'color': color,
    'workedMs': workedMs,
    'stampMs': stampMs,
    'pauseStartMs': pauseStartMs,
    'segmentStartMs': segmentStartMs,
    'pomoMs': pomoMs,
    'deadlineMs': deadlineMs,
    'art': art,
    'stageNames': stageNames,
    'stageMinutes': stageMinutes,
  });

  static Future<void> liveStop() => _ch.invokeMethod('live.stop');

  /// Tells the native side a background engine finished its work.
  static Future<void> backgroundDone() => _ch.invokeMethod('bg.done');

  static Future<int> sdkInt() async => await _ch.invokeMethod<int>('sdk') ?? 0;

  /// System sound picker. Returns (uri, title) or null if cancelled.
  static Future<({String uri, String title})?> pickSystemSound(String? current) async {
    final r = await _ch.invokeMapMethod<String, dynamic>('sound.pickSystem', {'current': current});
    if (r == null) return null;
    return (uri: r['uri'] as String, title: r['title'] as String);
  }

  /// content:// uri for a file inside `files/sounds/`, readable by the system.
  static Future<String> shareableUri(String path) async =>
      (await _ch.invokeMethod<String>('sound.shareableUri', path))!;

  /// Plays a sound on the alarm stream for a few seconds.
  static Future<void> previewSound(String kind, String value) =>
      _ch.invokeMethod('sound.preview', {'kind': kind, 'value': value});

  static Future<void> stopPreview() => _ch.invokeMethod('sound.stop');

  /// Writes a backup into Download/Taime, keeping the newest 4 automatic ones.
  static Future<void> saveBackup(String name, List<int> bytes) =>
      _ch.invokeMethod('backup.save', {'name': name, 'bytes': Uint8List.fromList(bytes)});

  /// Home-screen widget contents.
  static Future<void> widgetUpdate({
    required bool running,
    required bool paused,
    required String title,
    required String subtitle,
    required int sinceMs,
    String? artPath,
  }) => _ch.invokeMethod('widget.update', {
    'running': running,
    'paused': paused,
    'title': title,
    'subtitle': subtitle,
    'sinceMs': sinceMs,
    'artPath': artPath,
  });
}
