import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'db.g.dart';

class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  /// Index into the active palette, so changing palette recolours everything.
  IntColumn get colorIndex => integer()();
  TextColumn get icon => text().withDefault(const Constant('circle'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sort => integer().withDefault(const Constant(0))();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId => integer().references(Activities, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
}

/// A slice of a session: either work or pause.
///
/// [deadlineAt] + [deadlineKind] let the app close a segment at an exact past
/// moment without running any background code: whoever reads the live state
/// first applies the rule. See [Tracker.materialize].
class Segments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  BoolColumn get isPause => boolean()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  DateTimeColumn get deadlineAt => dateTime().nullable()();
  TextColumn get deadlineKind => text().nullable()();
}

class Prefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Activities, Sessions, Segments, Prefs])
class Db extends _$Db {
  Db() : super(driftDatabase(name: 'taime'));
  Db.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.wasCreated) {
        await batch((b) {
          b.insertAll(activities, [
            ActivitiesCompanion.insert(
              name: 'Studio',
              colorIndex: 0,
              icon: const Value('book'),
              sort: const Value(0),
            ),
            ActivitiesCompanion.insert(
              name: 'Palestra',
              colorIndex: 1,
              icon: const Value('barbell'),
              sort: const Value(1),
            ),
            ActivitiesCompanion.insert(
              name: 'Pulizie',
              colorIndex: 2,
              icon: const Value('broom'),
              sort: const Value(2),
            ),
          ]);
        });
      }
    },
  );

  Stream<List<Activity>> watchActivities({bool includeArchived = false}) {
    final q = select(activities)
      ..where((a) => includeArchived ? const Constant(true) : a.archived.equals(false))
      ..orderBy([(a) => OrderingTerm(expression: a.sort)]);
    return q.watch();
  }

  Future<Activity?> activityById(int id) =>
      (select(activities)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// The session that has no end yet, if any.
  Stream<Session?> watchOpenSession() =>
      (select(sessions)..where((s) => s.endedAt.isNull())).watchSingleOrNull();

  Future<Session?> openSession() =>
      (select(sessions)..where((s) => s.endedAt.isNull())).getSingleOrNull();

  Future<Segment?> openSegment() =>
      (select(segments)..where((s) => s.endedAt.isNull())).getSingleOrNull();

  Stream<Segment?> watchOpenSegment() =>
      (select(segments)..where((s) => s.endedAt.isNull())).watchSingleOrNull();

  Future<List<Segment>> segmentsOf(int sessionId) =>
      (select(segments)
            ..where((s) => s.sessionId.equals(sessionId))
            ..orderBy([(s) => OrderingTerm(expression: s.startedAt)]))
          .get();

  Stream<List<Segment>> watchSegmentsOf(int sessionId) =>
      (select(segments)
            ..where((s) => s.sessionId.equals(sessionId))
            ..orderBy([(s) => OrderingTerm(expression: s.startedAt)]))
          .watch();

  /// Sessions that overlap [from, to).
  Stream<List<Session>> watchSessionsBetween(DateTime from, DateTime to) {
    final q = select(sessions)
      ..where((s) => s.startedAt.isSmallerThanValue(to))
      ..where((s) => s.endedAt.isNull() | s.endedAt.isBiggerThanValue(from))
      ..orderBy([(s) => OrderingTerm(expression: s.startedAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Stream<List<Segment>> watchSegmentsBetween(DateTime from, DateTime to) {
    final q = select(segments)
      ..where((s) => s.startedAt.isSmallerThanValue(to))
      ..where((s) => s.endedAt.isNull() | s.endedAt.isBiggerThanValue(from));
    return q.watch();
  }

  Future<List<Segment>> segmentsBetween(DateTime from, DateTime to) {
    final q = select(segments)
      ..where((s) => s.startedAt.isSmallerThanValue(to))
      ..where((s) => s.endedAt.isNull() | s.endedAt.isBiggerThanValue(from));
    return q.get();
  }

  /// Segments overlapping [from, to) with the activity they belong to.
  Stream<List<({Segment segment, int activityId})>> watchRange(
    DateTime from,
    DateTime to,
  ) {
    final q = select(segments).join([
      innerJoin(sessions, sessions.id.equalsExp(segments.sessionId)),
    ])..where(
      segments.startedAt.isSmallerThanValue(to) &
          (segments.endedAt.isNull() | segments.endedAt.isBiggerThanValue(from)),
    );
    return q.watch().map(
      (rows) => rows
          .map(
            (r) => (
              segment: r.readTable(segments),
              activityId: r.readTable(sessions).activityId,
            ),
          )
          .toList(),
    );
  }

  Future<void> updateSessionNote(int id, String note) =>
      (update(sessions)..where((s) => s.id.equals(id)))
          .write(SessionsCompanion(note: Value(note)));

  Future<void> deleteSession(int id) async {
    await (delete(segments)..where((s) => s.sessionId.equals(id))).go();
    await (delete(sessions)..where((s) => s.id.equals(id))).go();
  }

  Future<void> deleteSegment(int id) =>
      (delete(segments)..where((s) => s.id.equals(id))).go();

  Future<Session?> sessionById(int id) =>
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Rewrites a session and keeps its start/end in step with its segments.
  Future<void> reshapeSession(int id) async {
    final segs = await segmentsOf(id);
    if (segs.isEmpty) return;
    final start = segs.map((s) => s.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final ends = segs.map((s) => s.endedAt).toList();
    final end = ends.contains(null)
        ? null
        : ends.cast<DateTime>().reduce((a, b) => a.isAfter(b) ? a : b);
    await (update(sessions)..where((s) => s.id.equals(id))).write(
      SessionsCompanion(startedAt: Value(start), endedAt: Value(end)),
    );
  }

  /// A finished session added by hand.
  Future<int> addManualSession({
    required int activityId,
    required DateTime start,
    required DateTime end,
    String note = '',
  }) async {
    final id = await into(sessions).insert(
      SessionsCompanion.insert(
        activityId: activityId,
        note: Value(note),
        startedAt: start,
        endedAt: Value(end),
      ),
    );
    await into(segments).insert(
      SegmentsCompanion.insert(
        sessionId: id,
        isPause: false,
        startedAt: start,
        endedAt: Value(end),
      ),
    );
    return id;
  }

  Future<String?> pref(String key) async {
    final row = await (select(prefs)..where((p) => p.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setPref(String key, String value) => into(
    prefs,
  ).insertOnConflictUpdate(PrefsCompanion.insert(key: key, value: value));

  Stream<Map<String, String>> watchPrefs() => select(prefs).watch().map(
    (rows) => {for (final r in rows) r.key: r.value},
  );

  Future<Map<String, String>> allPrefs() async =>
      {for (final r in await select(prefs).get()) r.key: r.value};
}
