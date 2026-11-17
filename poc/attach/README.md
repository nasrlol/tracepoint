# tracepoint — PoC: remote debuggen van een draaiend pwsh-script over SSH

**Bewijst:** vanaf een beheermachine kun je via SSH-remoting in een *ander, al draaiend* pwsh-proces
breakpoints zetten, zonder interactie, en de waarden terugkrijgen. Keten: host → `New-PSSession -HostName`
(SSH, subsystem `powershell`) → `NamedPipeConnectionInfo(pid)` → runspace in het doelproces → `Debugger`-API op runspace 1.

## Draaien
    ./up.sh                 # Debian 13 arm64 VM (QEMU), pwsh 7.6.5, sshd-subsystem, start hello.ps1 als service
    pwsh ./debug.ps1        # 7 s tracepoint + snapshot, resultaat op de host
    ./down.sh               # VM stoppen

Uitvoer (echt):

    attached to pid 879 (/opt/pwsh/pwsh -NoLogo -NoProfile -File /opt/hello.ps1)
    tracepoint: i=21
    snapshot: n=21 i=21 stack=hello.ps1: line 1 <- hello.ps1: line 3
    tracepoint: i=22
    ...

## Wat werkte / wat niet
- Werkt: attachen via named pipe binnen de SSH-sessie; variabele-tracepoint (`$i` write) en line-breakpoint met
  action die `$n`, `$i` en `Get-PSCallStack` vastlegt. Het script loopt gewoon door (actions zonder `break`).
- Werkt NIET: `Set-PSBreakpoint -Runspace` in de geattachte runspace →
  `Breakpoints cannot be set in the remote session because remote debugging is not supported by the current host.`
  Oplossing: rechtstreeks `$runspace.Debugger.SetVariableBreakpoint()/SetLineBreakpoint()/RemoveBreakpoint()`.
- Action-scriptblocks moeten *unbound* zijn (`[scriptblock]::Create(...)`) zodat ze in de doelrunspace draaien;
  resultaten gaan via een process-globale queue (`AppDomain.SetData`) terug naar de attach-runspace.
- Niet getest: echt stoppen + hervatten (DebuggerStop-event/`Debug-Runspace`) — dat vereist een host met debug-support.

## Beperkingen
- Zelfde gebruiker (of root) als het doelproces nodig: de pipe is een Unix-socket in `/tmp` van die user.
- PowerShell ≥ 7.2 aan beide kanten (SSH-remoting, `-Options`); getest met 7.6.5 host en guest.
- Bij detach logt het doelproces een onschuldige `TransportError ... unknown element`; het script draait door.
- `/dev/kvm` was niet toegankelijk (user niet in groep `kvm`) → TCG-emulatie; toch klaar in ~72 s.
- Guest heeft geen libicu → pwsh in invariant-globalization mode (runtimeconfig).
