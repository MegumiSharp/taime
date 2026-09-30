import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app.dart';
import '../db.dart';
import '../kitten/art.dart';
import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';

/// "Crea il tuo gattino": mix the styles of the kittens you adopted. Opens on
/// [edit] to change one you already made.
Future<void> openKittenMaker(BuildContext context, {Skin? edit}) async {
  final bought = await db.select(db.purchases).get();
  final ids = {for (final p in bought) p.skinId};
  final owned = kSkins.where((s) => s.free || ids.contains(s.id));
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _KittenMaker(parts: KittenParts(owned), edit: edit),
    ),
  );
}

class _KittenMaker extends StatefulWidget {
  const _KittenMaker({required this.parts, this.edit});
  final KittenParts parts;
  final Skin? edit;

  @override
  State<_KittenMaker> createState() => _KittenMakerState();
}

class _KittenMakerState extends State<_KittenMaker> {
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late Map<String, Object?> _look;

  @override
  void initState() {
    super.initState();
    final p = widget.parts;
    _look =
        widget.edit?.lookJson() ??
        {
          'pattern': CoatPattern.tintaUnita.name,
          'base': p.coats.first,
          'muzzle': p.muzzle,
          'belly': p.belly,
          'paws': p.paws,
          'pose': Pose.seduto.name,
          'eyes': EyeStyle.puntini.name,
        };
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Skin _skin([Map<String, Object?> change = const {}]) =>
      Skin.fromLook('preview', _name.text.trim(), {..._look, ...change});

  void _set(Map<String, Object?> change) {
    Haptic.select();
    setState(() => _look = {..._look, ...change});
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final nav = Navigator.of(context);
    final spec = jsonEncode(_look);
    final String id;
    if (widget.edit == null) {
      final row = await db
          .into(db.customSkins)
          .insert(CustomSkinsCompanion.insert(name: name, spec: spec, createdAt: DateTime.now()));
      id = '$kCustomPrefix$row';
    } else {
      id = widget.edit!.id;
      final row = int.parse(id.substring(kCustomPrefix.length));
      await (db.update(
        db.customSkins,
      )..where((c) => c.id.equals(row))).write(CustomSkinsCompanion(name: Value(name), spec: Value(spec)));
    }
    // Draw it right away with the new look (the database listener follows).
    kCustomSkins[id] = Skin.fromLook(id, name, _look);
    await clearKittenArt(id);
    if ((await db.pref('activeSkin')) == id) await ensureKittenArt(id);
    Haptic.medium();
    nav.pop();
  }

  Future<void> _delete() async {
    final edit = widget.edit!;
    final ok = await confirm(
      context,
      title: 'Liberare ${edit.name}?',
      message: 'Non potrai più sceglierlo, ma resta nel recinto per le sessioni passate.',
      action: 'Elimina',
      danger: true,
    );
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    final row = int.parse(edit.id.substring(kCustomPrefix.length));
    await (db.update(
      db.customSkins,
    )..where((c) => c.id.equals(row))).write(const CustomSkinsCompanion(deleted: Value(true)));
    if ((await db.pref('activeSkin')) == edit.id) {
      await db.setPref('activeSkin', kSkins.first.id);
      await ensureKittenArt(kSkins.first.id);
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final p = widget.parts;
    final skin = _skin();
    final pattern = skin.coat.pattern;
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Indietro',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        widget.edit == null ? 'Crea il tuo gattino' : 'Modifica ${widget.edit!.name}',
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.edit != null)
                      IconButton(
                        tooltip: 'Elimina',
                        onPressed: _delete,
                        icon: Icon(Icons.delete_outline_rounded, color: tc.danger),
                      ),
                  ],
                ),
              ),
              // The kitten stays in sight while you change it.
              SizedBox(
                height: 200,
                child: Center(child: KittenView(skin: skin, size: 190, showcase: true)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 20,
                      decoration: const InputDecoration(hintText: 'Come si chiama?', counterText: ''),
                    ),
                    _Section(
                      title: 'Posa',
                      children: [
                        for (final pose in const [Pose.seduto, Pose.pagnotta])
                          SoftChip(
                            label: pose.label,
                            selected: skin.pose == pose,
                            onTap: () => _set({'pose': pose.name}),
                          ),
                      ],
                    ),
                    _Section(
                      title: 'Pelo',
                      children: [
                        for (final c in p.coats)
                          _Swatch(color: Color(c), selected: skin.coat.base == c, onTap: () => _set({'base': c})),
                      ],
                    ),
                    _Section(
                      title: 'Motivo',
                      children: [
                        for (final (pat, second, third, fourth) in p.patterns)
                          _Thumb(
                            label: pat.label,
                            skin: _skin({'pattern': pat.name, 'second': second, 'third': third, 'fourth': fourth}),
                            selected: pattern == pat && skin.coat.second == second && skin.coat.third == third,
                            onTap: () => _set({'pattern': pat.name, 'second': second, 'third': third, 'fourth': fourth}),
                          ),
                      ],
                    ),
                    if (p.muzzle || p.blaze)
                      _Section(
                        title: 'Muso',
                        children: [
                          SoftChip(
                            label: 'Come il pelo',
                            selected: !skin.coat.whiteMuzzle && !skin.coat.blaze,
                            onTap: () => _set({'muzzle': false, 'blaze': false}),
                          ),
                          if (p.muzzle)
                            SoftChip(
                              label: 'Muso bianco',
                              selected: skin.coat.whiteMuzzle && !skin.coat.blaze,
                              onTap: () => _set({'muzzle': true, 'blaze': false}),
                            ),
                          if (p.blaze)
                            SoftChip(
                              label: 'Muso e striscia bianchi',
                              selected: skin.coat.blaze,
                              onTap: () => _set({'muzzle': true, 'blaze': true}),
                            ),
                        ],
                      ),
                    if (p.blackNose)
                      _Section(
                        title: 'Naso',
                        children: [
                          SoftChip(
                            label: 'Rosa',
                            selected: !skin.coat.blackNose,
                            onTap: () => _set({'blackNose': false}),
                          ),
                          SoftChip(
                            label: 'Nero',
                            selected: skin.coat.blackNose,
                            onTap: () => _set({'blackNose': true}),
                          ),
                        ],
                      ),
                    if (p.belly || p.paws)
                      _Section(
                        title: 'Pancia e zampe',
                        children: [
                          if (p.belly)
                            SoftChip(
                              label: 'Pancia bianca',
                              icon: skin.coat.whiteBelly ? Icons.check_rounded : Icons.add_rounded,
                              selected: skin.coat.whiteBelly,
                              onTap: () => _set({'belly': !skin.coat.whiteBelly}),
                            ),
                          if (p.paws)
                            SoftChip(
                              label: 'Zampe bianche',
                              icon: skin.coat.whitePaws ? Icons.check_rounded : Icons.add_rounded,
                              selected: skin.coat.whitePaws,
                              onTap: () => _set({'paws': !skin.coat.whitePaws}),
                            ),
                        ],
                      ),
                    _Section(
                      title: 'Occhi',
                      children: [
                        for (final e in p.eyes)
                          SoftChip(
                            label: e.label,
                            dot: switch (e) {
                              EyeStyle.puntini => const Color(0xFF3B2925),
                              EyeStyle.dorati => const Color(0xFFF0CD6A),
                              EyeStyle.azzurri => const Color(0xFFA9CFEF),
                              EyeStyle.verdi => const Color(0xFFB4D88A),
                            },
                            selected: skin.eyes == e,
                            onTap: () => _set({'eyes': e.name}),
                          ),
                      ],
                    ),
                    _Section(
                      title: 'In testa',
                      children: [
                        for (final (a, col) in _firstOfEach(p.head))
                          _Thumb(
                            label: a.label,
                            skin: _skin({'acc': a.name, 'accColor': skin.accessory == a ? skin.accessoryColor : col}),
                            selected: skin.accessory == a,
                            onTap: () => _set({'acc': a.name, 'accColor': col}),
                          ),
                      ],
                    ),
                    if (_tintable(skin.accessory))
                      _Section(
                        title: 'Colore di ${skin.accessory.label.toLowerCase()}',
                        children: [
                          for (final c in _accessoryColors(p.head, skin.accessory))
                            _Swatch(
                              color: Color(c),
                              selected: skin.accessoryColor == c,
                              onTap: () => _set({'accColor': c}),
                            ),
                        ],
                      ),
                    _Section(
                      title: 'Collo e schiena',
                      children: [
                        for (final (a, col) in _firstOfEach(p.neck))
                          _Thumb(
                            label: a.label,
                            skin: _skin({
                              'acc2': a.name,
                              'acc2Color': skin.accessory2 == a ? skin.accessory2Color : col,
                            }),
                            selected: skin.accessory2 == a,
                            onTap: () => _set({'acc2': a.name, 'acc2Color': col}),
                          ),
                      ],
                    ),
                    if (_tintable(skin.accessory2))
                      _Section(
                        title: 'Colore di ${skin.accessory2.label.toLowerCase()}',
                        children: [
                          for (final c in _accessoryColors(p.neck, skin.accessory2))
                            _Swatch(
                              color: Color(c),
                              selected: skin.accessory2Color == c,
                              onTap: () => _set({'acc2Color': c}),
                            ),
                        ],
                      ),
                    _Section(
                      title: 'Effetti (fino a due)',
                      children: [
                        for (final e in p.effects)
                          SoftChip(
                            label: e.label,
                            icon: e == Effect.nessuno ? null : Icons.auto_awesome_rounded,
                            selected: e == Effect.nessuno
                                ? skin.effect == Effect.nessuno && skin.effect2 == Effect.nessuno
                                : skin.has(e),
                            onTap: () => _set(_toggleEffect(skin, e)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.lock_open_rounded, size: 16, color: tc.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${p.count} stili su ${KittenParts.total}. Ogni gattino che adotti ne sblocca altri.',
                            style: TextStyle(color: tc.muted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    PillButton(
                      label: widget.edit == null ? 'Salva il gattino' : 'Salva le modifiche',
                      icon: Icons.favorite_rounded,
                      expand: true,
                      onTap: _name.text.trim().isEmpty ? null : _save,
                    ),
                    if (_name.text.trim().isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Dagli un nome per salvarlo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: tc.muted, fontSize: 12.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft colours any accessory can wear, besides the ones it came with.
const List<int> _kAccessoryColors = [
  0xFFE89BBE,
  0xFFE58C8C,
  0xFFF2A7C3,
  0xFFF4C27F,
  0xFFF2C94C,
  0xFFA9D18E,
  0xFF8FCFB0,
  0xFF9DC7EA,
  0xFF7F93C9,
  0xFFB89BE3,
  0xFFFFFAF3,
  0xFF4A3F5C,
];

/// Accessories whose colour is drawn from the pick (the helmet is always white).
bool _tintable(Accessory a) => a != Accessory.nessuno && a != Accessory.casco;

/// One thumbnail per accessory: the colour comes from the row below.
List<(Accessory, int)> _firstOfEach(List<(Accessory, int)> all) {
  final seen = <Accessory>{};
  return [
    for (final e in all)
      if (seen.add(e.$1)) e,
  ];
}

/// The colours it came with first, then the rest of the soft palette.
List<int> _accessoryColors(List<(Accessory, int)> owned, Accessory a) => {
  for (final (x, c) in owned)
    if (x == a) c,
  ..._kAccessoryColors,
}.toList();

/// Effects toggle; with two already on, the newest replaces the second.
Map<String, Object?> _toggleEffect(Skin skin, Effect e) {
  if (e == Effect.nessuno) return {'fx': e.name, 'fx2': e.name};
  final on = [skin.effect, skin.effect2].where((x) => x != Effect.nessuno).toList();
  if (on.contains(e)) {
    on.remove(e);
  } else if (on.length < 2) {
    on.add(e);
  } else {
    on[1] = e;
  }
  return {'fx': (on.isNotEmpty ? on[0] : Effect.nessuno).name, 'fx2': (on.length > 1 ? on[1] : Effect.nessuno).name};
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final c in children) Padding(padding: const EdgeInsets.only(right: 8), child: c)],
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Semantics(
      label: 'Colore',
      selected: selected,
      child: TapScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? tc.accent : tc.outline, width: selected ? 3 : 1.5),
          ),
        ),
      ),
    );
  }
}

/// A small still kitten wearing one option.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.label, required this.skin, required this.selected, required this.onTap});
  final String label;
  final Skin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        width: 84,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(
          color: selected ? tc.accentSoft : tc.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? tc.accent : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            KittenView(skin: skin, size: 62, animate: false),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}
