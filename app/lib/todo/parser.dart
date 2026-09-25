import 'recurrence.dart';

/// Quick-add parsing in Italian, Todoist style: dates, times, recurrences,
/// priorities and #categories are recognised in the text, highlighted while
/// typing, and removed from the title.
enum TokenKind { date, time, recurrence, priority, category }

class ParsedToken {
  const ParsedToken(this.kind, this.start, this.end, this.text);
  final TokenKind kind;
  final int start, end;
  final String text;

  /// Identity used to switch a recognition off by tapping it.
  String get key => '${kind.name}:${text.toLowerCase()}';
}

class ParsedTask {
  const ParsedTask({
    required this.title,
    required this.tokens,
    this.date,
    this.hour,
    this.minute,
    this.priority,
    this.category,
    this.recurrence,
  });

  final String title;
  final List<ParsedToken> tokens;
  final DateTime? date;
  final int? hour, minute;
  final int? priority;
  final String? category;
  final String? recurrence;

  bool get hasTime => hour != null;
  DateTime? get due =>
      date == null ? null : DateTime(date!.year, date!.month, date!.day, hour ?? 0, minute ?? 0);
}

const _weekdays = {
  'lunedì': 1, 'lunedi': 1, 'lun': 1,
  'martedì': 2, 'martedi': 2, 'mar': 2,
  'mercoledì': 3, 'mercoledi': 3, 'mer': 3,
  'giovedì': 4, 'giovedi': 4, 'gio': 4,
  'venerdì': 5, 'venerdi': 5, 'ven': 5,
  'sabato': 6, 'sab': 6,
  'domenica': 7, 'dom': 7,
};

const _months = {
  'gennaio': 1, 'gen': 1, 'febbraio': 2, 'feb': 2, 'marzo': 3, 'aprile': 4, 'apr': 4,
  'maggio': 5, 'mag': 5, 'giugno': 6, 'giu': 6, 'luglio': 7, 'lug': 7, 'agosto': 8, 'ago': 8,
  'settembre': 9, 'set': 9, 'ottobre': 10, 'ott': 10, 'novembre': 11, 'nov': 11,
  'dicembre': 12, 'dic': 12,
};

const _numbers = {
  'un': 1, 'uno': 1, 'una': 1, 'due': 2, 'tre': 3, 'quattro': 4, 'cinque': 5,
  'sei': 6, 'sette': 7, 'otto': 8, 'nove': 9, 'dieci': 10,
};

// Word boundaries that understand accented letters.
const _b = r'(?<![\p{L}\d])';
const _e = r'(?![\p{L}\d])';

final _weekdayAlt = _weekdays.keys.join('|');
final _monthAlt = (_months.keys.toList()..sort((a, b) => b.length.compareTo(a.length))).join('|');

RegExp _re(String p) => RegExp(p, caseSensitive: false, unicode: true);

final _rules = <(TokenKind, RegExp)>[
  (TokenKind.recurrence, _re('$_b(?:nei\\s+)?giorni\\s+feriali$_e|${_b}ogni\\s+giorno\\s+feriale$_e')),
  (TokenKind.recurrence, _re('${_b}ogni\\s+(giorno|settimana|mese|$_weekdayAlt)$_e')),
  (TokenKind.date, _re('$_b(?:il\\s+)?(\\d{1,2})\\s+($_monthAlt)(?:\\s+(\\d{4}))?$_e')),
  (TokenKind.date, _re('$_b(?:il\\s+)?(\\d{1,2})[/-](\\d{1,2})(?:[/-](\\d{2,4}))?$_e')),
  (TokenKind.time, _re('$_b(?:alle|ore|alle\\s+ore)\\s+(\\d{1,2})(?:[:.](\\d{2}))?(?:\\s+di\\s+(sera|pomeriggio|mattina))?$_e')),
  (TokenKind.time, _re('$_b(\\d{1,2}):(\\d{2})$_e')),
  (TokenKind.date, _re('$_b(dopodomani|domani|oggi|stasera|stamattina)$_e')),
  (TokenKind.date, _re('${_b}prossima\\s+settimana$_e')),
  (TokenKind.date, _re('$_b(?:tra|fra)\\s+(\\d+|${_numbers.keys.join('|')})\\s+(giorni|giorno|settimane|settimana|mesi|mese)$_e')),
  (TokenKind.date, _re('${_b}il\\s+(\\d{1,2})$_e')),
  (TokenKind.date, _re('$_b($_weekdayAlt)$_e')),
  (TokenKind.priority, _re('(?<![\\p{L}\\d])[!p]([1-4])$_e')),
  (TokenKind.category, _re('#([\\p{L}\\d_-]+)')),
];

ParsedTask parseTask(String input, DateTime now, {Set<String> ignored = const {}}) {
  final today = DateTime(now.year, now.month, now.day);
  final tokens = <ParsedToken>[];
  final taken = List<bool>.filled(input.length, false);

  DateTime? date;
  int? hour, minute, priority;
  String? category, recurrence;
  int? defaultHour;

  bool free(int s, int e) {
    for (var i = s; i < e; i++) {
      if (taken[i]) return false;
    }
    return true;
  }

  for (final (kind, re) in _rules) {
    for (final m in re.allMatches(input)) {
      final text = m.group(0)!;
      final token = ParsedToken(kind, m.start, m.end, text);
      if (!free(m.start, m.end) || ignored.contains(token.key)) continue;

      final low = text.toLowerCase();
      var used = true;
      switch (kind) {
        case TokenKind.recurrence:
          if (recurrence != null) {
            used = false;
            break;
          }
          if (low.contains('feriale') || low.contains('feriali')) {
            recurrence = 'weekdays';
          } else {
            final what = m.group(1)!.toLowerCase();
            recurrence = switch (what) {
              'giorno' => 'daily',
              'settimana' => 'weekly',
              'mese' => 'monthly',
              _ => 'weekly:${_weekdays[what]}',
            };
          }
        case TokenKind.time:
          if (hour != null) {
            used = false;
            break;
          }
          var h = int.parse(m.group(1)!);
          final mi = int.tryParse(m.group(2) ?? '') ?? 0;
          final part = m.groupCount >= 3 ? m.group(3)?.toLowerCase() : null;
          if ((part == 'sera' || part == 'pomeriggio') && h < 12) h += 12;
          if (h > 23 || mi > 59) {
            used = false;
            break;
          }
          hour = h;
          minute = mi;
        case TokenKind.priority:
          if (priority != null) {
            used = false;
            break;
          }
          priority = int.parse(m.group(1)!);
        case TokenKind.category:
          if (category != null) {
            used = false;
            break;
          }
          category = m.group(1);
        case TokenKind.date:
          if (date != null) {
            used = false;
            break;
          }
          final d = _resolveDate(low, m, today);
          if (d == null) {
            used = false;
            break;
          }
          date = d.$1;
          defaultHour = d.$2;
      }
      if (!used) continue;
      tokens.add(token);
      for (var i = m.start; i < m.end; i++) {
        taken[i] = true;
      }
    }
  }

  if (recurrence != null && date == null) date = firstOccurrence(today, recurrence);
  if (defaultHour != null && hour == null) {
    hour = defaultHour;
    minute = 0;
  }
  if (hour != null && date == null) {
    final t = DateTime(today.year, today.month, today.day, hour, minute ?? 0);
    date = t.isAfter(now) ? today : DateTime(today.year, today.month, today.day + 1);
  }

  final buf = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    buf.write(taken[i] ? ' ' : input[i]);
  }
  final title = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  tokens.sort((a, b) => a.start.compareTo(b.start));
  return ParsedTask(
    title: title,
    tokens: tokens,
    date: date,
    hour: hour,
    minute: minute,
    priority: priority,
    category: category,
    recurrence: recurrence,
  );
}

/// (day, default hour) for a date token; null if it is not a real date.
(DateTime, int?)? _resolveDate(String low, RegExpMatch m, DateTime today) {
  DateTime day(int y, int mo, int d) => DateTime(y, mo, d);
  final t = today;
  switch (low) {
    case 'oggi':
      return (t, null);
    case 'domani':
      return (day(t.year, t.month, t.day + 1), null);
    case 'dopodomani':
      return (day(t.year, t.month, t.day + 2), null);
    case 'stasera':
      return (t, 20);
    case 'stamattina':
      return (t, 9);
  }
  if (low.startsWith('prossima')) {
    final toMonday = 8 - t.weekday;
    return (day(t.year, t.month, t.day + toMonday), null);
  }
  if (low.startsWith('tra') || low.startsWith('fra')) {
    final nRaw = m.group(1)!.toLowerCase();
    final n = int.tryParse(nRaw) ?? _numbers[nRaw] ?? 1;
    final unit = m.group(2)!.toLowerCase();
    if (unit.startsWith('giorn')) return (day(t.year, t.month, t.day + n), null);
    if (unit.startsWith('settiman')) return (day(t.year, t.month, t.day + 7 * n), null);
    return (day(t.year, t.month + n, t.day), null);
  }
  final wd = _weekdays[low];
  if (wd != null) {
    var add = (wd - t.weekday + 7) % 7;
    if (add == 0) add = 7;
    return (day(t.year, t.month, t.day + add), null);
  }
  // "il 15"
  if (low.startsWith('il') && m.groupCount == 1) {
    final d = int.parse(m.group(1)!);
    if (d < 1 || d > 31) return null;
    final thisMonth = day(t.year, t.month, d);
    return (d >= t.day ? thisMonth : day(t.year, t.month + 1, d), null);
  }
  // "15 ottobre [2027]" or "15/10[/2027]"
  final d = int.tryParse(m.group(1) ?? '');
  final monthWord = m.group(2)?.toLowerCase();
  final mo = _months[monthWord] ?? int.tryParse(monthWord ?? '');
  if (d == null || mo == null || d < 1 || d > 31 || mo < 1 || mo > 12) return null;
  var y = int.tryParse(m.groupCount >= 3 ? m.group(3) ?? '' : '');
  if (y != null && y < 100) y += 2000;
  if (y != null) return (day(y, mo, d), null);
  final guess = day(t.year, mo, d);
  return (guess.isBefore(t) ? day(t.year + 1, mo, d) : guess, null);
}
