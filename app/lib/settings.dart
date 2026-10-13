import 'palette.dart';

/// Typed view over the key/value `prefs` table.
class Settings {
  const Settings(this._m);
  final Map<String, String> _m;

  static const empty = Settings({});

  int _int(String k, int d) => int.tryParse(_m[k] ?? '') ?? d;
  bool _bool(String k, bool d) => (_m[k] ?? (d ? '1' : '0')) == '1';

  /// 'light' | 'dark' | 'system'
  String get themeMode => _m['themeMode'] ?? 'light';

  /// 'salvia' | 'lavanda' | 'azzurro' | 'custom'
  String get theme => _m['theme'] ?? 'salvia';

  /// Only used by the 'custom' theme.
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

  /// Minutes of focus to aim for each day. 0 = off.
  int get dailyGoalMin => _int('dailyGoalMin', 120);

  bool get autoBackup => _bool('autoBackup', true);
  String get lastAutoBackup => _m['lastAutoBackup'] ?? '';

  int get lastActivityId => _int('lastActivityId', 0);

  String get activeSkin => _m['activeSkin'] ?? 'biscotto';

  /// 'bundled' | 'system' | 'file'
  String get soundKind => _m['soundKind'] ?? 'bundled';

  /// Bundled sound id, or a content/file uri.
  String get soundValue => _m['soundValue'] ?? 'campanella';
  String get soundName => _m['soundName'] ?? 'Campanella';

  /// Ring until touched (max 1 minute) instead of once.
  bool get soundLoop => _bool('soundLoop', false);
  bool get soundVibrate => _bool('soundVibrate', true);

  // --- Bevi acqua -------------------------------------------------------------

  /// The glasses chip in Focus and the reminders.
  bool get waterOn => _bool('waterOn', false);

  /// 'always' = every [waterEvery] minutes within the hours and days,
  /// 'focus' = every [waterEvery] minutes of a running session (pauses too).
  String get waterMode => _m['waterMode'] ?? 'always';
  int get waterEvery => _int('waterEvery', 60);

  /// Minutes from midnight; [waterTo] before [waterFrom] goes past midnight.
  int get waterFrom => _int('waterFrom', 9 * 60);
  int get waterTo => _int('waterTo', 21 * 60);

  /// Weekdays on (1 = Monday … 7 = Sunday).
  Set<int> get waterDays => {
    for (final c in (_m['waterDays'] ?? '1234567').split('')) ?int.tryParse(c),
  };

  int get waterGoal => _int('waterGoal', 8);

  /// One glass, in ml.
  int get waterGlass => _int('waterGlass', 250);
  int get waterSnooze => _int('waterSnooze', 15);
  String get waterText => _m['waterText'] ?? '';

  /// 'default' | a bundled sound id | 'vibrate' | 'silent'
  String get waterSound => _m['waterSound'] ?? 'default';

  /// The last glass: the next reminder counts from here.
  DateTime? get waterLast => DateTime.tryParse(_m['waterLast'] ?? '');

  /// Glasses drunk on [day].
  int waterCount(DateTime day) => _int(waterKey(day), 0);
}

String waterKey(DateTime d) =>
    'water.${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
