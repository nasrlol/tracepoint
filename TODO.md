# TODO

## Verbinding valt weg terwijl de debugger aan een script hangt

Wat gebeurt er als de debugger crasht of de SSH-verbinding wegvalt tijdens niveau 2 of 3?

- Tracepoints met acties zonder `break` stoppen het script nooit: het kan niet blijven hangen.
- Maar de breakpoints blijven in het script staan en blijven records in een wachtrij
  (`AppDomain`-data) zetten die niemand meer leegmaakt: geheugen groeit, het script blijft vertragen.
- Echt stoppen en hervatten zou een script laten hangen tot iemand het verderzet.

Opties:
- (a) Alleen tracepoints die nooit stoppen; bij opnieuw verbinden achtergebleven breakpoints opruimen.
- (b) Vangnet in de actie zelf: niets opgehaald na X seconden → breakpoint verwijdert zichzelf;
      wachtrij met een maximale grootte.
- (c) (a) en (b) samen.
- (d) Echt stoppen toelaten, met een time-out waarna het script zelf verdergaat.

Met een agent op de server (zie Extra agent) is dit eenvoudiger: die blijft draaien als de
verbinding wegvalt en kan breakpoints zelf opruimen.

## Meetbare performancedoelen vastleggen

Vastgelegd: een tracepoint vertraagt een script hooguit 10% (`Measure-Command`).
Nog te bepalen na metingen op de 5 testservers, voor het doel van 20 servers en ~100 scripts:
- `Test-TraceServer` op 20 servers: < ? s (parallel)
- `Find-TraceScript` op 20 servers: < ? s
- crash → rapport op de beheermachine: < ? s
- geheugen van een tracepoint-wachtrij per script: < ? MB

## CI op de eigen runner

Eigen runner (script dat bij een push getriggerd wordt). Nakijken:
- op welke machine hij draait en of die KVM heeft (dan kunnen de QEMU-test-VM's in CI);
- waar de macOS-tests draaien;
- unittests (Mock) op Linux en macOS, integratietests tegen QEMU-VM's.
