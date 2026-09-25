/// Recurrence rules for to-dos: 'daily', 'weekdays', 'weekly', 'weekly:N'
/// (N = 1 Monday .. 7 Sunday), 'monthly'.
library;

const _dayNames = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];

/// The occurrence after [due], keeping its time of day.
DateTime nextOccurrence(DateTime due, String rule) {
  DateTime addDays(int n) =>
      DateTime(due.year, due.month, due.day + n, due.hour, due.minute);
  switch (rule) {
    case 'daily':
      return addDays(1);
    case 'weekdays':
      var n = 1;
      while (addDays(n).weekday > 5) {
        n++;
      }
      return addDays(n);
    case 'weekly':
      return addDays(7);
    case 'monthly':
      final lastDay = DateTime(due.year, due.month + 2, 0).day;
      return DateTime(due.year, due.month + 1, due.day > lastDay ? lastDay : due.day, due.hour, due.minute);
  }
  if (rule.startsWith('weekly:')) {
    final target = int.tryParse(rule.substring(7)) ?? due.weekday;
    var n = 1;
    while (addDays(n).weekday != target) {
      n++;
    }
    return addDays(n);
  }
  return addDays(1);
}

/// First occurrence on or after [from] (used when a rule has no date).
DateTime firstOccurrence(DateTime from, String rule) {
  final d = DateTime(from.year, from.month, from.day);
  if (rule == 'weekdays') {
    var x = d;
    while (x.weekday > 5) {
      x = DateTime(x.year, x.month, x.day + 1);
    }
    return x;
  }
  if (rule.startsWith('weekly:')) {
    final target = int.tryParse(rule.substring(7)) ?? d.weekday;
    var x = d;
    while (x.weekday != target) {
      x = DateTime(x.year, x.month, x.day + 1);
    }
    return x;
  }
  return d;
}

String recurrenceLabel(String rule) {
  if (rule.startsWith('weekly:')) {
    final n = int.tryParse(rule.substring(7)) ?? 1;
    return 'Ogni ${_dayNames[(n - 1).clamp(0, 6)]}';
  }
  return switch (rule) {
    'daily' => 'Ogni giorno',
    'weekdays' => 'Giorni feriali',
    'weekly' => 'Ogni settimana',
    'monthly' => 'Ogni mese',
    _ => rule,
  };
}

const Map<String, String> kRecurrenceChoices = {
  'daily': 'Ogni giorno',
  'weekdays': 'Giorni feriali',
  'weekly': 'Ogni settimana',
  'monthly': 'Ogni mese',
};
