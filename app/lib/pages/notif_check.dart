import 'package:flutter/material.dart';
import 'package:taime_native/taime_native.dart';

import '../app.dart';
import '../notif.dart';
import '../settings.dart';
import '../theme.dart';
import '../ui/widgets.dart';

/// Impostazioni → Controlla le notifiche: what Android lets Taime do, a
/// one-tap fix for each problem, and real tests (a reminder now, a pause in
/// 10 seconds with the screen off).
class NotificationCheckPage extends StatefulWidget {
  const NotificationCheckPage({super.key});

  @override
  State<NotificationCheckPage> createState() => _NotificationCheckPageState();
}

class _Check {
  const _Check(this.title, this.ok, this.okText, this.badText, this.fix, {this.warn = false});
  final String title;
  final bool ok;
  final String okText, badText;

  /// The system page that fixes it; null when nothing can be done here.
  final Future<void> Function()? fix;

  /// Not blocking, just worse (e.g. no heads-up).
  final bool warn;
}

class _NotificationCheckPageState extends State<NotificationCheckPage> {
  late final AppLifecycleListener _life;
  NotificationHealth? _health;
  Settings _s = Settings.empty;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    // Coming back from a system page: look again.
    _life = AppLifecycleListener(onResume: _load);
    _load();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final h = await TaimeSystem.notificationStatus();
      final s = Settings(await db.allPrefs());
      if (mounted) {
        setState(() {
          _health = h;
          _s = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Non riesco a leggere lo stato delle notifiche su questo telefono.');
    }
  }

  List<_Check> _checks(NotificationHealth h) {
    ({String name, int importance})? ch(String id) => h.channels[id];
    // Android importance: 0 off, 3 default (no pop-up), 4+ high (pops up).
    _Check channel(String id, String title, {bool needsPopup = true}) {
      final c = ch(id);
      if (c == null) {
        return _Check(title, true, 'Si attiva alla prima notifica', '', null);
      }
      if (c.importance == 0) {
        return _Check(title, false, '', 'Disattivate', () => TaimeSystem.openSettings('channel', channel: id));
      }
      if (needsPopup && c.importance < 4) {
        return _Check(
          title,
          false,
          '',
          'Non compaiono in alto: attiva "Mostra sullo schermo"',
          () => TaimeSystem.openSettings('channel', channel: id),
          warn: true,
        );
      }
      return _Check(title, true, 'Attive', '', () => TaimeSystem.openSettings('channel', channel: id));
    }

    return [
      _Check('Notifiche di Taime', h.enabled, 'Permesse', 'Bloccate: senza questo non arriva niente', () async {
        await askNotificationPermission();
        await TaimeSystem.openSettings('notifications');
      }),
      channel(reminderChannelId(_s), 'Pause e pomodoro'),
      channel('taime_focus', 'Timer in corso', needsPopup: false),
      channel('todo', 'Promemoria dei to-do'),
      channel('note', 'Promemoria delle note'),
      _Check(
        'Sveglie precise',
        h.exactAlarms,
        'Permesse: i promemoria arrivano al minuto',
        'Non permesse: i promemoria possono arrivare in ritardo',
        () => TaimeSystem.openSettings('exact'),
      ),
      _Check(
        'Schermo che si accende',
        h.fullScreen,
        'Permesso',
        'Non permesso: la pausa non accende lo schermo',
        () => TaimeSystem.openSettings('fullScreen'),
      ),
      _Check(
        'Batteria',
        h.batteryUnrestricted,
        'Nessuna restrizione',
        'Ottimizzata: il telefono può ritardare o bloccare i promemoria',
        () => TaimeSystem.openSettings('battery'),
        warn: true,
      ),
    ];
  }

  Future<void> _run(Future<void> Function() test, String message) async {
    try {
      await test();
      if (mounted) setState(() => _message = message);
    } catch (e) {
      if (mounted) setState(() => _message = 'La prova non è partita: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final h = _health;
    final checks = h == null ? const <_Check>[] : _checks(h);
    final problems = checks.where((c) => !c.ok).length;
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Indietro',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Notifiche', style: Theme.of(context).textTheme.headlineSmall)),
                  IconButton(tooltip: 'Controlla di nuovo', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null)
                SoftCard(child: Text(_error!))
              else if (h == null)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                SoftCard(
                  color: problems == 0 ? tc.accentSoft : tc.pauseSoft,
                  child: Row(
                    children: [
                      Icon(
                        problems == 0 ? Icons.verified_rounded : Icons.report_rounded,
                        color: problems == 0 ? tc.accent : tc.pause,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          problems == 0
                              ? 'Tutto a posto. Fai una prova qui sotto per esserne sicuro.'
                              : problems == 1
                              ? 'C\'è una cosa da sistemare. Tocca "Sistema" e poi torna qui.'
                              : 'Ci sono $problems cose da sistemare. Tocca "Sistema" e poi torna qui.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                  child: Column(children: [for (final c in checks) _CheckRow(check: c)]),
                ),
                if (h.xiaomi) ...[
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Su Xiaomi, Redmi e POCO', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          'MIUI e HyperOS spengono di base alcune cose che il controllo non può vedere. '
                          'Attiva "Avvio automatico" e, nelle notifiche di Taime, "Schermata di blocco" e '
                          '"Notifiche mobili".',
                          style: TextStyle(color: tc.muted, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SoftChip(
                              label: 'Avvio automatico',
                              icon: Icons.rocket_launch_rounded,
                              onTap: () => TaimeSystem.openSettings('autostart'),
                            ),
                            SoftChip(
                              label: 'Notifiche di Taime',
                              icon: Icons.notifications_rounded,
                              onTap: () => TaimeSystem.openSettings('notifications'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Prova', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      PillButton(
                        label: 'Promemoria adesso',
                        icon: Icons.notifications_active_rounded,
                        kind: PillKind.soft,
                        expand: true,
                        onTap: () =>
                            _run(() => testReminderSound(_s), 'Inviato: dovresti sentire il suono delle pause.'),
                      ),
                      const SizedBox(height: 10),
                      PillButton(
                        label: 'Pausa tra 10 secondi',
                        icon: Icons.lock_clock_rounded,
                        expand: true,
                        onTap: () => _run(
                          () => testPauseReminder(_s),
                          'Ora blocca il telefono: tra 10 secondi lo schermo si accende e suona, come una sveglia.',
                        ),
                      ),
                      const SizedBox(height: 10),
                      PillButton(
                        label: 'Promemoria di un to-do',
                        icon: Icons.task_alt_rounded,
                        kind: PillKind.soft,
                        expand: true,
                        onTap: () => _run(testTodoNotification, 'Inviato: è il suono normale delle notifiche.'),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(_message!, style: TextStyle(color: tc.muted, height: 1.4)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final _Check check;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final c = check;
    final color = c.ok ? tc.accent : (c.warn ? tc.pause : tc.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            c.ok ? Icons.check_circle_rounded : (c.warn ? Icons.error_outline_rounded : Icons.cancel_rounded),
            color: color,
            semanticLabel: c.ok ? 'a posto' : 'da sistemare',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(c.ok ? c.okText : c.badText, style: TextStyle(color: tc.muted, fontSize: 13)),
              ],
            ),
          ),
          if (c.fix != null) TextButton(onPressed: c.fix, child: Text(c.ok ? 'Apri' : 'Sistema')),
        ],
      ),
    );
  }
}
