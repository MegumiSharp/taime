import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'db.dart';
import 'notif.dart';
import 'pages/log_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';
import 'pages/timer_page.dart';
import 'settings.dart';
import 'theme.dart';
import 'tracker.dart';

/// Runs in its own isolate when a notification button is tapped with the app
/// closed, so it opens its own database handle.
@pragma('vm:entry-point')
void onBackgroundNotification(NotificationResponse response) async {
  final bgDb = Db();
  await initTz();
  await Tracker(bgDb).handleAction(response.actionId);
  await bgDb.close();
}

void onForegroundNotification(NotificationResponse response) {
  tracker.handleAction(response.actionId);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it');
  await initNotifications(
    onTap: onForegroundNotification,
    onBackgroundTap: onBackgroundNotification,
  );
  await tracker.materialize();
  await tracker.sync();
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
    // Deadlines that fell due while we were away are applied on the way back in.
    _listener = AppLifecycleListener(
      onResume: () async {
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
          theme: buildTheme(s.palette, dark: false),
          darkTheme: buildTheme(s.palette, dark: true),
          themeMode: switch (s.themeMode) {
            'light' => ThemeMode.light,
            'system' => ThemeMode.system,
            _ => ThemeMode.dark,
          },
          home: Shell(settings: s),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.settings});
  final Settings settings;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final pages = [
      TimerPage(settings: s),
      LogPage(settings: s),
      StatsPage(settings: s),
      SettingsPage(settings: s),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: _NavBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.timer_rounded, Icons.timer_outlined, 'Timer'),
    (Icons.checklist_rounded, Icons.checklist_outlined, 'Registro'),
    (Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded, 'Statistiche'),
    (Icons.settings_rounded, Icons.settings_outlined, 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == index ? _items[i].$1 : _items[i].$2,
                          size: 24,
                          color: i == index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: i == index
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
