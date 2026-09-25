import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app.dart';
import '../backup.dart';
import '../db.dart';
import '../icons.dart';
import '../palette.dart' as pal;
import '../settings.dart';
import '../theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Impostazioni',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Aspetto',
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'dark', label: Text('Scuro')),
                ButtonSegment(value: 'light', label: Text('Chiaro')),
                ButtonSegment(value: 'system', label: Text('Sistema')),
              ],
              selected: {s.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => db.setPref('themeMode', v.first),
            ),
            const SizedBox(height: 16),
            _PaletteField(settings: s),
          ],
        ),

        _Section(
          title: 'Attività',
          children: [
            StreamBuilder<List<Activity>>(
              stream: db.watchActivities(includeArchived: true),
              builder: (context, snap) {
                final acts = snap.data ?? const <Activity>[];
                return Column(
                  children: [
                    for (final a in acts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          iconFor(a.icon),
                          color: activityColor(
                            a.colorIndex,
                            s.palette,
                            dark: theme.brightness == Brightness.dark,
                          ),
                        ),
                        title: Text(
                          a.name,
                          style: TextStyle(
                            decoration: a.archived
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: a.archived ? const Text('Archiviata') : null,
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                        ),
                        onTap: () => _editActivity(context, s, a),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _editActivity(context, s, null),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nuova attività'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),

        _Section(
          title: 'Pause',
          children: [
            _Choice(
              label: 'Avvisami dopo',
              value: s.breakAfterMin,
              options: const {
                0: 'Mai',
                30: '30 min',
                45: '45 min',
                60: '1 ora',
                90: '1h 30m',
                120: '2 ore',
                180: '3 ore',
              },
              onChanged: (v) => db.setPref('breakAfterMin', '$v'),
            ),
            if (s.breakAfterMin > 0) ...[
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'notify', label: Text('Solo avviso')),
                  ButtonSegment(value: 'auto', label: Text('Pausa automatica')),
                ],
                selected: {s.breakMode},
                showSelectedIcon: false,
                onSelectionChanged: (v) => db.setPref('breakMode', v.first),
              ),
              const SizedBox(height: 6),
              Text(
                s.breakMode == 'auto'
                    ? 'Allo scadere il timer si ferma e parte la pausa: la notifica ti chiede se tenerla.'
                    : 'Solo una notifica, il timer continua.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _Choice(
              label: 'Fine pausa dopo',
              value: s.pauseReminderMin,
              options: const {
                0: 'Mai',
                5: '5 min',
                10: '10 min',
                15: '15 min',
                20: '20 min',
                30: '30 min',
              },
              onChanged: (v) => db.setPref('pauseReminderMin', '$v'),
            ),
          ],
        ),

        _Section(
          title: 'Pomodoro',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modalità conto alla rovescia'),
              value: s.pomodoro,
              onChanged: (v) => db.setPref('pomodoro', v ? '1' : '0'),
            ),
            if (s.pomodoro) ...[
              _Choice(
                label: 'Lavoro',
                value: s.pomoWorkMin,
                options: const {15: '15 min', 25: '25 min', 30: '30 min', 45: '45 min', 50: '50 min'},
                onChanged: (v) => db.setPref('pomoWorkMin', '$v'),
              ),
              const SizedBox(height: 12),
              _Choice(
                label: 'Pausa',
                value: s.pomoBreakMin,
                options: const {3: '3 min', 5: '5 min', 10: '10 min', 15: '15 min'},
                onChanged: (v) => db.setPref('pomoBreakMin', '$v'),
              ),
            ],
          ],
        ),

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
          title: 'Backup',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_rounded),
              title: const Text('Esporta backup (JSON)'),
              subtitle: const Text('Reimportabile su un altro telefono'),
              onTap: exportJson,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.table_chart_rounded),
              title: const Text('Esporta CSV'),
              subtitle: const Text('Per Excel o Fogli Google'),
              onTap: exportCsv,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download_rounded),
              title: const Text('Importa backup'),
              subtitle: const Text('Sostituisce tutti i dati attuali'),
              onTap: () => _confirmImport(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Taime · i dati restano su questo telefono',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmImport(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importare il backup?'),
        content: const Text(
          'Tutte le sessioni e le attività attuali verranno sostituite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importa'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final msg = await importJson();
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editActivity(
    BuildContext context,
    Settings s,
    Activity? activity,
  ) async {
    final controller = TextEditingController(text: activity?.name ?? '');
    var icon = activity?.icon ?? 'circle';
    var colorIndex = activity?.colorIndex ?? 0;
    final dark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity == null ? 'Nuova attività' : 'Modifica attività',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Nome'),
                autofocus: activity == null,
              ),
              const SizedBox(height: 16),
              const Text('Colore'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (var i = 0; i < s.palette.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => colorIndex = i),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: activityColor(i, s.palette, dark: dark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: i == colorIndex
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Icona'),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final e in activityIcons.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => icon = e.key),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: e.key == icon
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(e.value, size: 22),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (activity != null)
                    TextButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await (db.update(db.activities)
                              ..where((a) => a.id.equals(activity.id)))
                            .write(
                              ActivitiesCompanion(
                                archived: Value(!activity.archived),
                              ),
                            );
                        navigator.pop();
                      },
                      icon: Icon(
                        activity.archived
                            ? Icons.restore_rounded
                            : Icons.archive_rounded,
                        size: 18,
                      ),
                      label: Text(activity.archived ? 'Ripristina' : 'Archivia'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;
                      final navigator = Navigator.of(context);
                      if (activity == null) {
                        await db
                            .into(db.activities)
                            .insert(
                              ActivitiesCompanion.insert(
                                name: name,
                                colorIndex: colorIndex,
                                icon: Value(icon),
                                sort: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
                              ),
                            );
                      } else {
                        await (db.update(db.activities)
                              ..where((a) => a.id.equals(activity.id)))
                            .write(
                              ActivitiesCompanion(
                                name: Value(name),
                                colorIndex: Value(colorIndex),
                                icon: Value(icon),
                              ),
                            );
                      }
                      navigator.pop();
                    },
                    child: const Text('Salva'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }
}

class _PaletteField extends StatefulWidget {
  const _PaletteField({required this.settings});
  final Settings settings;

  @override
  State<_PaletteField> createState() => _PaletteFieldState();
}

class _PaletteFieldState extends State<_PaletteField> {
  late final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.settings.palette.length; i++)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: activityColor(i, widget.settings.palette, dark: dark),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          decoration: const InputDecoration(
            hintText: 'Incolla un link di coolors.co',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed: () {
                final colors = pal.parsePalette(_c.text);
                if (colors.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nessuna palette trovata')),
                  );
                  return;
                }
                db.setPref('palette', pal.paletteToString(colors));
                _c.clear();
              },
              child: const Text('Applica'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => db.setPref(
                'palette',
                pal.paletteToString(pal.defaultPalette),
              ),
              child: const Text('Ripristina'),
            ),
          ],
        ),
        Text(
          'I colori tingono accenti e attività: lo sfondo resta neutro.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final int value;
  final Map<int, String> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        DropdownButton<int>(
          value: options.containsKey(value) ? value : options.keys.first,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(16),
          items: [
            for (final e in options.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
