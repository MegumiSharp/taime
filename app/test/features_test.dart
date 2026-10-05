import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show AndroidFlutterLocalNotificationsPlugin;
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app.dart';
import 'package:time_tracker/db.dart';
import 'package:time_tracker/notif.dart' show kPauseEndId, kReminderId;
import 'package:time_tracker/theme.dart';
import 'package:time_tracker/todo/checklist.dart';
import 'package:time_tracker/todo/notes.dart';
import 'package:time_tracker/todo/todo_page.dart' show matchesQuery;
import 'package:time_tracker/todo/todo_sync.dart';
import 'package:time_tracker/tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Notifications and the widget are native: answer every call with "ok".
  setUpAll(() {
    for (final name in ['dexterous.com/flutter/local_notifications', 'taime_native']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
  });

  setUp(() {
    db = Db.forTesting(NativeDatabase.memory());
    tracker = Tracker(db);
  });
  tearDown(() => db.close());

  Future<int> todo(String title, {DateTime? due, bool hasTime = false, int horizon = 0, DateTime? done}) => db
      .into(db.todos)
      .insert(
        TodosCompanion.insert(
          title: title,
          createdAt: DateTime(2026, 9, 1),
          due: Value(due),
          hasTime: Value(hasTime),
          horizon: Value(horizon),
          completedAt: Value(done),
        ),
      );

  group('checklists in notes', () {
    test('a tap ticks and unticks one line', () {
      const body = 'Spesa\n☐ latte\n☐ pane';
      final once = toggleLine(body, 1);
      expect(once, 'Spesa\n☑ latte\n☐ pane');
      expect(toggleLine(once, 1), body);
      expect(toggleLine(body, 0), body); // the title is not a box
    });

    test('the button adds or removes the box on the current line', () {
      final v = toggleBoxAtCursor(
        const TextEditingValue(text: 'Spesa\nlatte', selection: TextSelection.collapsed(offset: 9)),
      );
      expect(v.text, 'Spesa\n☐ latte');
      expect(toggleBoxAtCursor(v).text, 'Spesa\nlatte');
    });

    test('Enter continues the list, Enter on an empty item ends it', () {
      final f = ChecklistFormatter();
      const before = TextEditingValue(text: '☐ latte', selection: TextSelection.collapsed(offset: 7));
      final next = f.formatEditUpdate(
        before,
        const TextEditingValue(text: '☐ latte\n', selection: TextSelection.collapsed(offset: 8)),
      );
      expect(next.text, '☐ latte\n☐ ');
      final ended = f.formatEditUpdate(
        next,
        const TextEditingValue(text: '☐ latte\n☐ \n', selection: TextSelection.collapsed(offset: 11)),
      );
      expect(ended.text, '☐ latte\n');
      // Plain lines are left alone.
      final plain = f.formatEditUpdate(
        const TextEditingValue(text: 'ciao', selection: TextSelection.collapsed(offset: 4)),
        const TextEditingValue(text: 'ciao\n', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(plain.text, 'ciao\n');
    });
  });

  test('durations read naturally', () {
    expect(fmtHm(const Duration(minutes: 45)), '45m');
    expect(fmtHm(const Duration(hours: 3)), '3h');
    expect(fmtHm(const Duration(hours: 1, minutes: 11)), '1h 11m');
  });

  test('search ignores case and accents', () {
    expect(matchesQuery('Comprare il caffè', 'CAFFE'), isTrue);
    expect(matchesQuery('Palestra', 'studio'), isFalse);
    expect(matchesQuery('qualsiasi', '  '), isTrue);
  });

  test('the app version matches pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.substring(8).trim().split('+').first, kAppVersion);
  });

  test('"Svuota" deletes the completed to-dos with their subtasks, and undo brings them back', () async {
    final a = await todo('fatto', done: DateTime(2026, 9, 2));
    await db.into(db.todos).insert(TodosCompanion.insert(title: 'sotto', parentId: Value(a), createdAt: DateTime(2026)));
    await todo('aperto');
    final done = (await db.allTodos()).where((t) => t.completedAt != null).toList();
    final undo = await clearCompleted(done);
    expect((await db.allTodos()).map((t) => t.title), ['aperto']);
    await undo();
    expect((await db.allTodos()).map((t) => t.title).toSet(), {'fatto', 'sotto', 'aperto'});
  });

  test('"Tutti a oggi" moves overdue to-dos to today, keeping their time', () async {
    final now = DateTime.now();
    await todo('ieri', due: DateTime(now.year, now.month, now.day - 1, 18), hasTime: true);
    await todo('senza data');
    final all = await db.allTodos();
    final overdue = all.where((t) => isOverdue(t, now)).toList();
    expect(overdue.map((t) => t.title), ['ieri']);
    final undo = await moveOverdueToToday(overdue);
    final moved = (await db.allTodos()).firstWhere((t) => t.title == 'ieri');
    expect(moved.due, DateTime(now.year, now.month, now.day, 18));
    expect(sectionOf(moved, now), 0);
    await undo();
    expect((await db.allTodos()).firstWhere((t) => t.title == 'ieri').due!.day, DateTime(now.year, now.month, now.day - 1).day);
  });

  test('a focus started from a to-do remembers it; any other start forgets it', () async {
    final acts = await db.watchActivities().first;
    final id = await todo('capitolo 3');
    await tracker.start(acts.first.id, note: 'capitolo 3', todoId: id);
    expect((await focusTodo())?.title, 'capitolo 3');
    await tracker.start(acts.first.id);
    expect(await focusTodo(), isNull);
    await tracker.start(acts.first.id, todoId: id);
    await completeTodo((await todoById(id))!);
    expect(await focusTodo(), isNull); // already done: nothing to ask
    await tracker.stop();
  });

  test('a deleted note comes back with undo', () async {
    final id = await db.into(db.notes).insert(
      NotesCompanion.insert(body: 'idea\n☐ uno', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    );
    final undo = await deleteNote((await db.noteById(id))!);
    expect(await db.noteById(id), isNull);
    await undo();
    expect((await db.noteById(id))!.body, 'idea\n☐ uno');
  });

  test('pinned notes come first', () async {
    await db.into(db.notes).insert(NotesCompanion.insert(body: 'vecchia', createdAt: DateTime(2026, 1), updatedAt: DateTime(2026, 1), pinned: const Value(true)));
    await db.into(db.notes).insert(NotesCompanion.insert(body: 'nuova', createdAt: DateTime(2026, 9), updatedAt: DateTime(2026, 9)));
    expect((await db.watchNotes().first).map((n) => n.body), ['vecchia', 'nuova']);
  });

  test('ticking a to-do from the widget works without the app', () async {
    final id = await todo('widget');
    final t = (await todoById(id))!;
    await completeTodo(t);
    await pushTodoWidget(); // must not throw even with nothing on screen
    expect((await todoById(id))!.completedAt, isNotNull);
  });

  test('scheduled reminders and their buttons have receivers', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final r in ['ScheduledNotificationReceiver', 'ScheduledNotificationBootReceiver', 'ActionBroadcastReceiver']) {
      expect(manifest, contains('com.dexterous.flutterlocalnotifications.$r'));
    }
  });

  test('the auto-pause alarm survives the pause it starts', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    const notif = MethodChannel('dexterous.com/flutter/local_notifications');
    messenger.setMockMethodCallHandler(notif, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_timezone'), (_) async => 'Europe/Rome');
    addTearDown(() => messenger.setMockMethodCallHandler(notif, (_) async => null));
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    List<Object?> ids(String method) => [for (final c in calls.where((c) => c.method == method)) (c.arguments as Map)['id']];

    await db.setPref('breakMode', 'auto');
    await db.setPref('breakAfterMin', '50');
    await tracker.start((await db.watchActivities().first).first.id);
    expect(ids('zonedSchedule'), contains(kReminderId));

    // The deadline falls due and the live service sends "tick".
    final seg = (await db.openSegment())!;
    await (db.update(db.segments)..where((x) => x.id.equals(seg.id)))
        .write(SegmentsCompanion(deadlineAt: Value(DateTime.now().subtract(const Duration(seconds: 1)))));
    calls.clear();
    await tracker.handleAction('tick');
    expect((await db.openSegment())!.isPause, isTrue);
    expect(ids('cancel'), isNot(contains(kReminderId)));
    expect(ids('zonedSchedule'), contains(kPauseEndId));
    await tracker.stop();
  });
}
