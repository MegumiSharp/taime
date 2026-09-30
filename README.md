<img src="icon.png" width="96" alt="Icona di Taime: un gattino bianco su verde salvia">

# Taime

App Android personale per concentrarsi e tenere traccia del tempo, nello spirito di Forest: mentre lavori un gattino cresce, i minuti diventano crocchette per adottare altri gattini e ogni giorno riempie un recinto.

Nessun account, nessun server, nessuna pubblicità: tutto resta sul telefono (SQLite), con backup automatico ed export.

## Cosa fa

- **Focus**: scegli l'attività, premi Inizia e il gattino cresce fino a diventare adulto dopo un'ora. Hai pausa, Pomodoro con pausa lunga e pausa automatica che accende lo schermo come una sveglia. La scheda "Oggi" mostra le ore del giorno.
- **To-do e note**: to-do divisi in Oggi / Questa settimana / Più avanti, con date scritte in italiano ("domani alle 15"), ripetizioni, promemoria e ricerca. Le note hanno colori, caselle da spuntare, date, notifiche e si possono fissare in alto.
- **Panoramica**: recinto isometrico (giorno, settimana, mese, anno), registro modificabile e statistiche.
- **Negozio**: 69 gattini disegnati in codice in 4 rarità, più un album. Con "Crea il tuo gattino" ne componi fino a 5 con gli stili di quelli adottati.
- **Notifica e widget**: la notifica del focus si aggiorna da sola ogni 30 s. Due widget Home: il timer (Inizia / Pausa / Termina) e i to-do di oggi. Dopo un riavvio tornano. In Impostazioni, "Controlla le notifiche" trova e sistema quello che le blocca.

Le specifiche complete sono in [SPEC.md](SPEC.md).

## Installare

1. Scarica l'APK dall'ultima release: `Taime-x.y.z-arm64.apk` va bene per quasi tutti i telefoni recenti, `arm32` per quelli vecchi.
2. Aprilo sul telefono e consenti "Installa app sconosciute" per il browser o il file manager.
3. Gli aggiornamenti si installano sopra la versione precedente senza perdere i dati, purché siano firmati con la stessa chiave (vedi sotto).

Su MIUI/HyperOS, per installare via USB abilita "Installa tramite USB" nelle Opzioni sviluppatore.

## Lavorarci

Serve Flutter 3.47 (Dart 3.13) con l'SDK Android.

```bash
cd app
flutter pub get
flutter test                      # test di migrazione, timer, parser, gattini...
flutter run                       # su un telefono collegato: si installa come "Taime dev"
```

Dopo aver cambiato le tabelle in `lib/db.dart`, rigenera il codice di drift:

```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

Se cambi lo schema, alza `schemaVersion`, aggiungi la migrazione e un test in `test/migration_test.dart` (gli schemi delle versioni vecchie sono in `test/fixtures/`).

L'icona si rigenera con `flutter test tool/make_icon_test.dart` (scrive tutte le misure in `android/`).

Per vedere i gattini senza telefono:

```bash
cd app
flutter test tool/render_kittens_test.dart   # scrive build/kittens/*.png
```

### Struttura

```
app/
  lib/
    main.dart            avvio, barra in basso, notifiche
    db.dart              tabelle drift e query
    tracker.dart         timer fatto di timestamp (pausa, pomodoro, scadenze)
    kitten/              catalogo (skins.dart), disegno (painter.dart), animazioni (view.dart)
    pages/               Focus, Panoramica, recinto, Negozio, Crea il tuo gattino, Impostazioni, notifiche
    todo/                to-do, note, parser delle date in italiano
    backup.dart          backup JSON, CSV, backup automatico settimanale
  packages/taime_native/ plugin Kotlin: notifica del focus, widget, backup in Download
  test/                  test
  tool/                  anteprima dei gattini, icona, generatore dei suoni
```

### Build di release

```bash
cd app
flutter build apk --release --split-per-abi
```

La firma legge `app/android/key.properties`, che punta a `taime-release-key.jks`. Né la chiave né `key.properties` sono su GitHub: tienine una copia al sicuro. **Firma sempre con la stessa chiave**, altrimenti l'aggiornamento non si installa sopra quello vecchio e per installarlo bisogna disinstallare l'app, perdendo i dati.

Esempio di `key.properties` (con `/` anche su Windows):

```
storePassword=...
keyPassword=...
keyAlias=taime
storeFile=C:/percorso/taime-release-key.jks
```
