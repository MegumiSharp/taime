# Taime — Specifiche 2.2

App Android personale per concentrarsi e tracciare il tempo, nello spirito di Forest: mentre lavori un gattino cresce, il tempo diventa crocchette per comprare nuovi gattini, i giorni riempiono un recinto. Nessun account, nessun server: dati in SQLite sul telefono, con backup.

## Novità 2.2
- **Note** nella scheda To-do (interruttore To-do | Note): lista infinita, colori, filtro per colore, ordine per data, data e promemoria con notifica.
- **To-do ripensati**: sezioni Oggi / Questa settimana / Più avanti. Con una data decide la data, altrimenti la durata scelta. Nuovo to-do in una piccola finestra con scelte a un tocco. "Svuota" per i completati, swipe per eliminarne uno.
- **Crea il tuo gattino** (Negozio → Crea): fino a 5, con pelo, motivo, muso, pancia e zampe, occhi, accessori ed effetti sbloccati dai gattini adottati.
- **69 gattini**: 17 nuovi, tra cui Wendy (europea soriana) e Minou (tuxedo col papillon), panda, rana, ape, unicorno, fenice. Nuovi effetti: pioggerella, fulmini, foglie, braci.
- Gattini ritoccati: ombra morbida sotto il mento invece della linea, collarini e sciarpe attorno al collo, berretto, cornini, casco spaziale vero. Nelle scene casuali si muove la zampa del gattino; nel negozio le scene partono prima.
- La pausa automatica accende lo schermo come una sveglia (notifica a schermo intero).
- Scheda "Oggi" nel Focus: ore del giorno per attività, obiettivo e giorni di fila.
- Correzioni: scroll della Panoramica, crocchette che si ricontavano, nota del focus persa cambiando scheda, testo troppo vicino alla bolla, paletti doppi nel recinto, alone delle schede (soprattutto nel tema scuro).

## Novità 2.1
- Barra in basso solo icone; recinto sempre quadrato (settimana 3×3, mese 6×6, anno 4×4) senza scritte.
- 52 gattini (20 nuovi: mago, strega, angioletto, fantasmino, drago, astronauta...), effetti (fluttuare, magia, bolle, neve, cuori, stelle cadenti, coriandoli, fuochi fatui); ogni leggendario ha un effetto.
- Azioni casuali dei gattini ogni 25–70 s: mosca, bottiglia, sbadiglio, farfalla, gomitolo, starnuto.
- Notifica ridisegnata (non più stile musicale), si aggiorna da sola ogni 30 s e torna dopo il riavvio.
- Avviso se l'app resta in background 15 minuti con un timer attivo (suono di notifica predefinito).
- Obiettivo giornaliero con giorni di fila, Album dei gattini, widget Home, backup automatico settimanale in Download/Taime, pausa lunga del Pomodoro, spiegazione alla prima apertura.

## Stack
- Flutter 3.47, Android. Database **drift** (schema v3, migrazioni dalla 1.0 e dalla 2.x testate).
- Plugin locale `app/packages/taime_native` (Kotlin): notifica del focus con layout personalizzato in un foreground service (si aggiorna ogni 30 s), widget Home, ripristino dopo il riavvio, backup in Download, selettore dei suoni di sistema, anteprima audio sul canale sveglia.
- `flutter_local_notifications` per i promemoria (canale "allarme", passano il Non disturbare) e per i to-do.
- Icone Material "rounded", font Nunito incluso (200–800).

## Schermate
- **Focus**: attività in alto (lista scorribile sfocata, editor con 28 colori + colore libero e 140+ icone cercabili), nota, gattino nella bolla, cronometro (conto alla rovescia solo in Pomodoro), "Annulla (10)" nei primi 10 s, Pausa/Termina, pausa arancione con caffè e gattino che dorme, grafico stile GitHub delle ultime 20 settimane, riepilogo a fine sessione.
- **To-do**: Oggi (scaduti in cima) / Questa settimana / Più avanti, categorie a tendina, finestra "Nuovo to-do" con date in italiano evidenziate, ricorrenze, priorità, sottotask, promemoria, swipe, "Svuota" i completati, "Annulla", "Avvia focus".
- **Note**: accanto ai to-do; colore, data, promemoria; la prima riga fa da titolo.
- **Panoramica**: recinto isometrico (ogni tile un giorno, anno = 12 mesi), dettaglio giorno = registro modificabile, statistiche (distribuzione, attività, trend, abitudini, gattini preferiti, totale di sempre), calendario.
- **Negozio**: In evidenza / Tutti / Album / Crea, anteprima con pose e crescita, acquisto, gattini creati da te.
- **Impostazioni** (icona in alto a sinistra nel Focus): temi Salvia / Lavanda / Azzurro polvere / Personalizzato (Coolors), chiaro/scuro/sistema, attività, pause, suoni, Pomodoro, obiettivo, backup.

## Regole
- **Crescita**: in base al lavoro della sessione (la pausa la congela). Neonato 0', Cucciolo 10', Giovane 25', Quasi adulto 45', Adulto 60'.
- **Recinto**: per sessione, un gatto adulto per ogni ora completa di lavoro + un cucciolo per i minuti restanti (se almeno 5). Le pause non contano. Calcolato dalle sessioni, quindi le modifiche al registro si riflettono.
- **Crocchette**: 1 per minuto di lavoro (anche lo storico della 1.0) meno la spesa. Saldo mostrato mai sotto 0.
- **Gattini**: 69 skin disegnate in codice (`lib/kitten/`), 4 rarità, 3 gratuite, più fino a 5 create da te (tabella `custom_skins`; quelle eliminate restano per disegnare le sessioni passate).
- **Timer**: tutto lo stato è fatto di timestamp nel database; le scadenze (pausa automatica, fine pomodoro) si applicano con `Tracker.materialize()`.
- **Suoni**: 5 inclusi (generati da `tool/make_sounds.py`), suoni del telefono, file personale; flusso sveglia, una volta o finché non tocchi (max 1 min).

## Dati e backup
- Backup JSON v3 (sessioni, attività, gattini acquistati e creati, to-do, note, impostazioni); l'import accetta anche i backup v1 e v2. Backup automatico settimanale in Download/Taime (tiene gli ultimi 4).
- CSV per fogli di calcolo.

## Sviluppo
- Test: `flutter test` (migrazione, parser date, regola dei gatti, crocchette, contrasto temi, timer, palette).
- Anteprima gattini: `flutter test tool/render_kittens_test.dart` → `build/kittens/*.png`.
- Build: `flutter build apk --release --split-per-abi` da `app/`, sempre con la chiave `taime-release-key.jks` (non su GitHub: tienine una copia a parte).
- Le build di debug si installano come "Taime dev", accanto all'app vera.
