import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taime_native/taime_native.dart';

import '../app.dart';
import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../notif.dart' show kBundledSounds;
import '../settings.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';
import '../water.dart';
import 'settings_page.dart' show ChoiceRow, SettingsSection;

/// One line for the Settings list.
String waterSettingsSummary(Settings s) {
  if (!s.waterOn) return 'Spento';
  final every = fmtHm(Duration(minutes: s.waterEvery));
  return s.waterMode == 'focus'
      ? 'Ogni $every durante il focus · ${s.waterGoal} bicchieri'
      : 'Ogni $every, ${_hm(s.waterFrom)}–${_hm(s.waterTo)} · ${s.waterGoal} bicchieri';
}

String _hm(int minutes) => '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

const _days = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
const _dayNames = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];

Future<void> _set(String key, String value) async {
  await db.setPref(key, value);
  await pushWater();
}

/// Impostazioni → Acqua, and "Prossimo promemoria" in the glasses sheet.
class WaterPage extends StatefulWidget {
  const WaterPage({super.key});

  @override
  State<WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends State<WaterPage> {
  TextEditingController? _text;
  Timer? _save;

  @override
  void dispose() {
    _save?.cancel();
    _text?.dispose();
    super.dispose();
  }

  void _onText(String v) {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 500), () => _set('waterText', v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, String>>(
      stream: db.watchPrefs(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: PastelBackground(child: SizedBox.expand()));
        final s = Settings(snap.data!);
        _text ??= TextEditingController(text: s.waterText);
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
                      Text('Bevi acqua', style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Today(s: s),
                  const SizedBox(height: 14),
                  SettingsSection(title: 'Promemoria', children: [_Reminders(s: s)]),
                  SettingsSection(
                    title: 'Obiettivo',
                    children: [
                      ChoiceRow(
                        label: 'Bicchieri al giorno',
                        value: s.waterGoal,
                        options: {for (var i = 1; i <= 16; i++) i: '$i'},
                        onChanged: (v) => _set('waterGoal', '$v'),
                      ),
                      const SizedBox(height: 10),
                      ChoiceRow(
                        label: 'Un bicchiere',
                        value: s.waterGlass,
                        options: const {150: '150 ml', 200: '200 ml', 250: '250 ml', 300: '300 ml', 330: '330 ml', 400: '400 ml', 500: '500 ml'},
                        onChanged: (v) => _set('waterGlass', '$v'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'In tutto ${waterSummary(s.waterGoal, s).split('· ').last} al giorno. '
                        'Raggiunto l\'obiettivo, per oggi i promemoria tacciono.',
                        style: TextStyle(color: context.tc.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Notifica',
                    children: [
                      TextField(
                        controller: _text,
                        onChanged: _onText,
                        maxLength: 60,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Messaggio',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'È ora di bere un po\' d\'acqua',
                        ),
                      ),
                      const SizedBox(height: 4),
                      ChoiceRow(
                        label: 'Suono',
                        value: s.waterSound,
                        options: {
                          'default': 'Notifiche del telefono',
                          ...kBundledSounds,
                          'vibrate': 'Solo vibrazione',
                          'silent': 'Silenzioso',
                        },
                        onChanged: (v) => _set('waterSound', v),
                      ),
                      const SizedBox(height: 14),
                      PillButton(
                        label: 'Prova tra 10 secondi',
                        icon: Icons.lock_clock_rounded,
                        kind: PillKind.soft,
                        expand: true,
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await pushWater();
                          await TaimeSystem.waterTest();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Blocca il telefono: tra 10 secondi lo schermo si accende con il promemoria.'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Accende lo schermo e mostra la notifica sul blocco schermo, con "Ho bevuto" e "Più tardi". '
                        'Il timer non si ferma mai.',
                        style: TextStyle(color: context.tc.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The kitten, today's glasses and the buttons to count them.
class _Today extends StatelessWidget {
  const _Today({required this.s});
  final Settings s;

  @override
  Widget build(BuildContext context) {
    final n = s.waterCount(DateTime.now());
    return SoftCard(
      child: Column(
        children: [
          SizedBox(
            height: 96,
            width: 110,
            child: Stack(
              children: [
                KittenView(skin: skinById(s.activeSkin), size: 96),
                const Positioned(
                  right: 0,
                  bottom: 4,
                  child: Icon(Icons.water_drop_rounded, color: kWaterBlue, size: 30),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          WaterGlasses(count: n, goal: s.waterGoal),
          const SizedBox(height: 8),
          Text(waterSummary(n, s), style: TextStyle(color: context.tc.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Togli un bicchiere',
                onPressed: n > 0 ? () => addWater(-1) : null,
                icon: const Icon(Icons.remove_rounded),
                style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  backgroundColor: kWaterBlue.withValues(alpha: 0.16),
                  foregroundColor: kWaterBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PillButton(
                  label: 'Ho bevuto',
                  icon: Icons.water_drop_rounded,
                  expand: true,
                  color: kWaterBlue,
                  onTap: () {
                    Haptic.light();
                    addWater(1);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Reminders extends StatelessWidget {
  const _Reminders({required this.s});
  final Settings s;

  Future<void> _time(BuildContext context, String key, int current) async {
    final p = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (p != null) await _set(key, '${p.hour * 60 + p.minute}');
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final days = s.waterDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ricordami di bere', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Mostra anche i bicchieri di oggi nel Focus'),
          value: s.waterOn,
          onChanged: (v) => _set('waterOn', v ? '1' : '0'),
        ),
        if (s.waterOn) ...[
          const SizedBox(height: 8),
          PillSelector<String>(
            values: const ['always', 'focus'],
            labels: const ['Negli orari', 'Solo in focus'],
            selected: s.waterMode,
            onChanged: (v) => _set('waterMode', v),
          ),
          const SizedBox(height: 6),
          Text(
            s.waterMode == 'focus'
                ? 'Durante una sessione, pause comprese. A timer fermo non suona.'
                : 'Negli orari e nei giorni scelti, anche a timer fermo.',
            style: TextStyle(color: tc.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          ChoiceRow(
            label: 'Ogni',
            value: s.waterEvery,
            options: const {15: '15 min', 20: '20 min', 30: '30 min', 45: '45 min', 60: '1 ora', 90: '1h 30m', 120: '2 ore', 180: '3 ore'},
            onChanged: (v) => _set('waterEvery', '$v'),
          ),
          if (s.waterMode == 'always') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Dalle · alle', style: TextStyle(fontWeight: FontWeight.w600))),
                _TimeChip(label: _hm(s.waterFrom), semantics: 'Dalle', onTap: () => _time(context, 'waterFrom', s.waterFrom)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                _TimeChip(label: _hm(s.waterTo), semantics: 'Alle', onTap: () => _time(context, 'waterTo', s.waterTo)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var d = 1; d <= 7; d++)
                  Semantics(
                    label: _dayNames[d - 1],
                    selected: days.contains(d),
                    child: SoftChip(
                      label: _days[d - 1],
                      selected: days.contains(d),
                      onTap: () {
                        final next = days.contains(d) ? (days.toSet()..remove(d)) : {...days, d};
                        _set('waterDays', (next.toList()..sort()).join());
                      },
                    ),
                  ),
              ],
            ),
            if (days.isEmpty) ...[
              const SizedBox(height: 6),
              Text('Nessun giorno scelto: i promemoria non suonano.', style: TextStyle(color: tc.muted, fontSize: 12.5)),
            ],
          ],
          const SizedBox(height: 12),
          ChoiceRow(
            label: '"Più tardi" rimanda di',
            value: s.waterSnooze,
            options: const {5: '5 min', 10: '10 min', 15: '15 min', 30: '30 min', 60: '1 ora'},
            onChanged: (v) => _set('waterSnooze', '$v'),
          ),
        ],
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.semantics, required this.onTap});
  final String label, semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$semantics $label',
    excludeSemantics: true,
    button: true,
    onTap: onTap,
    child: TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: context.tc.raised, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
  );
}
