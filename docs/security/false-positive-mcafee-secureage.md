# Falso positivo McAfee e SecureAge

Questo documento serve a richiedere la riclassificazione di MoliOptimizer a McAfee e SecureAge. Non è una procedura per aggirare l'antivirus: i due motori devono analizzare il file e aggiornare le proprie firme o whitelist.

## Dati dell'applicazione

- Prodotto: MoliOptimizer v3.5 (web) e MoliOptimizerFast v3.5 (PowerShell)
- Autore: Molinays
- Versione: 3.5.0
- Repository: https://github.com/Molinays/MoliOptimizer
- Release: https://github.com/Molinays/MoliOptimizer/releases
- Tipo: ottimizzatore Windows con GUI web e GUI classica
- Motore: PowerShell 5.1, con guscio C# WebView2 nell'edizione web
- Firma: la release va firmata con un certificato code signing trusted prima dell'invio

## File e hash

Questi sono gli artefatti attuali, ancora non firmati. Dopo la firma gli hash cambiano: per l'invio ai vendor usare gli hash della build firmata.

| File | SHA-256 | Dimensione |
|---|---|---|
| `MoliOptimizer.exe` | `54C336703AFE0BD44BBFEE97E8FF62DCA8571D5442D81D063BA2C614794B5FFE` | 1.469.440 byte |
| `MoliOptimizer-Web.exe` | `2FEE32A04ADF120C111372787FB2DF8AA85AD2DA75D1A6362E842076EB9932A9` | 427.008 byte |
| `MoliOptimizerFast-IT.exe` | `E5996024345C481681048B14034AC72DD08BDD5CEA42ABA90D096BCE9AD4A392` | 364.544 byte |
| `MoliOptimizerFast-EN.exe` | `C918536CFEEBA9EB6C72EA490003820035830189130BE74E595DF178E886ED97` | 408.064 byte |

## Comportamento dichiarato

MoliOptimizer:

- analizza hardware, dischi, app, servizi e voci di avvio;
- applica solo le ottimizzazioni scelte e confermate dall'utente;
- salva un backup in `%ProgramData%\MoliOptimizer` e permette il ripristino;
- usa PowerShell per le operazioni di sistema e richiede l'elevazione per registro, servizi, Appx e alimentazione;
- nell'edizione web serve la GUI a WebView2 tramite risorse intercettate, senza aprire un server HTTP locale;
- nella build pubblica 3.5 il payload web è compresso ma non cifrato, mentre il bundle Fast è incorporato in chiaro; non usa `ps2exe` e non è un packer di evasione;
- non installa servizi persistenti, non crea driver e non stabilisce connessioni di comando e controllo;
- contatta GitHub solo per il controllo aggiornamenti e usa i collegamenti ufficiali per winget e ISO.

Il deep clean RAM e le ottimizzazioni sono funzioni richieste dall'utente e documentate nel README.

## McAfee

Modulo ufficiale per contestare una rilevazione:

https://www.mcafee.com/en-us/consumer-support/dispute-detection-allowlisting.html

Procedura:

1. Aprire **Dispute a Detection & Allowlisting Data**.
2. Inserire nome, email, azienda e descrizione.
3. Allegare il file della release (firmato, quando disponibile), oppure uno ZIP con il file.
4. Indicare il nome esatto della rilevazione mostrato da VirusTotal/McAfee.
5. Inserire il link al report VirusTotal e l'hash SHA-256.
6. Spiegare che MoliOptimizer è un ottimizzatore Windows pubblicato da Molinays e che il comportamento è descritto sopra; la firma trusted è il passo di release successivo.
7. Inviare e conservare il riferimento della richiesta.

McAfee indica tempi tipici di due giorni lavorativi, ma la risposta può richiedere più tempo. Il modulo richiede di essere autorizzati a inviare il software.

Se il modulo non è disponibile, il canale storico McAfee Labs è `virus_research@avertlabs.com`; per un falso positivo è preferibile il modulo. Per l'invio via email lo ZIP deve avere password `infected`.

## SecureAge

Modulo ufficiale:

https://www.secureage.com/support/report-false-positive

Procedura:

1. Comprimere il file in **ZIP**, non 7zip o RAR.
2. Proteggere lo ZIP con password `infected`.
3. Caricare il file dal modulo.
4. Inserire versione, hash SHA-256, nome della rilevazione e descrizione dell'app.
5. Indicare che la release sarà firmata da Molinays quando il certificato trusted sarà disponibile.
6. Inviare e conservare la conferma.

SecureAge analizza il file e può comunicare la riclassificazione ai motori che lo rilevano.

## Microsoft Defender

Se Defender continua a segnalare `Trojan:Win32/Wacatac.B!ml`, usare anche:

https://www.microsoft.com/en-us/wdsi/filesubmission

Selezionare la segnalazione come falso positivo, allegare il file della release e indicare hash, versione, detection e comportamento.

## Testo pronto per la segnalazione

> Oggetto: False positive report - MoliOptimizer v3.5 - Molinays
>
> We are reporting a false positive for MoliOptimizer v3.5, a Windows optimization application published by Molinays.
>
> File: [nome file]
> SHA-256: [hash della build firmata]
> Version: 3.5.0
> Detection: [nome esatto McAfee/SecureAge]
> VirusTotal: [link al report]
>
> MoliOptimizer scans hardware, installed applications, services and startup entries. It applies only user-selected optimizations, creates a backup before changes, and provides a restore function. The application uses PowerShell 5.1 for system operations and requests administrator rights only for registry, services, Appx and power changes. It does not install a service or driver and does not use command-and-control infrastructure. The web edition serves its UI to WebView2 from memory and does not open an HTTP listener.
>
> The attached build is the public MoliOptimizer 3.5 artifact. Please review the detection and allowlist the file if it is confirmed clean. A trusted code-signing certificate is the remaining release step; if a signed artifact is required for the review, request it from Molinays.
>
> Repository: https://github.com/Molinays/MoliOptimizer

## Dopo l'invio

- Non disattivare McAfee, SecureAge o Defender e non aggiungere esclusioni.
- La build pubblica 3.5 non cifra il payload: UI, bridge e script sono recuperabili da chi analizza il file. L'opzione interna `Build-WebHost.ps1 -Protect` protegge il codice proprietario ma non è pensata per eludere il motore e non va pubblicata. Se il vendor chiede una build non offuscata per l'analisi, fornire la build pubblica insieme all'artefatto firmato.
- Ricaricare il file su VirusTotal dopo la risposta del vendor e verificare che le due rilevazioni siano sparite.
- la build 3.5 ha già rimosso `ps2exe` (Fast), il server HTTP locale (Web) e il launcher .NET esterno (WebSingle); se un motore continua a rilevare, il passo successivo è la firma trusted e la riclassificazione vendor, non un ulteriore imballaggio.
- i due report indicati dall'utente sono: `https://www.virustotal.com/gui/file/1f8b21bfc1ce339d59b23b23f9547cecc954eb6088774e30daf6201a763a9ad6` e `https://www.virustotal.com/gui/file/b469816cfe400b59f65a961e306e9eea54df78e866b1d72d0c8ac79d407f75d7`. I file 3.5 hanno hash nuovi: vanno ricaricati su VirusTotal per una nuova analisi.
