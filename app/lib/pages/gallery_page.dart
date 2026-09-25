import 'package:flutter/material.dart';

import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'shop_page.dart' show rarityColor, showSkinPreview, ownedSkinIds;

/// Every kitten, every growth stage, every pose, in one scroll.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  bool _animate = true;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: FutureBuilder<Set<String>>(
            future: ownedSkinIds(),
            builder: (context, snap) {
              final owned = snap.data ?? const <String>{};
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                itemCount: kSkins.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Row(
                      children: [
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                        Expanded(child: Text('Galleria · ${kSkins.length} gattini', style: Theme.of(context).textTheme.titleLarge)),
                        const Text('Animati'),
                        Switch(value: _animate, onChanged: (v) => setState(() => _animate = v)),
                      ],
                    );
                  }
                  final s = kSkins[i - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SoftCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      onTap: () => showSkinPreview(context, s, owned: owned.contains(s.id), balance: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(width: 8),
                              Text(
                                s.rarity.label,
                                style: TextStyle(
                                  color: rarityColor(s.rarity, dark: tc.dark),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Text(s.free ? 'Gratis' : '${s.price}', style: TextStyle(color: tc.muted, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var st = 0; st < kStageMinutes.length; st++)
                                  _Cell(
                                    label: kStageNames[st],
                                    child: KittenView(skin: s, growth: kStageMinutes[st] / 60, size: 78, animate: _animate),
                                  ),
                                for (final p in Pose.values.where((p) => p != s.pose))
                                  _Cell(label: p.label, child: KittenView(skin: s, pose: p, size: 78, animate: _animate)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Column(
      children: [
        child,
        Text(label, style: TextStyle(fontSize: 11, color: context.tc.muted, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
