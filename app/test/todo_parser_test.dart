import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/todo/parser.dart';
import 'package:time_tracker/todo/recurrence.dart';

void main() {
  // Wednesday 23 September 2026, 10:00.
  final now = DateTime(2026, 9, 23, 10);
  ParsedTask p(String s, {Set<String> ignored = const {}}) => parseTask(s, now, ignored: ignored);
  DateTime d(int m, int day, [int y = 2026]) => DateTime(y, m, day);

  test('the acceptance example', () {
    final t = p('comprare il latte domani alle 18 #casa !2');
    expect(t.title, 'comprare il latte');
    expect(t.due, DateTime(2026, 9, 24, 18));
    expect(t.hasTime, isTrue);
    expect(t.category, 'casa');
    expect(t.priority, 2);
    expect(t.tokens.map((x) => x.kind), [
      TokenKind.date,
      TokenKind.time,
      TokenKind.category,
      TokenKind.priority,
    ]);
  });

  test('relative days', () {
    expect(p('x oggi').date, d(9, 23));
    expect(p('x domani').date, d(9, 24));
    expect(p('x dopodomani').date, d(9, 25));
    expect(p('x stasera').due, DateTime(2026, 9, 23, 20));
    expect(p('x stamattina').due, DateTime(2026, 9, 23, 9));
    expect(p('x stasera alle 21').due, DateTime(2026, 9, 23, 21));
    expect(p('x prossima settimana').date, d(9, 28));
    expect(p('x tra 3 giorni').date, d(9, 26));
    expect(p('x fra due settimane').date, d(10, 7));
    expect(p('x tra un mese').date, d(10, 23));
  });

  test('weekdays, full and short, always in the future', () {
    expect(p('esame lunedì').date, d(9, 28));
    expect(p('esame lunedi').date, d(9, 28));
    expect(p('esame lun').date, d(9, 28));
    expect(p('esame venerdì').date, d(9, 25));
    expect(p('esame mer').date, d(9, 30)); // today is Wednesday: next one
    expect(p('esame domenica').date, d(9, 27));
    expect(p('esame lunedì').title, 'esame');
  });

  test('calendar dates', () {
    expect(p('x il 15').date, d(10, 15)); // 15th already passed this month
    expect(p('x il 30').date, d(9, 30));
    expect(p('x 15/10').date, d(10, 15));
    expect(p('x 1/2').date, d(2, 1, 2027)); // passed: next year
    expect(p('x 15/10/2027').date, d(10, 15, 2027));
    expect(p('x 15 ottobre').date, d(10, 15));
    expect(p('x il 3 gen').date, d(1, 3, 2027));
    expect(p('x il 15 ottobre').title, 'x');
  });

  test('times', () {
    expect(p('x alle 18').due, DateTime(2026, 9, 23, 18));
    expect(p('x 18:30').due, DateTime(2026, 9, 23, 18, 30));
    // 9:00 has already gone today: tomorrow.
    expect(p('x alle 9').due, DateTime(2026, 9, 24, 9));
    expect(p('x alle 7 di sera').due, DateTime(2026, 9, 23, 19));
    expect(p('x domani alle 9:15').due, DateTime(2026, 9, 24, 9, 15));
    expect(p('x').due, isNull);
  });

  test('recurrences set a rule and a first date', () {
    final daily = p('bere acqua ogni giorno');
    expect(daily.recurrence, 'daily');
    expect(daily.date, d(9, 23));
    expect(daily.title, 'bere acqua');

    final mon = p('palestra ogni lunedì alle 19');
    expect(mon.recurrence, 'weekly:1');
    expect(mon.due, DateTime(2026, 9, 28, 19));

    expect(p('x ogni settimana').recurrence, 'weekly');
    expect(p('x ogni mese').recurrence, 'monthly');
    final wd = p('x nei giorni feriali');
    expect(wd.recurrence, 'weekdays');
    expect(wd.date, d(9, 23));
  });

  test('priorities and categories', () {
    expect(p('x p1').priority, 1);
    expect(p('x !4').priority, 4);
    expect(p('ascoltare mp3').priority, isNull);
    expect(p('x #Università').category, 'Università');
  });

  test('a tapped token is no longer recognised', () {
    final t = p('domani', ignored: {'date:domani'});
    expect(t.date, isNull);
    expect(t.title, 'domani');
  });

  test('next occurrences keep the time of day', () {
    final due = DateTime(2026, 9, 25, 18); // Friday
    expect(nextOccurrence(due, 'daily'), DateTime(2026, 9, 26, 18));
    expect(nextOccurrence(due, 'weekdays'), DateTime(2026, 9, 28, 18)); // skips the weekend
    expect(nextOccurrence(due, 'weekly'), DateTime(2026, 10, 2, 18));
    expect(nextOccurrence(due, 'weekly:1'), DateTime(2026, 9, 28, 18));
    expect(nextOccurrence(DateTime(2026, 1, 31), 'monthly'), DateTime(2026, 2, 28));
  });
}
