import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import 'package:taime_native/taime_native.dart';

import '../app.dart';
import '../db.dart';
import '../notif.dart';
import '../ui/swatches.dart';
import 'recurrence.dart';

/// To-do writes that have side effects (reminders, recurrences) live here so
/// every screen does them the same way.

Future<void> syncTodoReminder(Todo t) async {
  try {
    if (t.completedAt != null || t.due == null || t.remindBefore == null) {
      await cancelTodoReminder(t.id);
      return;
    }
    final due = t.due!;
    final at = t.hasTime
        ? due.subtract(Duration(minutes: t.remindBefore!))
        : DateTime(due.year, due.month, due.day, 9);
    await scheduleTodoReminder(
      todoId: t.id,
      at: at,
      title: t.title,
      body: t.hasTime ? 'Alle ${DateFormat.Hm().format(due)}' : 'Oggi',
    );
  } catch (_) {
    // Reminders are a nicety; the list must keep working without them.
  }
}

Future<void> resyncTodoReminders() async {
  try {
    for (final t in await db.allTodos()) {
      if (t.remindBefore != null) await syncTodoReminder(t);
    }
  } catch (_) {}
}

Future<Todo?> todoById(int id) =>
    (db.select(db.todos)..where((t) => t.id.equals(id))).getSingleOrNull();

Future<int> addTodo(TodosCompanion c) async {
  final id = await db.into(db.todos).insert(c);
  final t = await todoById(id);
  if (t != null) await syncTodoReminder(t);
  return id;
}

Future<void> updateTodo(int id, TodosCompanion c) async {
  await (db.update(db.todos)..where((t) => t.id.equals(id))).write(c);
  final t = await todoById(id);
  if (t != null) await syncTodoReminder(t);
}

/// Returns an undo callback.
Future<Future<void> Function()> completeTodo(Todo t) async {
  final now = DateTime.now();
  await (db.update(db.todos)..where((x) => x.id.equals(t.id))).write(
    TodosCompanion(completedAt: Value(now)),
  );
  await cancelTodoReminder(t.id);

  int? nextId;
  if (t.recurrence != null && t.due != null) {
    final next = nextOccurrence(t.due!, t.recurrence!);
    nextId = await addTodo(
      TodosCompanion.insert(
        title: t.title,
        notes: Value(t.notes),
        categoryId: Value(t.categoryId),
        due: Value(next),
        hasTime: Value(t.hasTime),
        priority: Value(t.priority),
        recurrence: Value(t.recurrence),
        remindBefore: Value(t.remindBefore),
        sort: Value(t.sort),
        createdAt: now,
      ),
    );
    final subs = await (db.select(db.todos)..where((x) => x.parentId.equals(t.id))).get();
    for (final s in subs) {
      await db.into(db.todos).insert(
        TodosCompanion.insert(
          parentId: Value(nextId),
          title: s.title,
          createdAt: now,
          sort: Value(s.sort),
        ),
      );
    }
  }

  return () async {
    if (nextId != null) {
      await (db.delete(db.todos)..where((x) => x.id.equals(nextId!))).go();
      await cancelTodoReminder(nextId!);
    }
    await (db.update(db.todos)..where((x) => x.id.equals(t.id))).write(
      const TodosCompanion(completedAt: Value(null)),
    );
    final back = await todoById(t.id);
    if (back != null) await syncTodoReminder(back);
  };
}

Future<void> uncompleteTodo(Todo t) async {
  await (db.update(db.todos)..where((x) => x.id.equals(t.id))).write(
    const TodosCompanion(completedAt: Value(null)),
  );
  final back = await todoById(t.id);
  if (back != null) await syncTodoReminder(back);
}

/// Deletes a to-do and its subtasks. Returns an undo callback.
Future<Future<void> Function()> deleteTodo(Todo t) async {
  final subs = await (db.select(db.todos)..where((x) => x.parentId.equals(t.id))).get();
  await (db.delete(db.todos)..where((x) => x.id.equals(t.id) | x.parentId.equals(t.id))).go();
  await cancelTodoReminder(t.id);
  return () async {
    await db.into(db.todos).insert(t);
    for (final s in subs) {
      await db.into(db.todos).insert(s);
    }
    await syncTodoReminder(t);
  };
}

/// Moves the due date, keeping the time of day. Returns an undo callback.
Future<Future<void> Function()> postponeTodo(Todo t, DateTime day) async {
  final old = t.due;
  final h = t.hasTime ? old!.hour : 0, m = t.hasTime ? old!.minute : 0;
  await updateTodo(t.id, TodosCompanion(due: Value(DateTime(day.year, day.month, day.day, h, m))));
  return () => updateTodo(t.id, TodosCompanion(due: Value(old)));
}

/// Deletes the given completed to-dos and their subtasks. Returns an undo.
Future<Future<void> Function()> clearCompleted(List<Todo> done) async {
  final ids = [for (final t in done) t.id];
  final subs = await (db.select(db.todos)..where((x) => x.parentId.isIn(ids))).get();
  await (db.delete(db.todos)..where((x) => x.id.isIn(ids) | x.parentId.isIn(ids))).go();
  return () async {
    await db.batch((b) {
      b.insertAll(db.todos, done);
      b.insertAll(db.todos, subs);
    });
  };
}

/// Section names, in order: see [sectionOf].
const List<String> kHorizonNames = ['Oggi', 'Questa settimana', 'Più avanti'];

/// Where a to-do shows up: 0 oggi (and overdue), 1 this week, 2 later. Its
/// date decides; without one, the horizon picked when it was made.
int sectionOf(Todo t, DateTime now) => sectionFor(t.due, t.horizon, now);

int sectionFor(DateTime? due, int horizon, DateTime now) {
  if (due == null) return horizon.clamp(0, 2);
  // Rounded hours, so a DST change (a 23 h day) is still one day.
  final days = (DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inHours / 24).round();
  if (days <= 0) return 0;
  return days < 7 ? 1 : 2;
}

/// Finds a category by name (any case) or creates it.
Future<int> categoryIdFor(String name) async {
  final all = await db.select(db.todoCategories).get();
  final found = all.where((c) => c.name.toLowerCase() == name.toLowerCase()).firstOrNull;
  if (found != null) return found.id;
  return db.into(db.todoCategories).insert(
    TodoCategoriesCompanion.insert(
      name: name[0].toUpperCase() + name.substring(1),
      color: activitySwatches[(all.length * 5 + 2) % activitySwatches.length],
      sort: Value(all.length),
    ),
  );
}

/// "Oggi", "Domani", "Lunedì", "12 ott", with the time when it has one.
String dueLabel(DateTime due, bool hasTime, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final d = DateTime(due.year, due.month, due.day);
  final diff = (d.difference(today).inHours / 24).round();
  final day = switch (diff) {
    0 => 'Oggi',
    1 => 'Domani',
    -1 => 'Ieri',
    _ when diff > 1 && diff < 7 => _cap(DateFormat('EEEE', 'it').format(d)),
    _ => DateFormat('d MMM', 'it').format(d),
  };
  return hasTime ? '$day ${DateFormat.Hm().format(due)}' : day;
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Whole days between two moments' calendar dates (DST-proof).
int daysBetween(DateTime from, DateTime to) =>
    (DateTime(to.year, to.month, to.day).difference(DateTime(from.year, from.month, from.day)).inHours / 24).round();

/// A to-do with a date before today.
bool isOverdue(Todo t, DateTime now) => t.completedAt == null && t.due != null && daysBetween(now, t.due!) < 0;

/// List order: soonest first, then priority, then oldest.
int compareTodos(Todo a, Todo b) {
  final c = (a.due ?? DateTime(9999)).compareTo(b.due ?? DateTime(9999));
  if (c != 0) return c;
  final p = a.priority.compareTo(b.priority);
  return p != 0 ? p : a.id.compareTo(b.id);
}

/// Moves every overdue to-do to today, keeping its time. Returns an undo.
Future<Future<void> Function()> moveOverdueToToday(List<Todo> overdue) async {
  final now = DateTime.now();
  final undos = [for (final t in overdue) await postponeTodo(t, now)];
  return () async {
    for (final u in undos) {
      await u();
    }
  };
}

// --- Home-screen widget -------------------------------------------------------

/// Sends today's open to-dos to the home-screen widget.
Future<void> pushTodoWidget([List<Todo>? all]) async {
  try {
    final todos = all ?? await db.allTodos();
    final now = DateTime.now();
    final today = [
      for (final t in todos)
        if (t.parentId == null && t.completedAt == null && sectionOf(t, now) == 0) t,
    ]..sort(compareTodos);
    await TaimeSystem.todoWidgetUpdate([
      for (final t in today.take(5))
        (
          id: t.id,
          title: t.title,
          meta: t.due == null ? '' : dueLabel(t.due!, t.hasTime, now: now),
          late: isOverdue(t, now),
        ),
    ], today.length);
  } catch (_) {
    // No widget support (tests, old phones): nothing to do.
  }
}

/// Keeps the widget in step with every change to the list.
void watchTodoWidget() => db.watchTodos().listen(pushTodoWidget);

// --- Focus started from a to-do -------------------------------------------------

/// Remembers which to-do a focus session is for, to offer ticking it off at
/// the end. Any other start clears it.
Future<void> setFocusTodo(int? id) => db.setPref('focusTodo', id?.toString() ?? '');

Future<Todo?> focusTodo() async {
  final id = int.tryParse(await db.pref('focusTodo') ?? '');
  if (id == null) return null;
  final t = await todoById(id);
  return t == null || t.completedAt != null ? null : t;
}
