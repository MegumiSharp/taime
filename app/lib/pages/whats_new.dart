import 'package:flutter/material.dart';

import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../theme.dart';
import '../ui/widgets.dart';

/// Bump when there is something new to tell: the dialog shows once per value.
const String kNewsVersion = '2.4';

const _news = <(IconData, String, String)>[
  (
    Icons.auto_awesome_rounded,
    'Wendy e Minou leggendarie',
    'Ridisegnate dalle foto: Wendy europea variegata con gli occhi verdi, farfalle e scintille smeraldo; '
        'Minou tuxedo con il naso nero, gli occhi gialli e il suo piumino giallo. Se le avevi già, sono ancora tue.',
  ),
  (
    Icons.wb_sunny_rounded,
    'Ore di oggi sotto Inizia',
    'A timer fermo o in pausa la scheda Oggi sta sotto Inizia; mentre lavori restano solo i trattini dell\'obiettivo.',
  ),
  (
    Icons.edit_note_rounded,
    'Dalla 2.3',
    'Controllo delle notifiche, widget dei to-do, to-do rimasti indietro, ricerca, note con caselle e fissate, '
        'focus da un to-do e gattini con colori ed effetti a scelta.',
  ),
];

/// What changed, shown once after an update (see `main.dart`).
Future<void> showWhatsNew(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final tc = context.tc;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KittenView(skin: skinById('wendy'), size: 104, showcase: true),
                  KittenView(skin: skinById('minou'), size: 104, showcase: true),
                ],
              ),
              Text('Novità di Taime', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  children: [
                    for (final (icon, title, text) in _news)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: tc.accentSoft, shape: BoxShape.circle),
                              child: Icon(icon, size: 18, color: tc.accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(text, style: TextStyle(color: tc.muted, fontSize: 13.5, height: 1.35)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: PillButton(
                  label: 'Andiamo',
                  icon: Icons.favorite_rounded,
                  expand: true,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
