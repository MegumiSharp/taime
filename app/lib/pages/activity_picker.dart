import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app.dart';
import '../db.dart';
import '../icons.dart';
import '../palette.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/swatches.dart';
import '../ui/widgets.dart';

/// Full-screen blurred overlay with every activity as a pill, like choosing a
/// tag in Forest. Returns the chosen activity.
Future<Activity?> showActivityPicker(BuildContext context, {int? currentId}) {
  return showGeneralDialog<Activity>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Chiudi',
    barrierColor: Colors.transparent,
    transitionDuration: Motion.of(context, Motion.slow),
    pageBuilder: (context, _, _) => _PickerOverlay(currentId: currentId),
    transitionBuilder: (context, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Motion.emphasized);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14 * a.value, sigmaY: 14 * a.value),
        child: FadeTransition(opacity: a, child: child),
      );
    },
  );
}

class _PickerOverlay extends StatelessWidget {
  const _PickerOverlay({required this.currentId});
  final int? currentId;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Material(
      color: tc.bgBottom.withValues(alpha: tc.dark ? 0.72 : 0.62),
      child: SafeArea(
        child: StreamBuilder<List<Activity>>(
          stream: db.watchActivities(),
          builder: (context, snap) {
            final acts = snap.data ?? const <Activity>[];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Su cosa lavori?',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(tooltip: 'Chiudi', 
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: acts.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == acts.length) {
                        return StaggeredIn(
                          index: i,
                          child: Center(
                            child: PillButton(
                              label: 'Nuova attività',
                              icon: Icons.add_rounded,
                              kind: PillKind.ghost,
                              onTap: () => showActivityEditor(context),
                            ),
                          ),
                        );
                      }
                      final a = acts[i];
                      return StaggeredIn(
                        index: i,
                        child: _ActivityPill(
                          activity: a,
                          selected: a.id == currentId,
                          onTap: () {
                            Haptic.select();
                            Navigator.pop(context, a);
                          },
                          onEdit: () => showActivityEditor(context, activity: a),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivityPill extends StatelessWidget {
  const _ActivityPill({
    required this.activity,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  final Activity activity;
  final bool selected;
  final VoidCallback onTap, onEdit;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final color = activityColor(activity.color, dark: tc.dark);
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        height: 60,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: selected ? activitySoft(activity.color, dark: tc.dark) : tc.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: activitySoft(activity.color, dark: tc.dark),
                shape: BoxShape.circle,
              ),
              child: Icon(iconFor(activity.icon), color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                activity.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Modifica',
              icon: Icon(Icons.edit_rounded, color: tc.muted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create or edit an activity: name, colour (swatches or free), icon.
Future<void> showActivityEditor(BuildContext context, {Activity? activity}) {
  return showSoftSheet<void>(
    context,
    builder: (context) => _ActivityEditor(activity: activity),
  );
}

class _ActivityEditor extends StatefulWidget {
  const _ActivityEditor({this.activity});
  final Activity? activity;

  @override
  State<_ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<_ActivityEditor> {
  late final _name = TextEditingController(text: widget.activity?.name ?? '');
  late int _color = widget.activity?.color ?? activitySwatches[14];
  late String _icon = widget.activity?.icon ?? 'star';
  String _group = kIconGroups.keys.first;
  final _search = TextEditingController();
  bool _custom = false;
  double _hue = 200, _light = 0.72;

  @override
  void initState() {
    super.initState();
    final o = toOklch(_color);
    _hue = o.h;
    _light = o.l.clamp(0.45, 0.9);
    _custom = !activitySwatches.contains(_color);
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final a = widget.activity;
    final q = _search.text;
    final icons = q.isEmpty ? kIconGroups[_group]! : searchIcons(q);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: activitySoft(_color, dark: tc.dark),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconFor(_icon), color: activityColor(_color, dark: tc.dark), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    a == null ? 'Nuova attività' : 'Modifica attività',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: a == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Nome, es. Studio'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('Colore', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _custom = !_custom),
                  child: Text(_custom ? 'Colori pronti' : 'Colore libero'),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: Motion.of(context, Motion.medium),
              crossFadeState: _custom ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in activitySwatches)
                    GestureDetector(
                      onTap: () {
                        Haptic.select();
                        setState(() => _color = c);
                      },
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.fast),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: activityColor(c, dark: tc.dark),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == _color ? tc.text : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: c == _color
                            ? Icon(Icons.check_rounded, size: 18, color: Color(onColor(activityColor(c, dark: tc.dark).toARGB32())))
                            : null,
                      ),
                    ),
                ],
              ),
              secondChild: Column(
                children: [
                  _HueSlider(
                    value: _hue,
                    onChanged: (v) => setState(() {
                      _hue = v;
                      _color = oklch(_light, 0.1, _hue);
                    }),
                  ),
                  Slider(
                    value: _light,
                    min: 0.45,
                    max: 0.9,
                    onChanged: (v) => setState(() {
                      _light = v;
                      _color = oklch(_light, 0.1, _hue);
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Icona', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Cerca: palestra, libro, cucina…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            if (q.isEmpty)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final g in kIconGroups.keys)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: g == _group,
                          showCheckmark: false,
                          shape: const StadiumBorder(),
                          onSelected: (_) => setState(() => _group = g),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.medium),
              child: Wrap(
                key: ValueKey('$_group$q'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (icons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('Nessuna icona trovata', style: TextStyle(color: tc.muted)),
                    ),
                  for (final i in icons)
                    GestureDetector(
                      onTap: () {
                        Haptic.select();
                        setState(() => _icon = i.key);
                      },
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.fast),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: i.key == _icon ? activitySoft(_color, dark: tc.dark) : tc.raised,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: i.key == _icon ? activityColor(_color, dark: tc.dark) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(i.icon, size: 22, color: i.key == _icon ? activityColor(_color, dark: tc.dark) : tc.muted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                if (a != null)
                  PillButton(
                    label: a.archived ? 'Ripristina' : 'Archivia',
                    icon: a.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
                    kind: PillKind.ghost,
                    onTap: () async {
                      final nav = Navigator.of(context);
                      await (db.update(db.activities)..where((x) => x.id.equals(a.id)))
                          .write(ActivitiesCompanion(archived: Value(!a.archived)));
                      nav.pop();
                    },
                  ),
                const Spacer(),
                PillButton(
                  label: 'Salva',
                  icon: Icons.check_rounded,
                  onTap: () async {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    final nav = Navigator.of(context);
                    if (a == null) {
                      await db.into(db.activities).insert(
                        ActivitiesCompanion.insert(
                          name: name,
                          color: _color,
                          icon: Value(_icon),
                          sort: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
                        ),
                      );
                    } else {
                      await (db.update(db.activities)..where((x) => x.id.equals(a.id))).write(
                        ActivitiesCompanion(name: Value(name), color: Value(_color), icon: Value(_icon)),
                      );
                    }
                    nav.pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [for (var h = 0; h <= 360; h += 30) Color(oklch(0.75, 0.1, h.toDouble()))],
        ),
      ),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: Colors.transparent,
          inactiveTrackColor: Colors.transparent,
          thumbColor: Colors.white,
        ),
        child: Slider(value: value, min: 0, max: 360, onChanged: onChanged),
      ),
    );
  }
}
