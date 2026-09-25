import 'package:flutter/material.dart';

import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';

/// How Taime works, in five short pages. Shown once at first launch and from
/// Impostazioni → Come funziona.
Future<void> showOnboarding(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: _Onboarding(),
    ),
  );
}

class _Page {
  const _Page(this.title, this.text, this.skin, {this.pose, this.growth = 1});
  final String title, text;
  final String skin;
  final Pose? pose;
  final double growth;
}

const _pages = [
  _Page(
    'Benvenuto in Taime',
    'Scegli su cosa lavori e premi Inizia. Nasce un gattino che cresce mentre ti concentri: diventa adulto dopo un\'ora.',
    'biscotto',
    growth: 0.2,
  ),
  _Page(
    'Pausa quando serve',
    'Con Pausa tutto diventa arancione e il gattino si fa un pisolino. I promemoria suonano come una sveglia, anche con il Non disturbare.',
    'nuvola',
    pose: Pose.dorme,
  ),
  _Page(
    'Il recinto',
    'Ogni ora di concentrazione lascia un gatto adulto nel recinto, i minuti in più un cucciolo. In Panoramica ogni tile è un giorno.',
    'pezzetta',
    pose: Pose.pagnotta,
  ),
  _Page(
    'Crocchette e negozio',
    'Ogni minuto di lavoro vale una crocchetta. Spendile nel Negozio per adottare nuovi gattini, dai comuni ai leggendari.',
    'merlino',
  ),
  _Page(
    'To-do veloci',
    'Scrivi come parli: "studiare fisica domani alle 15 #studio !1". Data, ora, categoria e priorità si riconoscono da sole.',
    'chef',
  ),
];

class _Onboarding extends StatefulWidget {
  const _Onboarding();

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final last = _i == _pages.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 340,
            child: PageView.builder(
              controller: _pc,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) {
                final p = _pages[i];
                return Column(
                  children: [
                    KittenView(skin: skinById(p.skin), pose: p.pose, growth: p.growth, size: 170, actions: false),
                    const SizedBox(height: 14),
                    Text(p.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    Text(
                      p.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tc.muted, fontSize: 15, height: 1.45),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.emphasized,
                  width: i == _i ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _i ? tc.accent : tc.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (!last)
                PillButton(label: 'Salta', kind: PillKind.ghost, onTap: () => Navigator.pop(context)),
              const Spacer(),
              PillButton(
                label: last ? 'Iniziamo' : 'Avanti',
                icon: last ? Icons.favorite_rounded : Icons.arrow_forward_rounded,
                onTap: () {
                  if (last) {
                    Navigator.pop(context);
                  } else {
                    _pc.nextPage(duration: Motion.slow, curve: Motion.emphasized);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
