# Trace

Remote debugger voor PowerShell-scripts op een vloot servers. Trace vindt draaiende
`pwsh`-scripts via SSH, volgt ze op en legt bij een crash de volledige toestand vast:
regel, variabelen, callstack en `$Error`. Op de servers wordt niets geïnstalleerd.

> **Status:** in ontwikkeling. Alleen de proof of concept in `poc/attach` werkt:
> attachen aan een al draaiend script op een andere machine, met tracepoints.

## Vereisten

- **Beheermachine:** PowerShell 7.2 of hoger, de module `powershell-yaml`.
- **Servers:** PowerShell 7.2 of hoger, en in `sshd_config`:
  ```
  Subsystem powershell /usr/bin/pwsh -sshs -NoLogo
  ```
- Om te attachen: dezelfde SSH-gebruiker als het script, of root.

## Snel aan de slag

1. Kopieer `fleet.example.yml` naar `fleet.yml` en vul je servers in.
   Een bestaande Ansible-inventaris in YAML werkt ook.
2. Zet `trace_debug: true` alleen op servers waar debuggen mag.

Gepland gebruik:

```powershell
Import-Module ./Trace
Import-TraceServer ./fleet.yml | Test-TraceServer      # is elke server klaar?
Import-TraceServer ./fleet.yml | Find-TraceScript      # welke scripts draaien er?
Get-Help about_Trace                                   # de niveaus van licht tot diep
```

## Cmdlets (gepland)

| Cmdlet | Wat het doet | Niveau |
|---|---|---|
| `Import-TraceServer` | Serverlijst inlezen en valideren | |
| `Test-TraceServer` | Controleren of elke server klaar is (pwsh, subsystem, rechten) | |
| `Find-TraceScript` | Draaiende `pwsh`-scripts vinden | |
| `Get-TraceLog` | Logs ophalen die het script zelf schrijft | 0 |
| `Start-TraceScript` | Script starten via de wrapper | 1 |
| `Set-TraceTracepoint` / `Remove-TraceTracepoint` | Tracepoints zetten en weghalen | 2 |
| `Connect-TraceScript` / `Disconnect-TraceScript` | Aanhaken aan een draaiend script en loskoppelen | 3 |
| `Get-TraceCrashReport` | Crashrapporten opvragen en tonen | |

## Mappen

```
fleet.example.yml        voorbeeldserverlijst
docs/architectuur.md     hoe het werkt, met de bevindingen uit de PoC
docs/about_Trace.help.txt  helptopic (komt in de module onder en-US/)
poc/attach/              proof of concept: VM opstarten en een draaiend script debuggen
```

## Proof of concept

```sh
cd poc/attach
./up.sh              # Debian-VM met pwsh en een draaiend hello.ps1
pwsh ./debug.ps1     # attachen, tracepoints, resultaat op de beheermachine
./down.sh            # VM stoppen
```

Zie `poc/attach/README.md` voor de uitvoer en de beperkingen.
