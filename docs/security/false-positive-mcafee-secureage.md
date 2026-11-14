# Falso positivo McAfee e SecureAge

Questo documento serve a richiedere la riclassificazione di MoliOptimizer a McAfee e SecureAge. Non è una procedura per aggirare l'antivirus: i due motori devono analizzare il file e aggiornare le proprie firme o whitelist.

## Dati dell'applicazione

- Prodotto: MoliOptimizer v3 (web) e MoliOptimizerFast v3 (PowerShell)
- Autore: Molinays
- Versione: 3.0.0
- Repository: https://github.com/Molinays/MoliOptimizer
- Release: https://github.com/Molinays/MoliOptimizer/releases
- Tipo: ottimizzatore Windows con GUI web e GUI classica
- Motore: PowerShell 5.1, con guscio C# WebView2 nell'edizione web
- Firma: la release va firmata con un certificato code signing trusted prima dell'invio

## File e hash

Questi sono gli artefatti attuali, ancora non firmati. Dopo la firma gli hash cambiano: per l'invio ai vendor usare gli hash della build firmata.

| File | SHA-256 | Dimensione |
|---|---|---|
| `MoliOptimizer.exe` | `92B0BAA80339164475F6B400DDCE1560B13E68DE1A4BE2A473A7345C699B35D7` | 721.408 byte |
| `MoliOptimizer-Web.exe` | `621BF7C7C13BA6F04DE4D73CE55212DD1F7DD5FCA36F241B2C0B5D8D5BB01D05` | 71.168 byte |
| `MoliOptimizerFast-IT.exe` | `2E5656CFB587E0FCA469B020CD1E77066C320D90CC33B09BBB1861A1EAAC8157` | 338.432 byte |
| `MoliOptimizerFast-EN.exe` | `57D490E1AB3AE00AD6DAE47FFCB55B9CA65FD309A1D31795165E7D69990BEC69` | 374.784 byte |

## Comportamento dichiarato

MoliOptimizer:

- analizza hardware, dischi, app, servizi e voci di avvio;
- applica solo le ottimizzazioni scelte e confermate dall'utente;
- salva un backup in `%ProgramData%\MoliOptimizer` e permette il ripristino;
- usa PowerShell per le operazioni di sistema e richiede l'elevazione per registro, servizi, Appx e alimentazione;
- nell'edizione web avvia un server HTTP locale limitato a `127.0.0.1` per servire la GUI a WebView2;
- non installa servizi persistenti, non crea driver e non stabilisce connessioni di comando e controllo;
- contatta GitHub solo per il controllo aggiornamenti e usa i collegamenti ufficiali per winget e ISO.

Il deep clean RAM e le ottimizzazioni sono funzioni richieste dall'utente e documentate nel README.

## McAfee

Modulo ufficiale per contestare una rilevazione:

https://www.mcafee.com/en-us/consumer-support/dispute-detection-allowlisting.html

Procedura:

1. Aprire **Dispute a Detection & Allowlisting Data**.
2. Inserire nome, email, azienda e descrizione.
3. Allegare il file firmato, oppure uno ZIP con il file.
4. Indicare il nome esatto della rilevazione mostrato da VirusTotal/McAfee.
5. Inserire il link al report VirusTotal e l'hash SHA-256.
6. Spiegare che MoliOptimizer è un ottimizzatore Windows firmato da Molinays e che il comportamento è descritto sopra.
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
5. Indicare che il file è firmato da Molinays dopo la firma della release.
6. Inviare e conservare la conferma.

SecureAge analizza il file e può comunicare la riclassificazione ai motori che lo rilevano.

## Microsoft Defender

Se Defender continua a segnalare `Trojan:Win32/Wacatac.B!ml`, usare anche:

https://www.microsoft.com/en-us/wdsi/filesubmission

Selezionare la segnalazione come falso positivo, allegare il file firmato e indicare hash, versione, detection e comportamento.

## Testo pronto per la segnalazione

> Oggetto: False positive report - MoliOptimizer v3 - Molinays
>
> We are reporting a false positive for MoliOptimizer v3, a signed Windows optimization application published by Molinays.
>
> File: [nome file]
> SHA-256: [hash della build firmata]
> Version: 3.0.0
> Detection: [nome esatto McAfee/SecureAge]
> VirusTotal: [link al report]
>
> MoliOptimizer scans hardware, installed applications, services and startup entries. It applies only user-selected optimizations, creates a backup before changes, and provides a restore function. The application uses PowerShell 5.1 for system operations and requests administrator rights only for registry, services, Appx and power changes. It does not install a service or driver and does not use command-and-control infrastructure. The web edition hosts its local UI on 127.0.0.1 through WebView2.
>
> The attached build is signed by Molinays with a trusted code signing certificate. Please review the detection and allowlist the file if it is confirmed clean.
>
> Repository: https://github.com/Molinays/MoliOptimizer

## Dopo l'invio

- Non disattivare McAfee, SecureAge o Defender e non aggiungere esclusioni.
- Non usare offuscamento, packer o modifiche pensate solo per eludere il motore.
- Ricaricare il file su VirusTotal dopo la risposta del vendor e verificare che le due rilevazioni siano sparite.
- Se SecureAge continua a rilevare la classica, il wrapper `ps2exe` è il candidato principale: valutare un host .NET firmato.
- Se continua a rilevare la web, valutare la rimozione del server HTTP locale in favore del mapping virtuale WebView2; è una modifica architetturale, non una modifica di evasione.
