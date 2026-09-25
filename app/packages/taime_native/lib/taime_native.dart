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

  /// Shows or refreshes the media-style focus notification.
  static Future<void> liveUpdate({
    required String title,
    required String subtitle,
    required bool paused,
    required int color,
    required int positionMs,
    required int durationMs,
    required int sinceMs,
    String? artPath,
  }) => _ch.invokeMethod('live.update', {
    'title': title,
    'subtitle': subtitle,
    'paused': paused,
    'color': color,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'sinceMs': sinceMs,
    'artPath': artPath,
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
}
