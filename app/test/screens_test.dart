import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:time_tracker/app.dart';
import 'package:time_tracker/db.dart';
import 'package:time_tracker/pages/create_kitten.dart';
import 'package:time_tracker/pages/focus_page.dart';
import 'package:time_tracker/pages/overview_page.dart';
import 'package:time_tracker/pages/settings_page.dart';
import 'package:time_tracker/pages/shop_page.dart';
import 'package:time_tracker/pages/whats_new.dart';
import 'package:time_tracker/settings.dart';
import 'package:time_tracker/theme.dart';
import 'package:time_tracker/todo/todo_page.dart';
import 'package:time_tracker/tracker.dart';

/// Every main screen on a small phone, light and dark, with big text: no
/// layout errors (overflows show up as exceptions here) and no crashes.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('it');
    // The real font: the test font draws every letter as a wide square.
    final nunito = FontLoader('Nunito');
    for (final w in ['ExtraLight', 'Light', 'Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      nunito.addFont(Future.value(ByteData.sublistView(File('fonts/Nunito-$w.ttf').readAsBytesSync())));
    }
    await nunito.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(Future.value(ByteData.sublistView(File(
      '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync())));
    await icons.load();
    for (final name in ['dexterous.com/flutter/local_notifications', 'taime_native']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
  });

  Future<void> seed() async {
    final acts = await db.watchActivities().first;
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 2));
    await db.addManualSession(activityId: acts.first.id, start: start, end: now.subtract(const Duration(minutes: 30)), skinId: 'wendy');
    await db.into(db.todos).insert(TodosCompanion.insert(title: 'Un to-do con un titolo piuttosto lungo per vedere se va a capo', createdAt: DateTime(2026, 9, 1)));
    await db.into(db.todos).insert(TodosCompanion.insert(title: 'Scaduto', createdAt: DateTime(2026, 9, 1), due: Value(now.subtract(const Duration(days: 2)))));
    await db.into(db.notes).insert(NotesCompanion.insert(body: 'Spesa\n☐ latte\n☑ pane', createdAt: now, updatedAt: now, pinned: const Value(true), color: const Value(0xFFA9D18E)));
    await db.setPref('dailyGoalMin', '180');
  }

  Future<void> show(WidgetTester tester, Widget page, {bool dark = false, double textScale = 1}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = Settings(await tester.runAsync(db.allPrefs) ?? const {});
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        supportedLocales: const [Locale('it')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(s, dark: dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        // In the app every page sits in the Shell's Scaffold.
        home: Scaffold(body: page),
      ),
    );
    // Let the database streams deliver, then a few frames.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  late Db testDb;
  setUp(() async {
    testDb = Db.forTesting(NativeDatabase.memory());
    db = testDb;
    tracker = Tracker(db);
  });
  tearDown(() async {
    await testDb.close();
  });

  final pages = <String, Widget Function()>{
    'Focus': () => const FocusPage(settings: Settings({'dailyGoalMin': '180'})),
    'To-do': () => const TodoPage(settings: Settings.empty),
    'Panoramica': () => const OverviewPage(settings: Settings.empty),
    'Negozio': () => const ShopPage(settings: Settings.empty),
    'Impostazioni': () => const SettingsPage(),
  };

  for (final e in pages.entries) {
    for (final (dark, scale) in const [(false, 1.0), (true, 1.3)]) {
      testWidgets('${e.key} · ${dark ? 'scuro' : 'chiaro'} · testo ${scale}x', (tester) async {
        // Collect every layout error in full, with the widget that caused it.
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.toString());
        addTearDown(() => FlutterError.onError = old);
        await tester.runAsync(seed);
        await show(tester, e.value(), dark: dark, textScale: scale);
        // Scroll to the bottom: the lower cards get built too.
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -3000));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        FlutterError.onError = old;
        expect(errors, isEmpty, reason: errors.join('\n---\n'));
      }, timeout: const Timeout(Duration(seconds: 60)));
    }
  }

  testWidgets('Note, with a pinned checklist', (tester) async {
    await tester.runAsync(seed);
    listsView.value = ListsView.note;
    await show(tester, const TodoPage(settings: Settings.empty));
    expect(find.text('latte'), findsOneWidget);
    expect(tester.takeException(), isNull);
    listsView.value = ListsView.todo;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('Novità', (tester) async {
    await show(tester, Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => showWhatsNew(context), child: const Text('apri'))))));
    await tester.tap(find.text('apri'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Novità di Taime'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('Crea il tuo gattino', (tester) async {
    await show(tester, Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => openKittenMaker(context), child: const Text('apri'))))));
    await tester.tap(find.text('apri'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Crea il tuo gattino'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
