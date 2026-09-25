# Taime — Specifiche 2.1

App Android personale per concentrarsi e tracciare il tempo, nello spirito di Forest: mentre lavori un gattino cresce, il tempo diventa crocchette per comprare nuovi gattini, i giorni riempiono un recinto. Nessun account, nessun server: dati in SQLite sul telefono, con backup.

La richiesta completa della 2.0 è in `Aggiornamento Taime/PROMPT Taime 2.0.md`.

## Novità 2.1
- Barra in basso solo icone; recinto sempre quadrato (settimana 3×3, mese 6×6, anno 4×4) senza scritte.
- 52 gattini (20 nuovi: mago, strega, angioletto, fantasmino, drago, astronauta...), effetti (fluttuare, magia, bolle, neve, cuori, stelle cadenti, coriandoli, fuochi fatui); ogni leggendario ha un effetto.
- Azioni casuali dei gattini ogni 25–70 s: mosca, bottiglia, sbadiglio, farfalla, gomitolo, starnuto.
- Notifica ridisegnata (non più stile musicale), si aggiorna da sola ogni 30 s e torna dopo il riavvio.
- Avviso se l'app resta in background 15 minuti con un timer attivo (suono di notifica predefinito).
- Obiettivo giornaliero con giorni di fila, Album dei gattini, widget Home, backup automatico settimanale in Download/Taime, pausa lunga del Pomodoro, spiegazione alla prima apertura.

## Stack
- Flutter 3.47, Android. Database **drift** (schema v2, migrazione dalla 1.0 testata).
- Plugin locale `app/packages/taime_native` (Kotlin): notifica "player" con MediaSession in un foreground service, selettore dei suoni di sistema, anteprima audio sul canale sveglia, uri condivisibili per i file audio.
- `flutter_local_notifications` per i promemoria (canale "allarme", passano il Non disturbare) e per i to-do.
- Icone Material "rounded", font Nunito incluso (200–800).

## Schermate
- **Focus**: attività in alto (lista scorribile sfocata, editor con 28 colori + colore libero e 140+ icone cercabili), nota, gattino nella bolla, cronometro (conto alla rovescia solo in Pomodoro), "Annulla (10)" nei primi 10 s, Pausa/Termina, pausa arancione con caffè e gattino che dorme, grafico stile GitHub delle ultime 20 settimane, riepilogo a fine sessione.
- **To-do**: Oggi (scaduti in cima) / Prossimi 7 giorni / Tutti (riordinabili), categorie a tendina, inserimento rapido con date in italiano evidenziate, ricorrenze, priorità, sottotask, promemoria, swipe, "Annulla", "Avvia focus".
- **Panoramica**: recinto isometrico (ogni tile un giorno, anno = 12 mesi), dettaglio giorno = registro modificabile, statistiche (distribuzione, attività, trend, abitudini, gattini preferiti, totale di sempre), calendario.
- **Negozio**: In evidenza / Tutti / I miei gattini, anteprima con pose e crescita, acquisto.
- **Impostazioni** (icona in alto a sinistra nel Focus): temi Salvia / Lavanda / Azzurro polvere / Personalizzato (Coolors), chiaro/scuro/sistema, attività, pause, suoni, Pomodoro, galleria gattini, backup.

## Regole
- **Crescita**: in base al lavoro della sessione (la pausa la congela). Neonato 0', Cucciolo 10', Giovane 25', Quasi adulto 45', Adulto 60'.
- **Recinto**: per sessione, un gatto adulto per ogni ora completa + un cucciolo per i minuti restanti (se almeno 5). Calcolato dalle sessioni, quindi le modifiche al registro si riflettono.
- **Crocchette**: 1 per minuto di lavoro (anche lo storico della 1.0) meno la spesa. Saldo mostrato mai sotto 0.
- **Gattini**: 32 skin disegnate in codice (`lib/kitten/`), 4 rarità, 3 gratuite.
- **Timer**: tutto lo stato è fatto di timestamp nel database; le scadenze (pausa automatica, fine pomodoro) si applicano con `Tracker.materialize()`.
- **Suoni**: 5 inclusi (generati da `tool/make_sounds.py`), suoni del telefono, file personale; flusso sveglia, una volta o finché non tocchi (max 1 min).

## Dati e backup
- Backup JSON v2 (sessioni, attività, gattini acquistati, to-do, impostazioni); l'import accetta anche i backup v1.
- CSV per fogli di calcolo.

## Sviluppo
- Test: `flutter test` (migrazione, parser date, regola dei gatti, crocchette, contrasto temi, timer, palette).
- Anteprima gattini: `flutter test tool/render_kittens_test.dart` → `build/kittens/*.png`.
- Build: `flutter build apk --release --split-per-abi` da `app/`, sempre con la chiave `taime-release-key.jks` (non su GitHub: tienine una copia a parte).
- Le build di debug si installano come "Taime dev", accanto all'app vera.
