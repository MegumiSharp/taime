import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'palette.dart';
import 'ui/swatches.dart';

part 'db.g.dart';

class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// ARGB. Always drawn through `accentFor` so it stays readable.
  IntColumn get color => integer()();
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

  /// Kitten skin used; null for sessions recorded before 2.0.
  TextColumn get skinId => text().nullable()();
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

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get skinId => text().unique()();
  IntColumn get price => integer()();
  DateTimeColumn get purchasedAt => dateTime()();
}

class TodoCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
}

class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Set for subtasks (one level only).
  IntColumn get parentId => integer().nullable().references(
    Todos,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get categoryId => integer().nullable().references(
    TodoCategories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get due => dateTime().nullable()();
  BoolColumn get hasTime => boolean().withDefault(const Constant(false))();

  /// 1 = highest, 4 = none.
  IntColumn get priority => integer().withDefault(const Constant(4))();

  /// See `todo/recurrence.dart`: daily, weekdays, weekly:N, monthly.
  TextColumn get recurrence => text().nullable()();

  /// Minutes before [due] to notify; null = no reminder.
  IntColumn get remindBefore => integer().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  /// For to-dos without a date: 0 = oggi, 1 = questa settimana, 2 = più avanti.
  IntColumn get horizon => integer().withDefault(const Constant(0))();
}

/// Free-form notes: an endless list, optionally coloured, dated, reminded.
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get body => text()();

  /// ARGB swatch; null = plain card.
  IntColumn get color => integer().nullable()();
  DateTimeColumn get date => dateTime().nullable()();
  BoolColumn get hasTime => boolean().withDefault(const Constant(false))();

  /// Notify at [date] (09:00 when it has no time).
  BoolColumn get remind => boolean().withDefault(const Constant(false))();

  /// Kept at the top of the list.
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Kittens made in "Crea il tuo gattino". Deleted ones stay (flagged) so past
/// sessions keep drawing them.
class CustomSkins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// JSON, see `Skin.toJson`.
  TextColumn get spec => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

typedef SessionWork = ({Session session, int workSeconds});

@DriftDatabase(
  tables: [
    Activities,
    Sessions,
    Segments,
    Prefs,
    Purchases,
    TodoCategories,
    Todos,
    Notes,
    CustomSkins,
  ],
)
class Db extends _$Db {
  Db() : super(driftDatabase(name: 'taime'));
  Db.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Activities stored a palette index; turn it into the colour the user
        // was actually looking at.
        final row = await customSelect(
          "SELECT value FROM prefs WHERE key = 'palette'",
        ).getSingleOrNull();
        final parsed = parsePalette(row?.read<String>('value') ?? '');
        final colors = parsed.isEmpty ? defaultPalette : parsed;
        final cases = [
          for (var i = 0; i < colors.length; i++) 'WHEN $i THEN ${colors[i]}',
        ].join(' ');
        await m.alterTable(
          TableMigration(
            activities,
            columnTransformer: {
              activities.color: CustomExpression<int>(
                'CASE (color_index % ${colors.length}) $cases END',
              ),
            },
            newColumns: [activities.color],
          ),
        );
        await m.addColumn(sessions, sessions.skinId);
        await m.createTable(purchases);
        await m.createTable(todoCategories);
        await m.createTable(todos);
      }
      if (from == 2) await m.addColumn(todos, todos.horizon);
      if (from < 3) {
        await m.createTable(notes);
        await m.createTable(customSkins);
      }
      if (from == 3) await m.addColumn(notes, notes.pinned);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.wasCreated) {
        await batch((b) {
          b.insertAll(activities, [
            ActivitiesCompanion.insert(
              name: 'Studio',
              color: activitySwatches[14],
              icon: const Value('book'),
              sort: const Value(0),
            ),
            ActivitiesCompanion.insert(
              name: 'Palestra',
              color: activitySwatches[9],
              icon: const Value('barbell'),
              sort: const Value(1),
            ),
            ActivitiesCompanion.insert(
              name: 'Pulizie',
              color: activitySwatches[3],
              icon: const Value('broom'),
              sort: const Value(2),
            ),
          ]);
        });
      }
      if (details.wasCreated || (details.versionBefore ?? 2) < 2) {
        await batch((b) {
          b.insertAll(todoCategories, [
            TodoCategoriesCompanion.insert(
              name: 'Personale',
              color: activitySwatches[16],
              sort: const Value(0),
            ),
            TodoCategoriesCompanion.insert(
              name: 'Studio',
              color: activitySwatches[14],
              sort: const Value(1),
            ),
            TodoCategoriesCompanion.insert(
              name: 'Casa',
              color: activitySwatches[3],
              sort: const Value(2),
            ),
          ]);
        });
      }
    },
  );

  // --- Activities -----------------------------------------------------------

  Stream<List<Activity>> watchActivities({bool includeArchived = false}) {
    final q = select(activities)
      ..where(
        (a) => includeArchived ? const Constant(true) : a.archived.equals(false),
      )
      ..orderBy([(a) => OrderingTerm(expression: a.sort)]);
    return q.watch();
  }

  Future<Activity?> activityById(int id) =>
      (select(activities)..where((a) => a.id.equals(id))).getSingleOrNull();

  // --- Sessions & segments --------------------------------------------------

  /// The session that has no end yet, if any.
  Stream<Session?> watchOpenSession() =>
      (select(sessions)..where((s) => s.endedAt.isNull())).watchSingleOrNull();

  Future<Session?> openSession() =>
      (select(sessions)..where((s) => s.endedAt.isNull())).getSingleOrNull();

  Future<Segment?> openSegment() =>
      (select(segments)..where((s) => s.endedAt.isNull())).getSingleOrNull();

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

  Stream<Session?> watchSession(int id) =>
      (select(sessions)..where((s) => s.id.equals(id))).watchSingleOrNull();

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

  /// Sessions that *started* in [from, to), each with its worked seconds.
  /// An open segment counts up to "now" at query time.
  Stream<List<SessionWork>> watchSessionWork(DateTime from, DateTime to) {
    return customSelect(
      'SELECT s.*, COALESCE(SUM(CASE WHEN g.is_pause = 0 THEN '
      "COALESCE(g.ended_at, CAST(strftime('%s','now') AS INTEGER)) - g.started_at "
      'END), 0) AS work '
      'FROM sessions s LEFT JOIN segments g ON g.session_id = s.id '
      'WHERE s.started_at >= ? AND s.started_at < ? '
      'GROUP BY s.id ORDER BY s.started_at',
      variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
      readsFrom: {sessions, segments},
    ).watch().map(
      (rows) => [
        for (final r in rows)
          (session: sessions.map(r.data), workSeconds: r.read<int>('work')),
      ],
    );
  }

  Future<void> updateSessionNote(int id, String note) =>
      (update(sessions)..where((s) => s.id.equals(id))).write(
        SessionsCompanion(note: Value(note)),
      );

  Future<void> deleteSession(int id) async {
    await (delete(segments)..where((s) => s.sessionId.equals(id))).go();
    await (delete(sessions)..where((s) => s.id.equals(id))).go();
  }

  Future<void> deleteSegment(int id) =>
      (delete(segments)..where((s) => s.id.equals(id))).go();

  /// Rewrites a session and keeps its start/end in step with its segments.
  Future<void> reshapeSession(int id) async {
    final segs = await segmentsOf(id);
    if (segs.isEmpty) return;
    final start = segs
        .map((s) => s.startedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
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
    String? skinId,
  }) async {
    final id = await into(sessions).insert(
      SessionsCompanion.insert(
        activityId: activityId,
        note: Value(note),
        startedAt: start,
        endedAt: Value(end),
        skinId: Value(skinId),
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

  // --- Crocchette -----------------------------------------------------------

  /// Seconds of finished work, all time.
  Stream<int> watchClosedWorkSeconds() => customSelect(
    'SELECT COALESCE(SUM(ended_at - started_at), 0) AS s FROM segments '
    'WHERE is_pause = 0 AND ended_at IS NOT NULL',
    readsFrom: {segments},
  ).watchSingle().map((r) => r.read<int>('s'));

  Stream<int> watchSpent() => customSelect(
    'SELECT COALESCE(SUM(price), 0) AS s FROM purchases',
    readsFrom: {purchases},
  ).watchSingle().map((r) => r.read<int>('s'));

  Stream<List<Purchase>> watchPurchases() => select(purchases).watch();

  // --- To-do ----------------------------------------------------------------

  Stream<List<Todo>> watchTodos() => (select(todos)
        ..orderBy([
          (t) => OrderingTerm(expression: t.sort),
          (t) => OrderingTerm(expression: t.id),
        ]))
      .watch();

  Future<List<Todo>> allTodos() => select(todos).get();

  Stream<List<TodoCategory>> watchTodoCategories() => (select(
    todoCategories,
  )..orderBy([(c) => OrderingTerm(expression: c.sort)])).watch();

  // --- Notes ----------------------------------------------------------------

  /// Pinned first, then newest first.
  Stream<List<Note>> watchNotes() => (select(notes)
        ..orderBy([
          (n) => OrderingTerm(expression: n.pinned, mode: OrderingMode.desc),
          (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<Note?> noteById(int id) => (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  // --- Custom kittens -------------------------------------------------------

  Stream<List<CustomSkin>> watchCustomSkins() => select(customSkins).watch();

  // --- Prefs ----------------------------------------------------------------

  Future<String?> pref(String key) async {
    final row = await (select(
      prefs,
    )..where((p) => p.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setPref(String key, String value) => into(
    prefs,
  ).insertOnConflictUpdate(PrefsCompanion.insert(key: key, value: value));

  Stream<Map<String, String>> watchPrefs() => select(
    prefs,
  ).watch().map((rows) => {for (final r in rows) r.key: r.value});

  Future<Map<String, String>> allPrefs() async => {
    for (final r in await select(prefs).get()) r.key: r.value,
  };

  /// Makes every open query re-run: another isolate (notification buttons)
  /// may have written to the file behind this connection's back.
  void refreshAll() => markTablesUpdated(allTables);
}
