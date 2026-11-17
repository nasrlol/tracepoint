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

Geen getallen vastleggen zonder meting. Eerst een basislijn meten op de 5 testservers (`Measure-Command`),
daarna pas doelen bepalen, voor het doel van 20 servers en ~100 scripts:
- vertraging van een script door tracepoints (met en zonder): < ? %
- `Test-TraceServer` op 20 servers: < ? s (parallel)
- `Find-TraceScript` op 20 servers: < ? s
- crash → rapport op de beheermachine: < ? s
- geheugen van een tracepoint-wachtrij per script: < ? MB

## CI op de eigen runner

Eigen runner (script dat bij een push getriggerd wordt). Nakijken:
- op welke machine hij draait en of die KVM heeft (dan kunnen de QEMU-test-VM's in CI);
- unittests (Mock) en veerkrachttests op Linux (QEMU-VM's).

## Write-ahead log vol

Wat gebeurt er als het log op de server zijn maximale grootte bereikt (beheermachine lang niet verbonden)?
Mogelijke richting: oudste tracepoint-records laten vallen en het gat in het rapport melden;
crashrapporten nooit weggooien. Staat als zwakte W5 in het voorstel.
