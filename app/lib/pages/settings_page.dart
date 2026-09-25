import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taime_native/taime_native.dart';

import '../app.dart';
import '../backup.dart';
import '../db.dart';
import '../icons.dart';
import '../notif.dart';
import '../palette.dart' as pal;
import '../settings.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';
import 'activity_picker.dart';
import 'gallery_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, String>>(
      stream: db.watchPrefs(),
      builder: (context, snap) {
        final s = Settings(snap.data ?? const {});
        return Scaffold(
          body: PastelBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                      const SizedBox(width: 4),
                      Text('Impostazioni', style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Section(title: 'Aspetto', children: [_Appearance(s: s)]),
                  _Section(title: 'Attività', children: [const _Activities()]),
                  _Section(title: 'Pause', children: [_Breaks(s: s)]),
                  _Section(title: 'Suono dei promemoria', children: [_Sounds(s: s)]),
                  _Section(title: 'Pomodoro', children: [_Pomodoro(s: s)]),
                  _Section(
                    title: 'Generale',
                    children: [
                      _Choice(
                        label: 'La settimana inizia',
                        value: s.weekStart,
                        options: const {1: 'Lunedì', 7: 'Domenica'},
                        onChanged: (v) => db.setPref('weekStart', '$v'),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Gattini',
                    children: [
                      _Row(
                        icon: Icons.pets_rounded,
                        title: 'Galleria',
                        subtitle: 'Tutti i gattini, in ogni posa e fase di crescita',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GalleryPage())),
                      ),
                    ],
                  ),
                  _Section(title: 'Backup', children: [const _Backup()]),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Taime 2.0 · i tuoi dati restano su questo telefono',
                      style: TextStyle(color: context.tc.muted, fontSize: 12.5),
                    ),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.value, required this.options, required this.onChanged});
  final String label;
  final int value;
  final Map<int, String> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        PopupMenuButton<int>(
          initialValue: value,
          onSelected: onChanged,
          itemBuilder: (_) => [for (final e in options.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: context.tc.raised, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(options[value] ?? options.values.first, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Aspetto ---------------------------------------------------------------------

class _Appearance extends StatefulWidget {
  const _Appearance({required this.s});
  final Settings s;

  @override
  State<_Appearance> createState() => _AppearanceState();
}

class _AppearanceState extends State<_Appearance> {
  final _coolors = TextEditingController();

  @override
  void dispose() {
    _coolors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final s = widget.s;
    final themes = [
      for (final e in kThemes.entries) (e.key, e.value.label, Color(pal.oklch(0.75, 0.09 * e.value.chroma, e.value.hue))),
      ('custom', 'Personalizzato', Color(pal.accentFor(s.palette.first, dark: false))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (id, label, color) in themes)
              Expanded(
                child: TapScale(
                  onTap: () {
                    Haptic.select();
                    db.setPref('theme', id);
                  },
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.medium),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: s.theme == id ? tc.accentSoft : tc.raised,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: s.theme == id ? tc.accent : Colors.transparent, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          child: s.theme == id ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        PillSelector<String>(
          values: const ['light', 'dark', 'system'],
          labels: const ['Chiaro', 'Scuro', 'Sistema'],
          selected: s.themeMode,
          onChanged: (v) => db.setPref('themeMode', v),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.curve,
          child: s.theme != 'custom'
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          for (final c in s.palette)
                            Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Color(pal.accentFor(c, dark: tc.dark)),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _coolors,
                        decoration: InputDecoration(
                          hintText: 'Incolla un link di coolors.co',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_rounded),
                            onPressed: () {
                              final colors = pal.parsePalette(_coolors.text);
                              if (colors.length < 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nessuna palette trovata')),
                                );
                                return;
                              }
                              db.setPref('palette', pal.paletteToString(colors));
                              _coolors.clear();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Il primo colore diventa il colore principale, ammorbidito perché resti leggibile.',
                        style: TextStyle(color: tc.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// --- Attività ---------------------------------------------------------------------

class _Activities extends StatelessWidget {
  const _Activities();

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return StreamBuilder<List<Activity>>(
      stream: db.watchActivities(includeArchived: true),
      builder: (context, snap) {
        final acts = snap.data ?? const <Activity>[];
        return Column(
          children: [
            for (final a in acts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: activitySoft(a.color, dark: tc.dark), shape: BoxShape.circle),
                  child: Icon(iconFor(a.icon), size: 20, color: activityColor(a.color, dark: tc.dark)),
                ),
                title: Text(
                  a.name,
                  style: TextStyle(decoration: a.archived ? TextDecoration.lineThrough : null),
                ),
                subtitle: a.archived ? const Text('Archiviata') : null,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showActivityEditor(context, activity: a),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: PillButton(
                label: 'Nuova attività',
                icon: Icons.add_rounded,
                kind: PillKind.soft,
                onTap: () => showActivityEditor(context),
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- Pause ------------------------------------------------------------------------

class _Breaks extends StatelessWidget {
  const _Breaks({required this.s});
  final Settings s;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Choice(
          label: 'Promemoria pausa dopo',
          value: s.breakAfterMin,
          options: const {0: 'Mai', 30: '30 min', 45: '45 min', 60: '1 ora', 90: '1h 30m', 120: '2 ore', 180: '3 ore'},
          onChanged: (v) => _set('breakAfterMin', '$v'),
        ),
        if (s.breakAfterMin > 0) ...[
          const SizedBox(height: 12),
          PillSelector<String>(
            values: const ['notify', 'auto'],
            labels: const ['Solo avviso', 'Pausa automatica'],
            selected: s.breakMode,
            onChanged: (v) => _set('breakMode', v),
          ),
          const SizedBox(height: 6),
          Text(
            s.breakMode == 'auto'
                ? 'Allo scadere il timer si ferma e parte la pausa: la notifica ti chiede se tenerla.'
                : 'Arriva solo una notifica, il timer continua.',
            style: TextStyle(color: tc.muted, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 12),
        _Choice(
          label: 'Fine pausa dopo',
          value: s.pauseReminderMin,
          options: const {0: 'Mai', 5: '5 min', 10: '10 min', 15: '15 min', 20: '20 min', 30: '30 min'},
          onChanged: (v) => _set('pauseReminderMin', '$v'),
        ),
      ],
    );
  }
}

Future<void> _set(String key, String value) async {
  await db.setPref(key, value);
  await tracker.sync();
}

// --- Suoni ------------------------------------------------------------------------

class _Sounds extends StatelessWidget {
  const _Sounds({required this.s});
  final Settings s;

  Future<void> _apply(String kind, String value, String name) async {
    await deleteReminderChannel(s);
    await db.setPref('soundKind', kind);
    await db.setPref('soundValue', value);
    await db.setPref('soundName', name);
    await tracker.sync();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Suona come una sveglia: si sente anche con il Non disturbare attivo, al volume della sveglia.',
          style: TextStyle(color: tc.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in kBundledSounds.entries)
              ChoiceChip(
                label: Text(e.value),
                showCheckmark: false,
                shape: const StadiumBorder(),
                selected: s.soundKind == 'bundled' && s.soundValue == e.key,
                onSelected: (_) async {
                  await _apply('bundled', e.key, e.value);
                  try {
                    await TaimeNative.previewSound('bundled', e.key);
                  } catch (_) {}
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        _Row(
          icon: Icons.library_music_rounded,
          title: 'Suoni del telefono',
          subtitle: s.soundKind == 'system' ? s.soundName : 'Sveglie, suonerie e notifiche',
          onTap: () async {
            try {
              final r = await TaimeNative.pickSystemSound(s.soundKind == 'system' ? s.soundValue : null);
              if (r != null) await _apply('system', r.uri, r.title);
            } catch (_) {}
          },
        ),
        _Row(
          icon: Icons.audio_file_rounded,
          title: 'Un mio file audio',
          subtitle: s.soundKind == 'file' ? s.soundName : 'Scegli un file dalla memoria',
          onTap: () async {
            final picked = (await FilePicker.pickFiles(type: FileType.audio)).firstOrNull;
            if (picked == null) return;
            final dir = Directory('${(await getApplicationSupportDirectory()).path}/sounds');
            if (!dir.existsSync()) dir.createSync(recursive: true);
            final safe = picked.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
            final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$safe');
            await file.writeAsBytes(await picked.xFile.readAsBytes());
            final uri = await TaimeNative.shareableUri(file.path);
            await _apply('file', uri, picked.name);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Suona finché non tocco'),
          subtitle: const Text('Come una sveglia, al massimo per un minuto'),
          value: s.soundLoop,
          onChanged: (v) async {
            await deleteReminderChannel(s);
            await _set('soundLoop', v ? '1' : '0');
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vibrazione'),
          value: s.soundVibrate,
          onChanged: (v) async {
            await deleteReminderChannel(s);
            await _set('soundVibrate', v ? '1' : '0');
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            PillButton(
              label: 'Prova suono',
              icon: Icons.notifications_active_rounded,
              kind: PillKind.soft,
              onTap: () => testReminderSound(s),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Ora in uso: ${s.soundName}',
                  style: TextStyle(color: tc.muted, fontSize: 12.5), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ],
    );
  }
}

// --- Pomodoro ---------------------------------------------------------------------

class _Pomodoro extends StatelessWidget {
  const _Pomodoro({required this.s});
  final Settings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Conto alla rovescia'),
          subtitle: const Text('Al posto del cronometro, con pause brevi'),
          value: s.pomodoro,
          onChanged: (v) => _set('pomodoro', v ? '1' : '0'),
        ),
        if (s.pomodoro) ...[
          _Choice(
            label: 'Lavoro',
            value: s.pomoWorkMin,
            options: const {15: '15 min', 25: '25 min', 30: '30 min', 45: '45 min', 50: '50 min'},
            onChanged: (v) => _set('pomoWorkMin', '$v'),
          ),
          const SizedBox(height: 10),
          _Choice(
            label: 'Pausa',
            value: s.pomoBreakMin,
            options: const {3: '3 min', 5: '5 min', 10: '10 min', 15: '15 min'},
            onChanged: (v) => _set('pomoBreakMin', '$v'),
          ),
        ],
      ],
    );
  }
}

// --- Backup -----------------------------------------------------------------------

class _Backup extends StatelessWidget {
  const _Backup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Row(
          icon: Icons.ios_share_rounded,
          title: 'Esporta backup (JSON)',
          subtitle: 'Tutto: sessioni, gattini, to-do. Reimportabile.',
          onTap: exportJson,
        ),
        _Row(
          icon: Icons.table_chart_rounded,
          title: 'Esporta CSV',
          subtitle: 'Per Excel o Fogli Google',
          onTap: exportCsv,
        ),
        _Row(
          icon: Icons.download_rounded,
          title: 'Importa backup',
          subtitle: 'Anche i backup della 1.0. Sostituisce i dati attuali.',
          onTap: () async {
            final ok = await confirm(
              context,
              title: 'Importare il backup?',
              message: 'Tutti i dati attuali verranno sostituiti da quelli del file.',
              action: 'Importa',
              danger: true,
            );
            if (!ok || !context.mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            final msg = await importJson();
            await tracker.sync();
            messenger.showSnackBar(SnackBar(content: Text(msg)));
          },
        ),
      ],
    );
  }
}
