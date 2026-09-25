import 'palette.dart';

/// Typed view over the key/value `prefs` table.
class Settings {
  const Settings(this._m);
  final Map<String, String> _m;

  static const empty = Settings({});

  int _int(String k, int d) => int.tryParse(_m[k] ?? '') ?? d;
  bool _bool(String k, bool d) => (_m[k] ?? (d ? '1' : '0')) == '1';

  /// 'system' | 'dark' | 'light'
  String get themeMode => _m['themeMode'] ?? 'dark';

  List<int> get palette {
    final p = parsePalette(_m['palette'] ?? '');
    return p.isEmpty ? defaultPalette : p;
  }

  /// Minutes of continuous work before the break reminder. 0 = off.
  int get breakAfterMin => _int('breakAfterMin', 120);

  /// 'notify' = only a heads-up, 'auto' = stop work and start the pause.
  String get breakMode => _m['breakMode'] ?? 'notify';

  /// Minutes of pause before the "back to work" reminder. 0 = off.
  int get pauseReminderMin => _int('pauseReminderMin', 15);

  bool get pomodoro => _bool('pomodoro', false);
  int get pomoWorkMin => _int('pomoWorkMin', 25);
  int get pomoBreakMin => _int('pomoBreakMin', 5);
  int get pomoLongBreakMin => _int('pomoLongBreakMin', 15);
  int get pomoEvery => _int('pomoEvery', 4);

  /// 1 = Monday, 7 = Sunday.
  int get weekStart => _int('weekStart', 1);

  int get lastActivityId => _int('lastActivityId', 0);
}
