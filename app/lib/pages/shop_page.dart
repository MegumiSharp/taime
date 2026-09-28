import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../db.dart';
import '../kitten/art.dart';
import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../palette.dart';
import '../settings.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';
import 'create_kitten.dart';

/// Skins the user can use: the free ones, purchases and the ones you made.
Future<Set<String>> ownedSkinIds() async {
  final bought = await db.select(db.purchases).get();
  final made = await (db.select(db.customSkins)..where((c) => c.deleted.equals(false))).get();
  return {
    for (final s in kSkins)
      if (s.free) s.id,
    for (final p in bought) p.skinId,
    for (final c in made) '$kCustomPrefix${c.id}',
  };
}

/// Live balance: finished work + [extraSeconds] of work in progress − spent.
///
/// Starts from the last known totals, so a chip that is rebuilt (a tab
/// switch, scrolling back up) does not count up from zero again.
class BalanceBuilder extends StatelessWidget {
  const BalanceBuilder({super.key, required this.builder, this.extraSeconds = 0});
  final Widget Function(BuildContext context, int balance) builder;
  final int extraSeconds;

  static int? _work, _spent;

  /// Reads the totals once at startup, so even the first chip is steady.
  static Future<void> warmUp() async {
    _work = await db.watchClosedWorkSeconds().first;
    _spent = await db.watchSpent().first;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      initialData: _work,
      stream: db.watchClosedWorkSeconds(),
      builder: (context, w) => StreamBuilder<int>(
        initialData: _spent,
        stream: db.watchSpent(),
        builder: (context, sp) {
          _work = w.data ?? _work;
          _spent = sp.data ?? _spent;
          if (_work == null || _spent == null) return builder(context, 0);
          return builder(context, crocchetteBalance(_work! + extraSeconds, _spent!));
        },
      ),
    );
  }
}

class BalanceChip extends StatelessWidget {
  const BalanceChip({super.key, this.extraSeconds = 0});
  final int extraSeconds;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return BalanceBuilder(
      extraSeconds: extraSeconds,
      builder: (context, b) => Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Kibble(size: 20),
            const SizedBox(width: 6),
            AnimatedCount(
              math.max(0, b),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// A little crocchetta: rounded brown kibble with a highlight.
class _Kibble extends StatelessWidget {
  const _Kibble({this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _KibblePainter());
  }
}

class _KibblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.08, s * 0.2, s * 0.84, s * 0.62),
      Radius.circular(s * 0.3),
    );
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate(-0.35);
    canvas.translate(-s / 2, -s / 2);
    canvas.drawRRect(r, Paint()..color = const Color(0xFFC98B5B));
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFF7A4E36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09,
    );
    canvas.drawCircle(Offset(s * 0.35, s * 0.42), s * 0.07, Paint()..color = const Color(0x99FFFFFF));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KibblePainter old) => false;
}

Color rarityColor(Rarity r, {required bool dark, bool soft = false}) => Color(
  soft ? oklch(dark ? 0.34 : 0.92, 0.05, r.hue) : oklch(dark ? 0.8 : 0.55, 0.11, r.hue),
);

class ShopPage extends StatefulWidget {
  const ShopPage({super.key, required this.settings});
  final Settings settings;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String _tab = 'evidenza';

  @override
  Widget build(BuildContext context) {
    return PastelBackground(
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Purchase>>(
          stream: db.watchPurchases(),
          builder: (context, snap) {
            final owned = {
              for (final s in kSkins)
                if (s.free) s.id,
              for (final p in snap.data ?? const <Purchase>[]) p.skinId,
            };
            return BalanceBuilder(
              builder: (context, balance) => CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Negozio', style: Theme.of(context).textTheme.headlineMedium),
                            ),
                            const BalanceChip(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Una crocchetta per ogni minuto di concentrazione.',
                          style: TextStyle(color: context.tc.muted),
                        ),
                        const SizedBox(height: 16),
                        PillSelector<String>(
                          values: const ['evidenza', 'tutti', 'miei', 'crea'],
                          labels: const ['In evidenza', 'Tutti', 'Album', 'Crea'],
                          selected: _tab,
                          onChanged: (v) => setState(() => _tab = v),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                  ..._content(context, owned, balance, snap.data ?? const <Purchase>[]),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, Set<String> owned, int balance, List<Purchase> purchases) {
    switch (_tab) {
      case 'evidenza':
        final featured = [
          ...kSkins.where((s) => s.rarity.index >= 1 && !owned.contains(s.id)),
          ...kSkins.where((s) => s.rarity.index >= 1 && owned.contains(s.id)),
        ].reversed.toList();
        return [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 360,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.78),
                itemCount: featured.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _FeaturedCard(
                    skin: featured[i],
                    owned: owned.contains(featured[i].id),
                    active: widget.settings.activeSkin == featured[i].id,
                    balance: balance,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(
              child: SectionTitle('Per iniziare'),
            ),
          ),
          _grid(
            context,
            kSkins.where((s) => s.rarity == Rarity.comune).toList(),
            owned,
            balance,
          ),
        ];
      case 'tutti':
        return [
          for (final r in Rarity.values) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: SectionTitle(
                  _plural(r),
                  trailing: _RarityDot(rarity: r),
                ),
              ),
            ),
            _grid(context, kSkins.where((s) => s.rarity == r).toList(), owned, balance),
          ],
        ];
      case 'crea':
        return [
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _Maker()),
          ),
        ];
      default:
        final adopted = kSkins.where((s) => owned.contains(s.id)).toList();
        final mine = [...adopted, ...myCustomSkins];
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${adopted.length} di ${kSkins.length} gattini adottati.',
                style: TextStyle(color: context.tc.muted),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Album(
              skins: mine,
              active: widget.settings.activeSkin,
              purchases: purchases,
            ),
          ),
        ];
    }
  }

  String _plural(Rarity r) => switch (r) {
    Rarity.comune => 'Comuni',
    Rarity.raro => 'Rari',
    Rarity.epico => 'Epici',
    Rarity.leggendario => 'Leggendari',
  };

  Widget _grid(BuildContext context, List<Skin> skins, Set<String> owned, int balance) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: skins.length,
        itemBuilder: (context, i) => StaggeredIn(
          index: i,
          child: _SkinTile(
            skin: skins[i],
            owned: owned.contains(skins[i].id),
            active: widget.settings.activeSkin == skins[i].id,
            balance: balance,
          ),
        ),
      ),
    );
  }
}

class _RarityDot extends StatelessWidget {
  const _RarityDot({required this.rarity, this.custom = false});
  final Rarity rarity;

  /// A kitten you made: "Creato da te" in the theme colour.
  final bool custom;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: custom ? tc.accentSoft : rarityColor(rarity, dark: tc.dark, soft: true),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        custom ? 'Creato da te' : rarity.label,
        style: TextStyle(
          color: custom ? tc.accent : rarityColor(rarity, dark: tc.dark),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.skin, required this.owned, required this.active});
  final Skin skin;
  final bool owned, active;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    if (active) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: tc.accent),
          const SizedBox(width: 4),
          Text('In uso', style: TextStyle(color: tc.accent, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      );
    }
    if (owned) {
      return Text('Tuo', style: TextStyle(color: tc.muted, fontWeight: FontWeight.w700, fontSize: 13));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Kibble(size: 15),
        const SizedBox(width: 4),
        Text('${skin.price}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
      ],
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.skin,
    required this.owned,
    required this.active,
    required this.balance,
  });

  final Skin skin;
  final bool owned, active;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      color: active ? tc.accentSoft : null,
      onTap: () => showSkinPreview(context, skin, owned: owned, balance: balance),
      child: Column(
        children: [
          Expanded(
            child: Opacity(
              opacity: owned ? 1 : 0.9,
              child: KittenView(skin: skin, size: 100, animate: false),
            ),
          ),
          Text(
            skin.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          _PriceTag(skin: skin, owned: owned, active: active),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.skin,
    required this.owned,
    required this.active,
    required this.balance,
  });

  final Skin skin;
  final bool owned, active;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final soft = rarityColor(skin.rarity, dark: tc.dark, soft: true);
    return TapScale(
      onTap: () => showSkinPreview(context, skin, owned: owned, balance: balance),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [soft, Color.lerp(soft, tc.surface, 0.55)!],
          ),
          boxShadow: [
            BoxShadow(
              color: tc.shadow(1.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RarityDot(rarity: skin.rarity),
            Expanded(child: Center(child: KittenView(skin: skin, size: 210, showcase: true))),
            Text(skin.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: _PriceTag(skin: skin, owned: owned, active: active),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big animated preview with every pose; buy or use from here.
Future<void> showSkinPreview(
  BuildContext context,
  Skin skin, {
  required bool owned,
  required int balance,
}) {
  return showSoftSheet<void>(
    context,
    builder: (context) => _Preview(skin: skin, owned: owned),
  );
}

class _Preview extends StatefulWidget {
  const _Preview({required this.skin, required this.owned});
  final Skin skin;
  final bool owned;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  late Pose _pose = widget.skin.pose;
  double _growth = 1;
  bool _justBought = false;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final skin = widget.skin;
    final owned = widget.owned || _justBought;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: StreamBuilder<Map<String, String>>(
          stream: db.watchPrefs(),
          builder: (context, prefSnap) {
            final active = Settings(prefSnap.data ?? const {}).activeSkin == skin.id;
            return BalanceBuilder(
              builder: (context, balance) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RarityDot(rarity: skin.rarity, custom: skin.isCustom),
                  const SizedBox(height: 6),
                  Text(skin.name, style: Theme.of(context).textTheme.headlineSmall),
                  SizedBox(
                    height: 230,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_justBought) const _Confetti(),
                        KittenView(skin: skin, pose: _pose, growth: _growth, size: 220, showcase: true),
                      ],
                    ),
                  ),
                  PillSelector<Pose>(
                    values: Pose.values,
                    labels: [for (final p in Pose.values) p.label],
                    selected: _pose,
                    onChanged: (p) => setState(() => _pose = p),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Crescita', style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600)),
                      Expanded(
                        child: Slider(
                          value: _growth,
                          onChanged: (v) => setState(() => _growth = v),
                        ),
                      ),
                      SizedBox(
                        width: 86,
                        child: Text(
                          kStageNames[stageOf(_growth * 60)],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (skin.isCustom) ...[
                    PillButton(
                      label: 'Modifica',
                      icon: Icons.brush_rounded,
                      kind: PillKind.soft,
                      expand: true,
                      onTap: () {
                        final nav = Navigator.of(context);
                        nav.pop();
                        openKittenMaker(nav.context, edit: skin);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (active)
                    PillButton(label: 'In uso', icon: Icons.check_rounded, kind: PillKind.soft, expand: true, onTap: null)
                  else if (owned)
                    PillButton(
                      label: 'Usa questo gattino',
                      icon: Icons.favorite_rounded,
                      expand: true,
                      onTap: () async {
                        await db.setPref('activeSkin', skin.id);
                        await ensureKittenArt(skin.id);
                      },
                    )
                  else
                    PillButton(
                      label: balance >= skin.price
                          ? 'Compra per ${skin.price} crocchette'
                          : 'Mancano ${skin.price - math.max(0, balance)} crocchette',
                      icon: Icons.shopping_bag_rounded,
                      expand: true,
                      onTap: balance >= skin.price ? () => _buy(context, balance) : null,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _buy(BuildContext context, int balance) async {
    final skin = widget.skin;
    final ok = await confirm(
      context,
      title: 'Adotti ${skin.name}?',
      message: 'Costa ${skin.price} crocchette. Te ne resteranno ${balance - skin.price}.',
      action: 'Adotta',
    );
    if (!ok) return;
    await db.into(db.purchases).insert(
      PurchasesCompanion.insert(skinId: skin.id, price: skin.price, purchasedAt: DateTime.now()),
    );
    Haptic.medium();
    setState(() => _justBought = true);
  }
}

/// A short burst of soft sparkles after a purchase.
class _Confetti extends StatelessWidget {
  const _Confetti();

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final colors = [tc.accent, tc.pause, const Color(0xFFF2A7C3), const Color(0xFFF6D46E)];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 1400)),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: const Size(260, 230),
        painter: _ConfettiPainter(t, colors),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.colors);
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 18; i++) {
      final ang = i / 18 * 2 * math.pi;
      final d = 40 + t * 90 + (i % 3) * 10;
      final o = c + Offset(math.cos(ang), math.sin(ang)) * d + Offset(0, t * t * 30);
      canvas.drawCircle(
        o,
        4 * (1 - t) + 1,
        Paint()..color = colors[i % colors.length].withValues(alpha: (1 - t).clamp(0, 1)),
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}


/// The adopted kittens, with what you did together.
class _Album extends StatelessWidget {
  const _Album({required this.skins, required this.active, required this.purchases});
  final List<Skin> skins;
  final String active;
  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final adopted = {for (final p in purchases) p.skinId: p.purchasedAt};
    return StreamBuilder<List<SessionWork>>(
      stream: db.watchSessionWork(DateTime(2000), DateTime(2200)),
      builder: (context, snap) {
        final seconds = <String, int>{};
        final sessions = <String, int>{};
        final cats = <String, int>{};
        for (final w in snap.data ?? const <SessionWork>[]) {
          final id = w.session.skinId ?? kSkins.first.id;
          seconds[id] = (seconds[id] ?? 0) + w.workSeconds;
          sessions[id] = (sessions[id] ?? 0) + 1;
          cats[id] = (cats[id] ?? 0) + catsForSession(w.workSeconds ~/ 60, id, w.session.id).length;
        }
        final sorted = [...skins]..sort((a, b) => (seconds[b.id] ?? 0).compareTo(seconds[a.id] ?? 0));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var i = 0; i < sorted.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StaggeredIn(
                    index: i,
                    child: SoftCard(
                      color: sorted[i].id == active ? tc.accentSoft : null,
                      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
                      onTap: () => showSkinPreview(context, sorted[i], owned: true, balance: 0),
                      child: Row(
                        children: [
                          KittenView(skin: sorted[i], size: 92, animate: sorted[i].id == active),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(sorted[i].name,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleMedium),
                                    ),
                                    if (sorted[i].id == active) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.favorite_rounded, size: 15, color: tc.accent),
                                    ],
                                  ],
                                ),
                                Text(
                                  sorted[i].isCustom
                                      ? 'Creato da te'
                                      : adopted[sorted[i].id] == null
                                      ? "Con te dall'inizio"
                                      : 'Adottato il ${DateFormat('d MMMM y', 'it').format(adopted[sorted[i].id]!)}',
                                  style: TextStyle(color: tc.muted, fontSize: 12.5),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 4,
                                  children: [
                                    _AlbumStat(icon: Icons.schedule_rounded, text: fmtHm(Duration(seconds: seconds[sorted[i].id] ?? 0))),
                                    _AlbumStat(icon: Icons.spa_rounded, text: '${sessions[sorted[i].id] ?? 0} sessioni'),
                                    _AlbumStat(icon: Icons.pets_rounded, text: '${cats[sorted[i].id] ?? 0} nel recinto'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AlbumStat extends StatelessWidget {
  const _AlbumStat({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: context.tc.accent),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
    ],
  );
}

/// The "Crea" tab: your kittens (up to five) and a card to make a new one.
class _Maker extends StatelessWidget {
  const _Maker();

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return StreamBuilder<List<CustomSkin>>(
      stream: db.watchCustomSkins(),
      builder: (context, snap) {
        final made = myCustomSkins;
        final room = made.length < kMaxCustomSkins;
        return StreamBuilder<Map<String, String>>(
          stream: db.watchPrefs(),
          builder: (context, prefSnap) {
            final active = Settings(prefSnap.data ?? const {}).activeSkin;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mescola gli stili dei gattini che hai adottato: pelo, muso, occhi, accessori ed effetti. '
                  'Puoi crearne fino a $kMaxCustomSkins.',
                  style: TextStyle(color: tc.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                  children: [
                    for (final s in made) _SkinTile(skin: s, owned: true, active: s.id == active, balance: 0),
                    if (room)
                      TapScale(
                        onTap: () => openKittenMaker(context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: tc.surface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(kRadius),
                            border: Border.all(color: tc.accent.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, size: 34, color: tc.accent),
                              const SizedBox(height: 4),
                              Text('Nuovo', style: TextStyle(fontWeight: FontWeight.w800, color: tc.accent)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  room
                      ? '${made.length} di $kMaxCustomSkins creati. Tocca un gattino per usarlo o modificarlo.'
                      : 'Hai già $kMaxCustomSkins gattini: modificane o eliminane uno per crearne un altro.',
                  style: TextStyle(color: tc.muted, fontSize: 12.5),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
