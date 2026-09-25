import 'package:drift/drift.dart';

import 'db.dart';
import 'notif.dart';
import 'settings.dart';

/// Deadline kinds stored on a segment.
const kAutoPause = 'autoPause'; // work segment: turn into a pause when it expires
const kPomoWork = 'pomoWork'; // work segment: pomodoro ran out
const kFromAuto = 'fromAuto'; // pause segment: born from an auto-pause

/// All timer state lives in the database as timestamps, so the app never has to
/// be running for time to pass correctly. Deadlines that fall due while the app
/// is closed are applied by [materialize] on the next read.
class Tracker {
  Tracker(this.db);
  final Db db;

  Future<Settings> _settings() async => Settings(await db.allPrefs());

  Future<void> start(int activityId, {String note = ''}) async {
    await stop();
    final now = DateTime.now();
    final id = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            activityId: activityId,
            note: Value(note),
            startedAt: now,
          ),
        );
    await _openWork(id, now);
    await db.setPref('lastActivityId', '$activityId');
    await sync();
  }

  Future<void> _openWork(int sessionId, DateTime at) async {
    final s = await _settings();
    DateTime? deadline;
    String? kind;
    if (s.pomodoro) {
      deadline = at.add(Duration(minutes: s.pomoWorkMin));
      kind = kPomoWork;
    } else if (s.breakMode == 'auto' && s.breakAfterMin > 0) {
      deadline = at.add(Duration(minutes: s.breakAfterMin));
      kind = kAutoPause;
    }
    await db
        .into(db.segments)
        .insert(
          SegmentsCompanion.insert(
            sessionId: sessionId,
            isPause: false,
            startedAt: at,
            deadlineAt: Value(deadline),
            deadlineKind: Value(kind),
          ),
        );
  }

  Future<void> pause() async {
    await materialize();
    final seg = await db.openSegment();
    if (seg == null || seg.isPause) return;
    final now = DateTime.now();
    await _close(seg, now);
    await db
        .into(db.segments)
        .insert(
          SegmentsCompanion.insert(
            sessionId: seg.sessionId,
            isPause: true,
            startedAt: now,
          ),
        );
    await sync();
  }

  Future<void> resume() async {
    await materialize();
    final seg = await db.openSegment();
    if (seg == null || !seg.isPause) return;
    final now = DateTime.now();
    await _close(seg, now);
    await _openWork(seg.sessionId, now);
    await sync();
  }

  Future<void> stop() async {
    await materialize();
    final seg = await db.openSegment();
    final now = DateTime.now();
    if (seg != null) await _close(seg, now);
    final session = await db.openSession();
    if (session != null) {
      await (db.update(db.sessions)..where((s) => s.id.equals(session.id)))
          .write(SessionsCompanion(endedAt: Value(now)));
    }
    await sync();
  }

  /// Corrects the activity of the running session ("started the wrong one").
  Future<void> reassign(int activityId) async {
    final session = await db.openSession();
    if (session == null) return;
    await (db.update(db.sessions)..where((s) => s.id.equals(session.id))).write(
      SessionsCompanion(activityId: Value(activityId)),
    );
    await db.setPref('lastActivityId', '$activityId');
    await sync();
  }

  /// "No, continua": cancel the automatic pause and keep working.
  Future<void> declineAutoPause() async {
    final s = await _settings();
    final next = s.breakAfterMin > 0
        ? DateTime.now().add(Duration(minutes: s.breakAfterMin))
        : null;
    final seg = await db.openSegment();
    if (seg == null) return;

    if (!seg.isPause) {
      // Deadline had not been applied yet: just push it forward.
      await (db.update(db.segments)..where((x) => x.id.equals(seg.id))).write(
        SegmentsCompanion(
          deadlineAt: Value(next),
          deadlineKind: Value(next == null ? null : kAutoPause),
        ),
      );
    } else if (seg.deadlineKind == kFromAuto) {
      // Already applied: glue the work segment back together.
      final prev =
          await (db.select(db.segments)
                ..where((x) => x.sessionId.equals(seg.sessionId))
                ..where((x) => x.endedAt.equalsNullable(seg.startedAt))
                ..where((x) => x.isPause.equals(false)))
              .getSingleOrNull();
      await (db.delete(db.segments)..where((x) => x.id.equals(seg.id))).go();
      if (prev != null) {
        await (db.update(db.segments)..where((x) => x.id.equals(prev.id))).write(
          SegmentsCompanion(
            endedAt: const Value(null),
            deadlineAt: Value(next),
            deadlineKind: Value(next == null ? null : kAutoPause),
          ),
        );
      }
    }
    await sync();
  }

  Future<void> _close(Segment seg, DateTime at) =>
      (db.update(db.segments)..where((x) => x.id.equals(seg.id))).write(
        SegmentsCompanion(
          endedAt: Value(at.isBefore(seg.startedAt) ? seg.startedAt : at),
          deadlineAt: const Value(null),
          deadlineKind: const Value(null),
        ),
      );

  /// Applies a deadline that fell due while nobody was looking.
  Future<bool> materialize() async {
    final seg = await db.openSegment();
    if (seg == null) return false;
    final due = seg.deadlineAt;
    if (due == null || DateTime.now().isBefore(due)) return false;

    if (seg.deadlineKind == kAutoPause || seg.deadlineKind == kPomoWork) {
      await _close(seg, due);
      await db
          .into(db.segments)
          .insert(
            SegmentsCompanion.insert(
              sessionId: seg.sessionId,
              isPause: true,
              startedAt: due,
              deadlineKind: Value(
                seg.deadlineKind == kAutoPause ? kFromAuto : null,
              ),
            ),
          );
      return true;
    }
    return false;
  }

  /// Worked time of a session, open segment included.
  static Duration worked(List<Segment> segs, {DateTime? now}) {
    final n = now ?? DateTime.now();
    var total = Duration.zero;
    for (final s in segs.where((s) => !s.isPause)) {
      total += (s.endedAt ?? n).difference(s.startedAt);
    }
    return total;
  }

  static Duration paused(List<Segment> segs, {DateTime? now}) {
    final n = now ?? DateTime.now();
    var total = Duration.zero;
    for (final s in segs.where((s) => s.isPause)) {
      total += (s.endedAt ?? n).difference(s.startedAt);
    }
    return total;
  }

  /// Rebuilds the ongoing notification and the single pending reminder.
  /// Notifications are a convenience: if the platform refuses, the timer
  /// itself must keep working, so failures here are swallowed.
  Future<void> sync() async {
    try {
      await _sync();
    } catch (_) {}
  }

  Future<void> _sync() async {
    final seg = await db.openSegment();
    if (seg == null) {
      await hideOngoing();
      await cancelReminder();
      return;
    }
    final s = await _settings();
    final session = await db.openSession();
    final act = session == null ? null : await db.activityById(session.activityId);
    final name = act?.name ?? 'Attività';

    if (seg.isPause) {
      await showOngoing(
        title: 'In pausa · $name',
        body: 'Tocca Riprendi quando torni',
        since: seg.startedAt,
        actions: [action('resume', 'Riprendi'), action('stop', 'Stop')],
      );
      final mins = s.pomodoro ? s.pomoBreakMin : s.pauseReminderMin;
      if (mins > 0) {
        await scheduleReminder(
          at: seg.startedAt.add(Duration(minutes: mins)),
          title: 'Torna al lavoro',
          body: 'La pausa di $mins minuti è finita',
          actions: [action('resume', 'Riprendi')],
        );
      } else {
        await cancelReminder();
      }
      return;
    }

    final segs = await db.segmentsOf(seg.sessionId);
    await showOngoing(
      title: name,
      body: s.pomodoro ? 'Pomodoro in corso' : 'Timer in corso',
      since: DateTime.now().subtract(worked(segs)),
      actions: [action('pause', 'Pausa'), action('stop', 'Stop')],
    );

    final due = seg.deadlineAt;
    if (s.pomodoro && due != null) {
      await scheduleReminder(
        at: due,
        title: 'Pomodoro finito',
        body: 'Pausa di ${s.pomoBreakMin} minuti',
        actions: [action('stop', 'Stop')],
      );
    } else if (s.breakMode == 'auto' && due != null) {
      await scheduleReminder(
        at: due,
        title: 'Pausa automatica',
        body: 'Hai lavorato ${s.breakAfterMin} minuti. Prendi la pausa?',
        actions: [
          action('keepPause', 'Sì'),
          action('declinePause', 'No, continua'),
        ],
      );
    } else if (s.breakAfterMin > 0) {
      await scheduleReminder(
        at: seg.startedAt.add(Duration(minutes: s.breakAfterMin)),
        title: 'Fai una pausa',
        body: 'Stai lavorando da ${s.breakAfterMin} minuti',
        actions: [action('pause', 'Pausa ora')],
      );
    } else {
      await cancelReminder();
    }
  }

  Future<void> handleAction(String? actionId) async {
    switch (actionId) {
      case 'pause':
        await pause();
      case 'resume':
        await resume();
      case 'stop':
        await stop();
      case 'declinePause':
        await declineAutoPause();
      case 'keepPause':
        await materialize();
        await sync();
      default:
        await materialize();
        await sync();
    }
  }
}
