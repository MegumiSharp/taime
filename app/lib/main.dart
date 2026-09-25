import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taime_native/taime_native.dart';

import 'app.dart';
import 'db.dart';
import 'kitten/art.dart';
import 'notif.dart';
import 'pages/focus_page.dart';
import 'pages/overview_page.dart';
import 'pages/shop_page.dart';
import 'settings.dart';
import 'theme.dart';
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
  if (payload.startsWith('todo:')) {
    shellTab.value = 1;
    return;
  }
  tracker.handleAction(response.actionId);
}

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
  final prefs = Settings(await db.allPrefs());
  await ensureKittenArt(prefs.activeSkin);
  await tracker.materialize();
  await tracker.sync();
  resyncTodoReminders();
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
    _listener = AppLifecycleListener(
      onResume: () async {
        // Another isolate (notification buttons) may have changed the file.
        db.refreshAll();
        await tracker.materialize();
        await tracker.sync();
      },
    );
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
    (Icons.task_alt_rounded, Icons.task_alt_outlined, 'To-do'),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Container(
          height: 66,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: tc.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: tc.text.withValues(alpha: tc.dark ? 0.3 : 0.09),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < Shell._items.length; i++)
                Expanded(
                  flex: i == index ? 14 : 10,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: Motion.of(context, Motion.medium),
                      curve: Motion.emphasized,
                      decoration: BoxDecoration(
                        color: i == index ? tc.accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == index ? Shell._items[i].$1 : Shell._items[i].$2,
                            size: 23,
                            color: i == index ? tc.text : tc.muted,
                          ),
                          AnimatedSize(
                            duration: Motion.of(context, Motion.medium),
                            curve: Motion.emphasized,
                            child: i == index
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text(
                                      Shell._items[i].$3,
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: tc.text,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
