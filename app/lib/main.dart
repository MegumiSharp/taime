import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taime_native/taime_native.dart';

import 'app.dart';
import 'backup.dart';
import 'db.dart';
import 'kitten/art.dart';
import 'kitten/skins.dart';
import 'notif.dart';
import 'pages/focus_page.dart';
import 'pages/onboarding.dart';
import 'pages/overview_page.dart';
import 'pages/shop_page.dart';
import 'settings.dart';
import 'theme.dart';
import 'todo/notes.dart';
import 'todo/todo_page.dart';
import 'todo/todo_sync.dart';
import 'tracker.dart';
import 'ui/motion.dart';

/// Reminder buttons tapped with the app closed: runs in its own isolate with
/// its own database handle.
@pragma('vm:entry-point')
void onBackgroundNotification(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  final bgDb = Db();
  await initTz();
  await Tracker(bgDb).handleAction(response.actionId);
  await bgDb.close();
}

/// Live-notification buttons (pause / resume / stop) with no UI alive: the
/// native side boots an engine straight into this function.
@pragma('vm:entry-point')
Future<void> liveActionMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final bgDb = Db();
  try {
    await initNotifications(requestPermission: false);
    await Tracker(bgDb).handleAction(args.isEmpty ? null : args.first);
  } finally {
    await bgDb.close();
    await TaimeNative.backgroundDone();
  }
}

void onForegroundNotification(NotificationResponse response) {
  final payload = response.payload ?? '';
  if (payload.startsWith('todo:') || payload.startsWith('note:')) {
    listsView.value = payload.startsWith('note:') ? ListsView.note : ListsView.todo;
    shellTab.value = 1;
    return;
  }
  tracker.handleAction(response.actionId);
}

final navigatorKey = GlobalKey<NavigatorState>();

/// Which tab the shell shows; other screens can jump (e.g. "Vedi nel recinto").
final shellTab = ValueNotifier<int>(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it');
  await initNotifications(
    onTap: onForegroundNotification,
    onBackgroundTap: onBackgroundNotification,
  );
  try {
    await TaimeNative.registerUi((action) => tracker.handleAction(action));
  } catch (_) {}
  List<({int id, String name, String spec, bool deleted})> rows(List<CustomSkin> l) => [
    for (final c in l) (id: c.id, name: c.name, spec: c.spec, deleted: c.deleted),
  ];
  loadCustomSkins(rows(await db.select(db.customSkins).get()));
  db.watchCustomSkins().listen((l) => loadCustomSkins(rows(l)));
  await BalanceBuilder.warmUp();
  final prefs = Settings(await db.allPrefs());
  if (await db.pref('fullScreenAsked') == null) {
    await db.setPref('fullScreenAsked', '1');
    await requestFullScreenAlerts();
  }
  await ensureKittenArt(prefs.activeSkin);
  await tracker.materialize();
  await tracker.sync();
  resyncTodoReminders();
  resyncNoteReminders();
  maybeAutoBackup();
  runApp(const TaimeApp());
}

class TaimeApp extends StatefulWidget {
  const TaimeApp({super.key});

  @override
  State<TaimeApp> createState() => _TaimeAppState();
}

class _TaimeAppState extends State<TaimeApp> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Future.delayed(const Duration(milliseconds: 600), _maybeOnboard));
    _listener = AppLifecycleListener(
      onHide: () async {
        final session = await db.openSession();
        final seg = await db.openSegment();
        if (session == null || seg == null || seg.isPause) return;
        final act = await db.activityById(session.activityId);
        await scheduleAwayReminder(
          at: DateTime.now().add(const Duration(minutes: 15)),
          activity: act?.name ?? 'Il focus',
        );
      },
      onResume: () async {
        await cancelAwayReminder();
        maybeAutoBackup();
        // Another isolate (notification buttons) may have changed the file.
        db.refreshAll();
        await tracker.materialize();
        await tracker.sync();
      },
    );
  }

  Future<void> _maybeOnboard() async {
    if (await db.pref('onboarded') != null) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await db.setPref('onboarded', '1');
    if (ctx.mounted) await showOnboarding(ctx);
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, String>>(
      stream: db.watchPrefs(),
      builder: (context, snap) {
        final s = Settings(snap.data ?? const {});
        return MaterialApp(
          title: 'Taime',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: const Locale('it'),
          supportedLocales: const [Locale('it'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(s, dark: false),
          darkTheme: buildTheme(s, dark: true),
          themeAnimationDuration: Motion.slow,
          themeAnimationCurve: Motion.curve,
          themeMode: switch (s.themeMode) {
            'dark' => ThemeMode.dark,
            'system' => ThemeMode.system,
            _ => ThemeMode.light,
          },
          home: Shell(settings: s),
        );
      },
    );
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key, required this.settings});
  final Settings settings;

  static const _items = [
    (Icons.spa_rounded, Icons.spa_outlined, 'Focus'),
    (Icons.task_alt_rounded, Icons.task_alt_outlined, 'To-do e note'),
    (Icons.grid_view_rounded, Icons.grid_view_outlined, 'Panoramica'),
    (Icons.storefront_rounded, Icons.storefront_outlined, 'Negozio'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (context, tab, _) {
        final pages = [
          FocusPage(settings: settings),
          TodoPage(settings: settings),
          OverviewPage(settings: settings),
          ShopPage(settings: settings),
        ];
        return Scaffold(
          extendBody: true,
          body: AnimatedSwitcher(
            duration: Motion.of(context, Motion.medium),
            switchInCurve: Motion.curve,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.985, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
          ),
          bottomNavigationBar: _NavBar(
            index: tab,
            onChanged: (i) {
              if (i != tab) Haptic.select();
              shellTab.value = i;
            },
          ),
        );
      },
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final n = Shell._items.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 12),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: tc.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(31),
            boxShadow: [
              BoxShadow(
                color: tc.shadow(1.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A soft blob that slides under the selected icon.
              AnimatedAlign(
                duration: Motion.of(context, Motion.slow),
                curve: Motion.emphasized,
                alignment: Alignment(-1 + 2 * index / (n - 1), 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tc.accentSoft,
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Semantics(
                        label: Shell._items[i].$3,
                        selected: i == index,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: SizedBox(
                            height: 62,
                            child: AnimatedScale(
                              scale: i == index ? 1.08 : 1,
                              duration: Motion.of(context, Motion.medium),
                              curve: Motion.spring,
                              child: Icon(
                                i == index ? Shell._items[i].$1 : Shell._items[i].$2,
                                size: 25,
                                color: i == index ? tc.text : tc.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
