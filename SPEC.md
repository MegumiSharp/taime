# Time Tracker — Specifiche v1

App Android (APK) personale per cronometrare il tempo speso sulle attività. Nessun account, nessun server: dati in SQLite sul telefono, con export/import.

## Stack
- **Flutter** (Android ora; desktop/web possibili in futuro dallo stesso codice)
- **drift** (SQLite) — database locale
- **flutter_local_notifications** — notifica fissa con cronometro, promemoria programmati con suono custom (funzionano ad app chiusa)
- **fl_chart** — grafici
- **Icone Material "rounded"** (incluse in Flutter). `phosphor_flutter` è stato scartato: incompatibile con Flutter 3.47 (`IconData` è diventata una classe `final`)
- Font **Nunito** incluso nell'APK (offline), cifre tabulari per il timer
- **share_plus / file_picker** — export/import

## Concetti
- **Attività**: la categoria su cui si lavora (es. Studio, Palestra, Pulizie). Nome, colore, icona. Una per sessione, niente tag.
- **Sessione**: da Start a Stop, su un'attività, con nota opzionale.
- **Segmento**: pezzo di una sessione, tipo `lavoro` o `pausa`. Tempo lavorato = somma dei segmenti lavoro; le pause si contano a parte.

## Timer (schermata principale)
- Pulsante circolare grande con anello di progresso. Sotto: attività selezionata (tap per cambiarla), nota opzionale.
- **Start** → apre sessione + segmento lavoro.
- **Pausa** → chiude il segmento lavoro, apre segmento pausa. Il cronometro principale si ferma, parte il cronometro della pausa (visibile, stile diverso).
- **Riprendi** → chiude la pausa, apre nuovo segmento lavoro; il cronometro principale riparte da dove era.
- **Stop** → chiude tutto, sessione salvata.
- Cambiare attività durante una sessione = riassegna la sessione corrente (per correggere un avvio sbagliato). Avviare un'altra attività dalle recenti ferma la corrente e ne apre una nuova.
- Lista "recenti" sotto il timer con ▶ per ripartire al volo.
- **Notifica fissa** mentre il timer è attivo: tempo che scorre + pulsanti Pausa/Riprendi e Stop.
- Stato salvato solo nel DB (timestamp): chiusura forzata o riavvio del telefono non perdono nulla.

### Promemoria
- **Fai una pausa**: dopo X di lavoro continuo (default 2h, configurabile, disattivabile) → notifica con suono. Comportamento scelto in Impostazioni:
  - **Solo avviso** (default): notifica, il timer continua.
  - **Pausa automatica**: allo scadere di X il lavoro si ferma e parte la pausa; notifica con suono "Prendi la pausa?" con pulsanti **Sì** / **No, continua**.
    - Sì → la pausa prosegue (con il promemoria di fine pausa).
    - No → la pausa viene annullata e il tempo tra lo scadere e la risposta conta come lavoro, senza buchi; il promemoria si riprogramma tra altri X.
    - Nessuna risposta → resta in pausa; se era un errore si corregge dal Registro.
  - Il passaggio avviene all'orario esatto anche con app chiusa o telefono bloccato: lo stato è fatto di timestamp, quindi la pausa risulta iniziata allo scadere esatto, non a quando rispondi.
- **Suono**: i promemoria usano il suono di notifica di sistema (scegli tu quale dalle impostazioni Android del canale "Promemoria"). Un file audio personale dentro l'app è rimandato.
- **Fine pausa**: dopo Y di pausa (default 15 min, configurabile) → notifica con suono "torna al lavoro". Ignorabile, la pausa continua finché non premi Riprendi.
- Programmati all'inizio del segmento, cancellati al cambio di stato.

### Pomodoro (opzionale)
- Interruttore Cronometro / Pomodoro sulla schermata timer, durate in Impostazioni (default 25 lavoro / 5 pausa / 15 pausa lunga ogni 4).
- Conto alla rovescia; a fine lavoro suono + passaggio automatico alla pausa; a fine pausa suono, il lavoro successivo si avvia con un tap.
- Salva sessioni/segmenti identici al cronometro → stesse statistiche.

## Registro (log modificabile)
- Sessioni raggruppate per giorno, con totale del giorno.
- Card sessione: attività · orario inizio–fine · tempo lavoro · tempo pausa, con mini-timeline colorata dei segmenti.
- Tap → foglio di modifica: attività, nota, lista segmenti con orari modificabili (selettori nativi), aggiungi/elimina segmento, elimina sessione.
- Aggiunta manuale di una sessione ("ho dimenticato di avviarlo").
- Validazione: fine dopo inizio, avviso su sovrapposizioni. Eliminazione con "Annulla".

## Statistiche
- Periodo: Giorno / Settimana / Mese / Anno, con frecce avanti/indietro.
- Totale lavoro (e pausa) del periodo.
- Barre per sotto-periodo (ore / giorni / mesi) impilate per attività.
- Ciambella + tabella attività → ore → %.
- Mappa attività annuale stile GitHub.
- Totale di sempre per attività.

## Impostazioni
- Tema: Scuro / Chiaro / Sistema.
- Palette Coolors (incolla URL o codici hex), anteprima, ripristina default.
- Attività: crea, rinomina, colore, icona, archivia, riordina. Default: Studio, Palestra, Pulizie.
- Promemoria pausa (on/off, durata, comportamento: solo avviso / pausa automatica), fine pausa (durata), suono (preimpostati o file personale), volume/vibrazione.
- Pomodoro: durate.
- Primo giorno della settimana.
- Backup: esporta JSON (completo, reimportabile), esporta CSV, importa JSON.

## Design
- Minimale, card in stile bento (raggio 20–24px, bordi sottili), navigazione a pillola in basso: **Timer · Registro · Statistiche · Impostazioni**.
- **Scuro**: sfondo quasi nero neutro con appena una sfumatura della tonalità principale.
- **Chiaro**: sfondo guscio d'uovo (~#F3EFE6), testo grigio scuro caldo, niente bianco puro.
- **Regole palette** (in OKLCH): la palette colora solo accenti e attività; gli sfondi restano neutri (croma ≤ 0.02). Gli accenti vengono ricondotti a luminosità/saturazione sicure per il tema (scuro: L 0.70–0.82; chiaro: L 0.45–0.60; croma max ~0.14), il testo sopra l'accento è scelto automaticamente nero/bianco per contrasto ≥ 4.5. Uno sfondo fucsia è impossibile per costruzione.

## Modello dati
```
activities  id, name, color, icon, archived, sort
sessions    id, activity_id, note, started_at, ended_at (null = in corso)
segments    id, session_id, kind (work|pause), started_at, ended_at (null = in corso)
settings    key, value
```
Al massimo un segmento aperto alla volta.

## Fuori dalla v1
Desktop, sincronizzazione, backup automatico, tag, obiettivi giornalieri.

## Note operative
- APK firmato sempre con la stessa chiave: `taime-release-key.jks` nella cartella del progetto, password in `app/android/key.properties`. **Da conservare**: senza, gli aggiornamenti non si installano sopra e serve disinstallare (backup → reinstalla → importa).
- Build: `flutter build apk --release` da `app/`.
- Permessi: notifiche, sveglie esatte (promemoria puntuali anche in risparmio energetico).
