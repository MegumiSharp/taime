import 'package:flutter/material.dart';

import '../kitten/skins.dart';
import '../kitten/view.dart';
import '../theme.dart';
import '../ui/widgets.dart';

/// Bump when there is something new to tell: the dialog shows once per value.
const String kNewsVersion = '2.3';

const _news = <(IconData, String, String)>[
  (
    Icons.wb_sunny_rounded,
    'Le ore di oggi in grande',
    'A timer fermo o in pausa, in cima al Focus: ore, obiettivo e giorni di fila.',
  ),
  (
    Icons.notifications_active_rounded,
    'Controllo delle notifiche',
    'In Impostazioni: vedi cosa blocca i promemoria, lo sistemi con un tocco e provi la pausa.',
  ),
  (Icons.widgets_rounded, 'Widget dei to-do', 'I to-do di oggi sulla schermata Home, da spuntare senza aprire l\'app.'),
  (
    Icons.history_rounded,
    'To-do rimasti indietro',
    'In cima a Oggi, con "Tutti a oggi". Quelli senza data dicono da quanti giorni aspettano.',
  ),
  (Icons.search_rounded, 'Ricerca', 'Nei to-do e nelle note, dalla lente in alto.'),
  (
    Icons.checklist_rounded,
    'Note con caselle e fissate',
    'Liste da spuntare dentro le note; tieni premuta una nota per fissarla in alto.',
  ),
  (
    Icons.task_alt_rounded,
    'Focus da un to-do',
    'Alla fine della sessione Taime ti chiede se l\'hai finito e lo spunta per te.',
  ),
  (Icons.brush_rounded, 'Gattini più tuoi', 'In "Crea il tuo gattino" scegli il colore degli accessori e due effetti.'),
  (
    Icons.edit_note_rounded,
    'Dalla 2.2',
    'Note, to-do per Oggi / Settimana / Più avanti, Crea il tuo gattino, 17 gattini nuovi (Wendy e Minou!) e lo schermo che si accende alla pausa.',
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
              KittenView(skin: skinById('wendy'), size: 110, showcase: true),
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
