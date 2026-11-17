# Architectuur

## Overzicht

```
beheermachine                         server (niets extra geïnstalleerd)
─────────────                         ──────────────────────────────────
Trace-module                          sshd
  │  serverlijst (YAML)                 │  Subsystem powershell → pwsh -sshs
  │                                     ▼
  └─ SSH-remoting ──────────────────► pwsh-sessie van Trace
     (één sessie per server)            │  Get-PSHostProcessInfo / Get-Process
                                        │  NamedPipeConnectionInfo(pid)
                                        ▼
                                      pwsh-proces van het script
                                        └─ runspace 1 → Debugger
```

Alle logica zit in de module op de beheermachine. Op een server zijn alleen
`pwsh` (7.4 of hoger) en het `powershell`-subsystem van sshd nodig.

## Debugging van licht tot diep

| Niveau | Hoe | Grijpt in? |
|---|---|---|
| 0: logs | De parser zoekt in het script waar het naartoe logt (`Start-Transcript`, `Out-File`, `Add-Content`); die bestanden worden via SSH opgehaald | Nee |
| 1: wrapper | Het script start via een wrapper met `$ErrorActionPreference = 'Break'` | Alleen bij een fout |
| 2: tracepoints | Breakpoint met een actie zonder `break`: legt een waarde vast, het script loopt door | Licht |
| 3: attach | Aanhaken aan een al draaiend `pwsh`-proces en daar niveau 1 en 2 toepassen | Ja |

Niveau 1 tot 3 mogen alleen op servers met `trace_debug: true`.

## Attachen aan een draaiend script (niveau 3)

Aangetoond in `poc/attach`. De keten:

1. **SSH-remoting** naar de server: `New-PSSession -HostName … -KeyFilePath …`.
2. **Het script vinden**: `pwsh`-processen waarvan de opdrachtregel naar het script wijst.
3. **Attachen**: `[NamedPipeConnectionInfo]::new($pid)` en `[runspacefactory]::CreateRunspace(...)`.
   Die runspace draait *in* het doelproces. Het is dezelfde weg die `Enter-PSHostProcess` gebruikt,
   maar dan zonder interactieve prompt. Op Linux is de pipe een Unix-socket in `/tmp`.
4. **De runspace van het script**: `Get-Runspace -Id 1`.
5. **Breakpoints met acties** rechtstreeks op `$runspace.Debugger`.

### Bevindingen uit de PoC

- `Set-PSBreakpoint -Runspace` weigert in een geattachte runspace:
  `Breakpoints cannot be set in the remote session because remote debugging is not supported by the current host.`
  De debugger-API rechtstreeks werkt wel: `SetVariableBreakpoint`, `SetLineBreakpoint`, `RemoveBreakpoint`.
- Acties moeten losse scriptblocks zijn (`[scriptblock]::Create(...)`), anders draaien ze in de
  verkeerde runspace. Hun resultaten gaan via een gedeelde wachtrij in het doelproces terug.
- Een actie zonder `break` stopt het script niet. Na het loskoppelen loopt het script gewoon door.
- Attachen vraagt dezelfde gebruiker als het script, of root: de socket is van die gebruiker.
- Bij het loskoppelen logt het doelproces een onschuldige `TransportError`.

### Nog niet aangetoond

- Echt stoppen, rondkijken en hervatten (`DebuggerStop`-event, `Debug-Runspace`).
- Een crashrapport bij een fout in een al draaiend script.

## Uitvoer

| Wat | Formaat | Waar |
|---|---|---|
| Crashrapport | JSON, één bestand per crash | Beheermachine, één map per server |
| Tracepoint-records | JSON Lines, één record per regel | Beheermachine, één bestand per sessie |

Het wegschrijven zit in één functie, zodat een ander formaat (bijvoorbeeld binair) één functie vervangt.
