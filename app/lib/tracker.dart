import 'package:drift/drift.dart';

import 'package:taime_native/taime_native.dart';

import 'db.dart';
import 'kitten/art.dart';
import 'kitten/skins.dart';
import 'notif.dart';
import 'palette.dart';
import 'settings.dart';
import 'theme.dart';

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

  /// [todoId]: the to-do this focus is for (Avvia focus), offered to tick off
  /// at the end.
  Future<void> start(int activityId, {String note = '', String? skinId, int? todoId}) async {
    await stop();
    await db.setPref('focusTodo', todoId?.toString() ?? '');
    final now = DateTime.now();
    final skin = skinId ?? (await _settings()).activeSkin;
    final id = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            activityId: activityId,
            note: Value(note),
            startedAt: now,
            skinId: Value(skin),
          ),
        );
    await _openWork(id, now);
    await db.setPref('lastActivityId', '$activityId');
    await sync();
  }

  /// Throws the running session away, as if it never started.
  Future<void> cancel() async {
    final session = await db.openSession();
    if (session == null) return;
    await db.deleteSession(session.id);
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

  /// Pomodoro pause length: every [Settings.pomoEvery]-th one is the long one.
  static int pomoBreakMinutes(Settings s, List<Segment> segs) {
    final done = segs.where((x) => !x.isPause && x.endedAt != null).length;
    return done > 0 && done % s.pomoEvery == 0 ? s.pomoLongBreakMin : s.pomoBreakMin;
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
    final s = await _settings();
    if (seg == null || seg.isPause) await cancelAwayReminder();
    if (seg == null) {
      await cancelReminder();
      await TaimeNative.liveStop().catchError((_) {});
      await _widgetIdle(s);
      return;
    }
    final session = await db.openSession();
    final act = session == null ? null : await db.activityById(session.activityId);
    final name = act?.name ?? 'Attività';
    final color = accentFor(act?.color ?? 0xFF93C4A0, dark: false);
    final segs = await db.segmentsOf(seg.sessionId);
    final now = DateTime.now();
    final work = worked(segs, now: now);
    final skinId = session?.skinId ?? s.activeSkin;
    final stage = stageOf((work.inSeconds / 60) % 60);
    final pauseMins = s.pomodoro ? pomoBreakMinutes(s, segs) : s.pauseReminderMin;

    // The reminder matters most: schedule it before anything else can fail.
    try {
      await _scheduleFor(s, seg, segs, pauseMins);
    } catch (_) {}

    final art = [for (var i = 0; i <= 4; i++) await kittenArtPath(skinId, i), await kittenArtPath(skinId, 0, sleeping: true)];
    await TaimeNative.liveUpdate(
      title: name,
      paused: seg.isPause,
      pomodoro: s.pomodoro,
      color: color,
      workedMs: work.inMilliseconds,
      stampMs: now.millisecondsSinceEpoch,
      pauseStartMs: seg.startedAt.millisecondsSinceEpoch,
      segmentStartMs: seg.startedAt.millisecondsSinceEpoch,
      pomoMs: (seg.isPause ? pauseMins : s.pomoWorkMin) * 60000,
      deadlineMs: seg.deadlineAt?.millisecondsSinceEpoch ?? 0,
      art: art,
      stageNames: kStageNames,
      stageMinutes: kStageMinutes,
    );
    await TaimeNative.widgetUpdate(
      running: true,
      paused: seg.isPause,
      title: seg.isPause ? 'In pausa · $name' : name,
      subtitle: seg.isPause ? 'Lavoro ${fmtHm(work)}' : kStageNames[stage],
      sinceMs: seg.isPause ? seg.startedAt.millisecondsSinceEpoch : now.subtract(work).millisecondsSinceEpoch,
      artPath: seg.isPause ? art.last : art[stage],
    ).catchError((_) {});
  }

  Future<void> _scheduleFor(Settings s, Segment seg, List<Segment> segs, int pauseMins) async {
    if (seg.isPause) {
      if (pauseMins > 0) {
        await scheduleReminder(
          settings: s,
          at: seg.startedAt.add(Duration(minutes: pauseMins)),
          title: 'Torna al lavoro',
          body: 'La pausa di $pauseMins minuti è finita',
          actions: [action('resume', 'Riprendi')],
        );
      } else {
        await cancelReminder();
      }
      return;
    }

    final due = seg.deadlineAt;
    if (s.pomodoro && due != null) {
      await scheduleReminder(
        settings: s,
        at: due,
        title: 'Pomodoro finito',
        body: 'Pausa di ${pomoBreakMinutes(s, [...segs.where((x) => x.id != seg.id), seg.copyWith(endedAt: Value(due))])} minuti',
        actions: [action('stop', 'Termina')],
      );
    } else if (s.breakMode == 'auto' && due != null) {
      await scheduleReminder(
        settings: s,
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
        settings: s,
        at: seg.startedAt.add(Duration(minutes: s.breakAfterMin)),
        title: 'Fai una pausa',
        body: 'Stai lavorando da ${s.breakAfterMin} minuti',
        actions: [action('pause', 'Pausa ora')],
      );
    } else {
      await cancelReminder();
    }
  }

  /// Widget at rest: the chosen kitten and the activity you would start.
  Future<void> _widgetIdle(Settings s) async {
    try {
      final acts = await db.watchActivities().first;
      final act = acts.where((a) => a.id == s.lastActivityId).firstOrNull ?? acts.firstOrNull;
      await TaimeNative.widgetUpdate(
        running: false,
        paused: false,
        title: act?.name ?? 'Taime',
        subtitle: 'Pronto per il focus',
        sinceMs: 0,
        artPath: await kittenArtPath(s.activeSkin, 4),
      );
    } catch (_) {}
  }

  /// "Inizia" from the widget: the last activity, with the chosen kitten.
  Future<void> startLast() async {
    final s = await _settings();
    final acts = await db.watchActivities().first;
    if (acts.isEmpty) return;
    final act = acts.where((a) => a.id == s.lastActivityId).firstOrNull ?? acts.first;
    await start(act.id);
  }

  Future<void> handleAction(String? actionId) async {
    switch (actionId) {
      case 'pause':
        await pause();
      case 'resume':
        await resume();
      case 'stop':
        await stop();
      case 'start':
        if (await db.openSession() == null) await startLast();
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
