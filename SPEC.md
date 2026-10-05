# Taime — Specifiche 2.5.2

App Android personale per concentrarsi e tracciare il tempo, nello spirito di Forest: mentre lavori un gattino cresce, il tempo diventa crocchette per comprare nuovi gattini, i giorni riempiono un recinto. Nessun account, nessun server: dati in SQLite sul telefono, con backup.

## Novità 2.5.2
- Tolto l'avviso "Il timer è ancora attivo": suonava 15 minuti dopo essere usciti dall'app con il timer avviato, quindi a metà di ogni focus col telefono bloccato (prima della 2.5.1 non partiva mai). La notifica del timer è già sempre visibile e le pause hanno i loro promemoria.

## Novità 2.5.1
- Corretto: nessun promemoria programmato partiva (fine pausa, pausa automatica, pomodoro, to-do, note, "Prova della pausa"), e i tasti nelle notifiche (Riprendi, Sì, No continua…) non facevano nulla. Al manifest mancavano i ricevitori di flutter_local_notifications. Un test ora controlla che ci siano.

## Novità 2.5
- **Cerca aggiornamenti** (Impostazioni → Aiuto): legge l'ultima release di GitHub, scarica l'APK adatto al telefono (arm64 o arm32) e apre l'installazione di Android, che lo mette sopra senza perdere dati. La prima volta Android chiede di permettere a Taime di installare app. È l'unico momento in cui Taime va in rete e non invia nulla; Android accetta solo APK firmati con la stessa chiave.

## Novità 2.4.2
- Corretto: la notifica stile sveglia della pausa automatica (e del pomodoro finito) non arrivava. Allo scadere la pausa partiva subito e il suo promemoria "Torna al lavoro" prendeva il posto della sveglia, cancellandola. Ora sono due promemoria separati; mettendo in pausa a mano la sveglia della pausa automatica viene annullata.

## Novità 2.4.1
- Minou: naso nero e occhi gialli. Wendy: mantello europeo variegato (chiazze calde nocciola sfumate, picchiettature chiare e scure, macchie irregolari, coda con tono caldo). In "Crea il tuo gattino" il naso può essere rosa o nero.

## Novità 2.4
- **Wendy e Minou leggendarie**, ridisegnate dalle foto delle gatte vere: Wendy europea maculata (mantello "maculato" nuovo: M in fronte, righe dagli occhi, macchie sui fianchi, petto chiaro, coda ad anelli) con farfalle e scintille smeraldo; Minou tuxedo con la striscia bianca, la macchiolina sul naso e il piumino giallo che dondola. Chi le aveva già le tiene.
- "Crea il tuo gattino": la macchiolina sul naso si sblocca con Minou; il papillon passa a Bruno.

## Novità 2.3.1
- La scheda "Oggi" (ore, obiettivo, attività, giorni di fila) sta sotto "Inizia" a timer fermo o in pausa; mentre lavori restano solo dei trattini, uno per ogni mezz'ora dell'obiettivo, colorati per attività.
- Corretto: in 2.3.0 il Focus poteva non accorgersi che il timer era partito (il timer contava comunque).

## Novità 2.3
- **Ore di oggi in grande** nel Focus quando il timer è fermo o in pausa (ore, barra per attività, obiettivo, giorni di fila); mentre lavori resta la scheda piccola in basso. Il contatore dei gatti della sessione è in alto accanto alle crocchette, fuori dal cerchio; il cuscino del gattino sta dentro la bolla.
- **Controlla le notifiche** (Impostazioni): permessi, canali, sveglie precise, schermo che si accende, batteria, avvio automatico su Xiaomi; ogni problema con "Sistema"; prove: promemoria adesso, pausa tra 10 secondi a schermo spento, to-do. I promemoria vengono programmati prima di ogni altra cosa e, se il telefono rifiuta le sveglie precise, ripiegano su modalità meno precise invece di sparire.
- **Widget dei to-do di oggi** (fino a 5, spunta dal widget, "+" per un nuovo to-do).
- **To-do**: "Rimasti indietro" in cima a Oggi con "Tutti a oggi"; quelli senza data mostrano "da N giorni"; ricerca (senza badare ad accenti e maiuscole).
- **Note**: caselle da spuntare (anche direttamente dalla scheda), fissate in alto (tieni premuto), ricerca.
- **Focus da un to-do**: a fine sessione "Hai finito …?" lo spunta.
- **Crea il tuo gattino**: colore degli accessori e fino a due effetti.
- **Novità**: una finestra, una volta, dopo ogni aggiornamento (anche da Impostazioni → Aiuto).
- **Icona** nuova: silhouette bianca del gattino con gli occhi vuoti su verde salvia; la stessa, piccola, nella barra di stato.
- Revisione: codice morto rimosso, accessibilità (etichette e stati per i lettori di schermo, testo grande), query al database non più ripetute ogni secondo nel Focus, test delle schermate su telefono piccolo, chiaro/scuro e testo ingrandito.

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
- Avviso se l'app resta in background 15 minuti con un timer attivo (tolto nella 2.5.2).
- Obiettivo giornaliero con giorni di fila, Album dei gattini, widget Home, backup automatico settimanale in Download/Taime, pausa lunga del Pomodoro, spiegazione alla prima apertura.

## Stack
- Flutter 3.47, Android. Database **drift** (schema v4, migrazioni dalla 1.0, 2.0/2.1 e 2.2 testate).
- Plugin locale `app/packages/taime_native` (Kotlin): notifica del focus con layout personalizzato in un foreground service (si aggiorna ogni 30 s), widget Home, ripristino dopo il riavvio, backup in Download, selettore dei suoni di sistema, anteprima audio sul canale sveglia.
- `flutter_local_notifications` per i promemoria (canale "allarme", passano il Non disturbare) e per i to-do.
- Icone Material "rounded", font Nunito incluso (200–800).

## Schermate
- **Focus**: attività in alto (lista scorribile sfocata, editor con 28 colori + colore libero e 140+ icone cercabili), nota, gattino nella bolla, cronometro (conto alla rovescia solo in Pomodoro), "Annulla (10)" nei primi 10 s, Pausa/Termina, pausa arancione con caffè e gattino che dorme, grafico stile GitHub delle ultime 20 settimane, riepilogo a fine sessione.
- **To-do**: Oggi (scaduti in cima) / Questa settimana / Più avanti, categorie a tendina, finestra "Nuovo to-do" con date in italiano evidenziate, ricorrenze, priorità, sottotask, promemoria, swipe, "Svuota" i completati, "Annulla", "Avvia focus".
- **Note**: accanto ai to-do; colore, data, promemoria, caselle da spuntare, fissate in alto, ricerca; la prima riga fa da titolo.
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
- Backup JSON v4 (sessioni, attività, gattini acquistati e creati, to-do, note, impostazioni); l'import accetta anche i backup v1–v3 e, se il file è danneggiato, lascia i dati intatti. Backup automatico settimanale in Download/Taime (tiene gli ultimi 4).
- CSV per fogli di calcolo.

## Sviluppo
- Test: `flutter test` (migrazioni, parser date, regola dei gatti, crocchette, contrasto temi, timer, palette, to-do e note, e tutte le schermate su un telefono piccolo, chiaro/scuro, testo ingrandito).
- Icona: `flutter test tool/make_icon_test.dart` rigenera tutte le misure.
- Anteprima gattini: `flutter test tool/render_kittens_test.dart` → `build/kittens/*.png`.
- Build: `flutter build apk --release --split-per-abi` da `app/`, sempre con la chiave `taime-release-key.jks` (non su GitHub: tienine una copia a parte).
- Le build di debug si installano come "Taime dev", accanto all'app vera.
