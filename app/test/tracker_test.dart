import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/db.dart';
import 'package:time_tracker/tracker.dart';

void main() {
  late Db db;
  late Tracker tracker;

  setUp(() async {
    db = Db.forTesting(NativeDatabase.memory());
    tracker = Tracker(db);
    await db.customStatement('select 1'); // force beforeOpen + seed data
  });

  tearDown(() => db.close());

  Future<int> firstActivity() async =>
      (await db.watchActivities().first).first.id;

  test('start opens a session with one open work segment', () async {
    await tracker.start(await firstActivity());

    final session = await db.openSession();
    expect(session, isNotNull);
    final seg = await db.openSegment();
    expect(seg!.isPause, isFalse);
    expect(seg.endedAt, isNull);
  });

  test('pause and resume split the session, pause is not worked time', () async {
    final id = await firstActivity();
    await tracker.start(id);

    final session = (await db.openSession())!;
    // Backdate the work segment: 30 minutes of work already done.
    final start = DateTime.now().subtract(const Duration(minutes: 30));
    await (db.update(db.segments)..where((s) => s.sessionId.equals(session.id)))
        .write(SegmentsCompanion(startedAt: Value(start)));

    await tracker.pause();
    expect((await db.openSegment())!.isPause, isTrue);

    await tracker.resume();
    final seg = await db.openSegment();
    expect(seg!.isPause, isFalse);

    final segs = await db.segmentsOf(session.id);
    expect(segs.length, 3);
    final worked = Tracker.worked(segs);
    expect(worked.inMinutes, inInclusiveRange(29, 31));
    expect(Tracker.paused(segs).inMinutes, lessThan(2));
  });

  test('an expired auto-pause deadline turns into a pause at that time', () async {
    await db.setPref('breakMode', 'auto');
    await db.setPref('breakAfterMin', '120');
    await tracker.start(await firstActivity());

    final session = (await db.openSession())!;
    final due = DateTime.now().subtract(const Duration(minutes: 5));
    await (db.update(db.segments)..where((s) => s.sessionId.equals(session.id)))
        .write(
          SegmentsCompanion(
            startedAt: Value(due.subtract(const Duration(hours: 2))),
            deadlineAt: Value(due),
            deadlineKind: const Value(kAutoPause),
          ),
        );

    expect(await tracker.materialize(), isTrue);

    final segs = await db.segmentsOf(session.id);
    expect(segs.length, 2);
    // Stored timestamps have second precision.
    expect(segs.first.endedAt!.difference(due).inSeconds, 0); // stopped at the deadline
    expect(segs.last.isPause, isTrue);
    expect(segs.last.startedAt.difference(due).inSeconds, 0); // pause started there
    expect(Tracker.worked(segs).inMinutes, inInclusiveRange(119, 121));
  });

  test('"no, keep working" glues the work back together, no gap', () async {
    await db.setPref('breakMode', 'auto');
    await db.setPref('breakAfterMin', '120');
    await tracker.start(await firstActivity());

    final session = (await db.openSession())!;
    final due = DateTime.now().subtract(const Duration(minutes: 5));
    await (db.update(db.segments)..where((s) => s.sessionId.equals(session.id)))
        .write(
          SegmentsCompanion(
            startedAt: Value(due.subtract(const Duration(hours: 2))),
            deadlineAt: Value(due),
            deadlineKind: const Value(kAutoPause),
          ),
        );
    await tracker.materialize();
    await tracker.declineAutoPause();

    final segs = await db.segmentsOf(session.id);
    expect(segs.length, 1);
    expect(segs.single.isPause, isFalse);
    expect(segs.single.endedAt, isNull);
    // The five minutes spent not answering still count as work.
    expect(Tracker.worked(segs).inMinutes, inInclusiveRange(124, 126));
    expect(Tracker.paused(segs), Duration.zero);
  });

  test('stop closes both the segment and the session', () async {
    await tracker.start(await firstActivity());
    await tracker.stop();

    expect(await db.openSegment(), isNull);
    expect(await db.openSession(), isNull);
  });

  test('starting another activity closes the previous session', () async {
    final acts = await db.watchActivities().first;
    await tracker.start(acts[0].id);
    await tracker.start(acts[1].id);

    final open = await db.openSession();
    expect(open!.activityId, acts[1].id);
    final all = await db.select(db.sessions).get();
    expect(all.length, 2);
    expect(all.where((s) => s.endedAt == null).length, 1);
  });
}
