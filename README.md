# SommoMemory

Il memory di Michele Tagliabue, ripristinato per Android, iPhone, iPad e browser.

Il gioco si chiama **SommoMemory**. SKU `mymemory-ios` e bundle/package `cc.sommomi.mymemory` restano invariati. Il sito e il multiplayer usano `sommomemory.sommomi.cc`.

**Gioca:** https://sommomemory.sommomi.cc · **Privacy:** https://sommomemory.sommomi.cc/privacy · **Assistenza:** https://sommomemory.sommomi.cc/support

**English:** [Privacy](https://sommomemory.sommomi.cc/en/privacy) · [Support](https://sommomemory.sommomi.cc/en/support) · [Delete account](https://sommomemory.sommomi.cc/en/delete-account)

## Sala giochi pop — italiano e inglese, build 30017

La revisione **3.1.0 (30017)** aggiunge l'interfaccia inglese alla grafica A: cobalto, giallo e corallo, tessere con bordi e ombre nette, carte spesse e coppie trovate evidenziate in giallo. La lingua segue il dispositivo: italiano sui dispositivi italiani, inglese per le altre lingue. **Impostazioni → Lingua** permette di scegliere Automatico, Italiano o Inglese e conserva la preferenza. Le sillabe del mazzo Paola restano italiane.

Analisi statica e **182 test Flutter / 101 test Node** sono passati, con verifiche di lingua automatica, cambio lingua persistente, parametri dinamici e interfaccia inglese su schermi compatti. Anche il cambio lingua sul sito pubblicato è stato verificato, ripristinando poi la preferenza Automatico. **Google Play release 15, build 30017**, è attiva nel canale interno esistente; **TestFlight 30017 è VALID / IN_BETA_TESTING** per i due tester già presenti. Anche il sito è aggiornato a **20261106-pop-30017**, con pagine di privacy, assistenza e cancellazione account in inglese. Ricevute in [native-builds-30017.json](artifacts/native-builds-30017.json) e [deployment-30017.json](artifacts/deployment-30017.json).

Le schede mantengono l'italiano primario e aggiungono **en-US / en-GB**, con disponibilità pubblica impostata su **27 Stati UE + Stati Uniti**. Le gallerie in italiano e inglese sono caricate e rilette su entrambi gli store: tutti i 24 asset Apple sono **COMPLETE**. Google Play ha superato i controlli automatici e mostra le 13 modifiche preparate come pronte da inviare in revisione. La submission pubblica è lasciata all'utente. Stato dei contenuti e dei prerequisiti in [STORE_METADATA_3_1_IT.md](docs/STORE_METADATA_3_1_IT.md).

## Il gioco

- Giocatore singolo anche al primo avvio senza Internet: gemme, collezioni sbloccate e record salvati sul dispositivo, poi sincronizzati automaticamente al ritorno della rete. Nessun limite di tabelloni preparati per l'individuale.
- Due giocatori sullo stesso dispositivo, a turni.
- Online con stanza privata e codice: **Amichevole** da un round oppure **Classificata** da tre round. La classificata richiede due profili distinti nella stessa arena; Android, iOS e browser condividono lo stesso servizio. Il matchmaking automatico resta previsto per una versione futura.
- Bluetooth Low Energy offline nelle app Android/iOS: si sceglie subito tra **Cerca partita** e **Crea partita**. Chi cerca entra direttamente nella ricerca; solo chi crea sceglie mazzo e numero di coppie. Entrambe le app devono restare aperte; alcuni Android non supportano il ruolo host. Interoperabilità radio ancora da collaudare su due telefoni fisici.
- **Quattro arene e 21 deck illustrati**, ciascuno con 18 soggetti locali, più **Paola** con 18 sillabe italiane. **Valle Selvaggia (0 corone), Baia Corallina (100), Grande Città (300), Frontiera Spaziale (600)** hanno tre deck gratuiti ciascuna e altri acquistabili con gemme. Le amichevoli consentono 6, 8, 12 o 18 coppie; la classificata usa 12 coppie per round e tre deck diversi estratti dai gratuiti e dagli acquisti di entrambi i giocatori. Catalogo, prezzi e regole in `docs/ARENAS_SPEC.md`; fonti e licenze in `docs/DECKS.md`.
- Le arene formano un viaggio illustrato con sentiero, tappe numerate, paesaggi e progresso verso la destinazione successiva. La mappa è accessibile anche dalla preparazione dell'individuale; riferimenti in `docs/ARENA_JOURNEY_REFERENCES.md`. Le soglie e le regole delle corone rimangono invariate.
- Le corone salgono di **20 per vittoria classificata**, scendono di **20 per sconfitta** fino al minimo zero e restano invariate nei pareggi. In classificata i due giocatori completano tabelloni individuali identici, senza turni: vince chi impiega meno tentativi totali nei tre round. Ogni nuova classificata usa l'arena delle corone attuali; le arene raggiunte restano disponibili nelle amichevoli. Tra i round entrambi confermano il proseguimento. Le gemme sono assegnate una sola volta dopo la partita completa.
- La nuova lobby richiede “Pronto” da entrambi. L'ospite può uscire liberando il posto senza cambiare il codice; l'host può chiuderla. Prima dell'inizio non vengono assegnati esiti o premi. Nella stessa lobby è disponibile una chat vocale facoltativa per tutti i partecipanti: chi la attiva si sente con gli altri che l’hanno attivata. L’audio non viene registrato.
- Flip 3D delle carte (320 ms), retro dedicato a ogni collezione, impostazione di sistema Riduci movimento rispettata. Collezione e difficoltà vengono ricordate alla riapertura.
- Suoni originali e vibrazioni per apertura delle carte, coppie, errori e cambio turno, disattivabili separatamente nelle impostazioni. Gli esiti seguono la fine reale dei flip; nessun feedback viene riprodotto entrando in una partita già in corso o dagli aggiornamenti ripetuti. I suoni rispettano il silenzioso di iOS e si fermano quando l’app passa in background.
- Le stanze piene mostrano un’anteprima dei due giocatori, dei punteggi e del risultato finale, aggiornabile senza occupare un posto. Gli avvisi hanno una superficie opaca leggibile sopra tutti gli sfondi; gli errori definitivi non mostrano una connessione ancora in corso.
- Profilo ospite con **100 gemme iniziali**, **20 gemme per partita completata e validata** e sblocchi permanenti. Salvataggio e sincronizzazione facoltativi tramite codice personale di recupero: niente email/password proprie, pubblicità o denaro reale. Il codice consente di collegare app e browser allo stesso profilo; non compare mai nei link d’invito. L’accesso Google facoltativo usa un SDK di autenticazione che dichiara proprie raccolte di dati e finalità di analisi; dettagli nell’[informativa privacy](server/public/privacy.html).
- Sfondo cobalto a tutto schermo con pattern geometrici discreti e retro dedicato per ogni collezione, incluso un quaderno con sillabe per Paola. Il movimento si arresta quando l’app è sospesa o con Riduci movimento.
- Interfaccia senza slogan, con modalità e configurazione separate; tabelloni completi senza scorrimento anche su iPhone SE e in orizzontale. Ogni riga contiene sempre lo stesso numero di carte, usando solo numeri di colonne che dividono esattamente il totale.

Nelle amichevoli una coppia corretta mantiene il turno; un errore mostra le carte per 900 ms, poi passa il turno. In classificata ogni giocatore completa il proprio tabellone e ogni seconda carta scoperta conta un tentativo. Punteggio, coppie trovate e risultato compaiono solo dopo l’apertura completa delle carte; il cambio turno aspetta la completa richiusura. Durante qualunque flip il tabellone resta bloccato, in locale, online e Bluetooth. Gli aggiornamenti remoti attendono in ordine la fine reale delle animazioni; il movimento ridotto non aggiunge attese artificiali. Il server decide mazzo, turni e punteggio e non invia le carte coperte. La riconnessione online conserva il posto per 90 secondi; dopo il termine si perde per abbandono. Le stanze inattive scadono dopo 24 ore.

## Gemme, profilo e inviti

Il profilo è personalizzabile con nickname, avatar e colore anche da ospite. Apple e Google sono attivi per l'accesso opzionale e la sincronizzazione di gemme, collezioni e personalizzazioni del profilo, con gestione dei dispositivi e cancellazione dall'app o dal browser. Istruzioni e opzioni per le build in [docs/ACCOUNTS_SETUP.md](docs/ACCOUNTS_SETUP.md). I record dell'individuale vengono uniti conservando il miglior numero di tentativi per difficoltà; i vecchi record solo locali e le preferenze rimangono sul dispositivo.

Le gemme e le collezioni possedute sono conservate in transazioni SQLite sul server, con richieste idempotenti e un registro degli accrediti. Le credenziali del profilo restano nel Keychain/Keystore dell’app; sul web il salvataggio appartiene a quel browser e dominio. Il codice personale permette di ritrovare lo stesso profilo su un altro dispositivo, dopo anteprima e conferma, senza sommare i saldi dei due ospiti. È possibile mostrare, ruotare il codice, scollegare un dispositivo o eliminare il profilo.

In amichevole basta che chi crea la stanza possieda il deck; in classificata il sorteggio può includere i deck acquistati da uno dei due, senza trasferirne la proprietà. Le partite online completate premiano ciascun profilo distinto una sola volta, senza gemme per abbandono. Un abbandono classificato assegna la vittoria e modifica le corone; due disconnessioni scadute annullano la sfida. Per partite locali e Bluetooth l’app prepara online due tabelloni per la configurazione scelta e conserva le prove delle partite finite da sincronizzare. Senza un tabellone preparato si può sempre giocare in modalità pratica, senza gemme. I deck già posseduti restano disponibili offline. I vecchi profili conservano Oceano, Spazio e tutti gli acquisti nelle attività non classificate, anche se non hanno ancora raggiunto le nuove arene; non vengono regalate corone o altre collezioni. Questa verifica blocca premi doppi e prove incoerenti, ma non certifica il gioco umano; le ricariche a pagamento non sono implementate. Contratto completo in `docs/ECONOMY_PROTOCOL.md`.

Gli inviti condivisi usano `https://sommomemory.sommomi.cc/invite/CODICE`. iOS Universal Links e Android App Links richiedono la build 30009 o successiva e le associazioni pubbliche del dominio. Rimangono compatibili i precedenti `/?room=CODICE` sul nuovo dominio. Su richiesta dell’utente viene mantenuto solo `sommomemory.sommomi.cc`; il vecchio hostname non è più pubblicato. Se il browser mantiene aperto il sito, l’invito offre **Apri nell’app** come azione esplicita; il codice della stanza resta disponibile anche per entrare dal browser. I link non trasportano credenziali del profilo. Un invito ricevuto durante una partita chiede conferma prima di abbandonarla, senza ricreare il profilo. Limiti Safari e verifica fisica in `docs/DEEP_LINKS.md`.

## Struttura e recupero

| Percorso | Contenuto |
|---|---|
| `app/` | Applicazione unica Flutter, Android + iOS + web |
| `server/` | Servizio Node, WebSocket e pagine privacy/assistenza |
| `deploy/` | Container, release, volume persistente e route Caddy su Sommonas |
| `scripts/` | Icone riproducibili e operazioni App Store Connect con chiave esterna |
| `docs/ADMIN.md` | Area admin con passkey, statistiche operative, storico online e attivazione |
| `docs/RELEASE.md` | Firma, pubblicazione, TestFlight e verifiche residue |
| `docs/ARENAS_SPEC.md` | Specifica di arene, corone, lobby e classificate da tre round |
| `docs/ARENAS_TASKS.md` | Task delegati, verifiche e fasi di implementazione delle arene |
| `legacy/AUDIT.md` | Confronto dei progetti storici e provenienza delle regole |
| `old/`, `new/` | Sorgenti Flutter storici conservati dalla repository originale; non compilati |

La storia Git della repository Flutter è conservata. Il vecchio backend Node/Socket.IO/MySQL è stato esaminato ma sostituito: manteneva credenziali e fiducia nel client non adatte al nuovo servizio. Il Java originale e le copie di consultazione dei repository rimangono nell'area di lavoro, fuori dai nuovi pacchetti.

## Sviluppo

Toolchain verificata: **Flutter 3.47.9 / Dart 3.13.7**, JDK 17, Android SDK 36, Xcode 27.2. Server verificato con Node 22.23 e container Node 24.22.1. Le versioni delle dipendenze sono bloccate nei lockfile.

Installare anche le dipendenze del server con `cd server && npm ci`: la suite Flutter include una prova di sincronizzazione con un server Node temporaneo e dati isolati.

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

Il client usa per impostazione predefinita `wss://sommomemory.sommomi.cc/ws`. Per un servizio locale:

```sh
cd server
npm ci
npm test
PORT=8787 npm start
# Da un altro terminale, nella cartella app:
flutter run --dart-define=MULTIPLAYER_URL=ws://127.0.0.1:8787/ws --dart-define=PROFILE_API_URL=http://127.0.0.1:8787/api/v1
```

Dai telefoni, usare un servizio HTTPS/WSS raggiungibile: l’API del profilo consente HTTP soltanto su localhost per lo sviluppo. Le build distribuite mantengono HTTPS/WSS. Non abilitare eccezioni al traffico in chiaro nelle build di pubblicazione.

## Build

```sh
cd app
flutter build web --release
flutter build appbundle --release
flutter build apk --release
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist \
  --dart-define=ACCOUNT_APPLE_IOS_ENABLED=true \
  --dart-define=ACCOUNT_GOOGLE_IOS_ENABLED=true
```

Android usa la **nuova app `cc.sommomi.mymemory`**, nome **SommoMemory**, versione **3.1.0 (30017)**. Il nome nel launcher è **SommoMemory**; la scheda Store ha il nuovo nome salvato in bozza e Google mostra un nome temporaneo fino alla prima revisione. La release 15, **3.1.0 Sala giochi pop · English**, è attiva nei [test interni Google Play](https://play.google.com/apps/internaltest/4700857721365894827), con la lista dei tester esistente, osservata con tre utenti e mantenuta invariata. Occorre accettare l'invito nella pagina del test. La vecchia `com.michele.mymemory` è stata eliminata il **5 novembre 2026**, su conferma esplicita dell'utente; Google consente di recuperarla fino al **12 novembre 2026**. Dopo la cancellazione è stato verificato che il nuovo test interno resta attivo. Vedere `docs/ANDROID.md` per i dettagli.

La nuova chiave upload dedicata è conservata esternamente in `~/.codex/credentials/android/mymemory/`, con configurazione privata e `app/android/key.properties` locale ignorato da Git. Le release non usano la chiave debug; Google Play gestisce la firma delle installazioni distribuite dal canale interno.

iOS usa **`cc.sommomi.mymemory`**, versione **3.1.0 (30017)**, verificata **VALID / IN_BETA_TESTING** nel gruppo **SommoMemory Internal** su TestFlight per i due tester esistenti autorizzati. Il tester proprietario è già aggiunto e il suo invito risulta accettato. Il profilo e la chiave rimangono esterni alla repository. In caso di interruzione dopo l’invio completo dei byte, `node scripts/testflight-upload.mjs --commit-only artifacts/SommoMemory-3.1.0-30017.ipa` riprende soltanto la conferma della ricevuta esistente, verificando versione e impronte senza creare un altro upload. Gli script ASC leggono la configurazione in `~/.codex/credentials/appstoreconnect/config.json`, firmano JWT brevi in memoria e non espongono credenziali. Dopo l'upload, `node scripts/testflight-finalize.mjs --finalize --build=30017 --wait=1200 --notes-file=artifacts/beta-notes-30017-it.txt` verifica Apple e collega solo il gruppo interno esistente. Per il gruppo con due tester occorre anche `--additional-tester=ID_TESTER_ESISTENTE_AUTORIZZATO`: lo script verifica l’insieme esatto e non crea tester o inviti.

## Area amministrativa

L’[admin riservato](https://sommomemory.sommomi.cc/admin) usa esclusivamente passkey per l’accesso e mostra attività dei profili, partite online, storico e lobby, con aggiornamento ogni 15 secondi. La prima passkey si registra con un codice monouso generato sul server; codici e credenziali restano fuori dalla repository. Le statistiche partono dall’attivazione, senza ricostruire le partite offline o quelle precedenti. Dettagli in [docs/ADMIN.md](docs/ADMIN.md).

## Hosting e collaudo

Dopo la build web, `node scripts/prepare-web.mjs` assegna al codice JavaScript un nome basato sul suo contenuto, evitando che una copia precedente nella cache nasconda gli aggiornamenti. `bash deploy/deploy.sh` esegue questo passaggio automaticamente e pubblica una release separata su Sommonas; vedere `deploy/README.md`. Dati in volume Docker persistente; una sola istanza del servizio. Caddy gestisce HTTPS e WebSocket. Per scalare a più istanze occorrono storage transazionale e sincronizzazione condivisi.

Lo stesso passaggio prepara la copia offline del sito: dopo il primo caricamento completo online, gioco, motore grafico e collezioni possono riaprirsi senza rete. Le risposte delle API e dell'account non vengono memorizzate dal service worker. La sincronizzazione dei progressi viene ritentata ogni 10 secondi e al ritorno in primo piano; sul web anche all'evento di riconnessione. Server e sito sono aggiornati alla release **20261106-pop-30017**; tutti i 56 profili preesistenti al backup sono conservati, con 56 profili totali alla verifica e integrità SQLite confermata. La selezione del runtime nel bootstrap, i file pubblici e le quattro risorse di privacy/assistenza/cancellazione in inglese corrispondono ai file locali. Ricevuta in [artifacts/deployment-30017.json](artifacts/deployment-30017.json).

Verificati **182 test Flutter** (motore locale, quattro viewport con safe area iOS, tastiera aperta, tutte le 36 carte visibili e selezionabili, dialoghi, flip avanti/indietro, eventi solo a fine animazione, movimento ridotto e pausa dell’app, blocco durante i flip, aggiornamenti remoti anticipati, rotazione e nuova partita senza callback obsolete, righe complete a ogni difficoltà, decodifica di tutte le immagini e licenze, Bluetooth e riconnessione, mappa delle arene, salvataggio e sincronizzazione offline anche con il server reale) e **101 test Node** con credenziali, ripristino del profilo, sblocchi atomici, premi e prove di partita, migrazione del database, due client e ripristino da disco, code offline e aggiornamento di una versione web già memorizzata dal browser. Per la revisione finale sono state verificate analisi statica, tutte le suite Flutter/Node, build firmate Android/iOS 30017 accettate nei canali interni e corrispondenza dei file pubblici, salute del servizio e protocollo WSS del sito. I 24 screenshot italiani e inglesi dello store sono catture dell’interfaccia Flutter con profilo ospite isolato, non catture di telefoni fisici o simulatori; font e fallback emoji sono caricati nel renderer e la conversione RGB conserva i pixel senza ritoccare l’interfaccia. Il Bluetooth ha ancora bisogno del collaudo fisico Android↔iPhone, Android↔Android e iPhone↔iPhone, con permessi negati, radio spenta, background e perdita di connessione. I simulatori non possono verificare questa parte radio.
