# Voorstel: remote PowerShell-debugger voor een vloot servers

**Student:** Abdellah El Morabit, 3de bachelor Toegepaste Informatica\
**Vak:** System Automation & Scripting\
**Repository (momenteel enkel de proof of concept):** https://github.com/nasrlol/tracepoint

## Probleem

Een PowerShell-script dat op een server draait, is van buitenaf niet te debuggen. `Enter-PSHostProcess` en de debugger van VS Code zijn interactief: één proces, één sessie, iemand die meekijkt. Een script dat via cron of systemd draait, heeft niemand die meekijkt; crasht het, dan verdwijnen variabelen, callstack en `$Error` met het proces. Het enige spoor is wat het script zelf logde.

Dit project lost dat op met een **remote debugger**: via SSH vindt hij draaiende `pwsh`-processen op meerdere servers tegelijk, hangt er zonder interactie een debugger aan en legt bij een fout regel, variabelen, callstack en `$Error` vast. De technische kern is attachen aan een proces dat al draait op een andere machine, de toestand vastleggen zonder het script te stoppen, en dat volhouden als de verbinding wegvalt. Serverlijst, servercontrole en centrale rapporten maken er een infrastructuurtool van.

**Schaal:** als ontwerpkeuze 20 servers met elk 5 scripts (100 scripts).

## Ontwerp en alternatieven

Ansible, journald en monitoring (Prometheus, Zabbix) zien dát een script faalt, niet waarom: geen variabelen, geen callstack.

| Keuze | Weerhouden | Afgewogen alternatieven |
|---|---|---|
| Verbinding | **SSH-remoting:** in PowerShell 7, niets te installeren (Microsoft, 2025) | WinRM (niet op Linux); eigen agent (installatie en beveiliging per server) → extra, via SSH |
| Debugmanier | **Debugger-API rechtstreeks** (uitgetest; Microsoft, 2023a, 2023b) | `Set-PSBreakpoint -Runspace` (uitgetest, geweigerd; Microsoft, 2026); Debug Adapter Protocol via PowerShell Editor Services (moet op elke server; Microsoft, z.d.-a; PowerShell, z.d.) → terugvaloptie voor M4 |
| Parallel | **`Invoke-Command`** over sessies en **`ForEach-Object -Parallel`** over scripts: ingebouwd | `Start-ThreadJob`; eigen `RunspacePool` (meer code) |
| Serverlijst | **YAML als Ansible-inventaris** (YAML Language Development Team, 2021): bestaande inventarissen werken | `.psd1`, JSON (geen commentaar), eigen formaat, `~/.ssh/config` |

**Proof of concept.** Attachen aan een draaiend script op een andere machine werkt: via SSH-remoting naar een VM, via een named pipe (`NamedPipeConnectionInfo`, zoals `Enter-PSHostProcess`; Microsoft, 2022) het `pwsh`-proces in, en tracepoints rechtstreeks op de debugger van die runspace. Waarden en callstack komen terug; het script loopt door. `Set-PSBreakpoint -Runspace` weigerde daar. Nog niet aangetoond: een crashrapport via attach, en writer en lease die een wegvallende verbinding overleven.

**Platform en vereisten:** Linux voor servers en beheermachine (Windows-servers: extra). PowerShell 7.4 (LTS) of hoger, getest met 7.6.5; OpenSSH met het `powershell`-subsystem; `powershell-yaml` op de beheermachine (Samfira & Pilotti, 2025). Attachen vraagt dezelfde gebruiker als het script, of root.

## MVP

- **Servers:** YAML in de structuur van een Ansible-inventaris (Ansible, z.d.): per server gebruiker, sleutel en `trace_debug` (mag er ingegrepen worden). Verplichte velden, types en unieke namen worden gecontroleerd; `Test-TraceServer` controleert per server PowerShell-versie, `powershell`-subsystem en rechten om te attachen.
- **Discovery:** draaiende `pwsh`-processen met PID, gebruiker en scriptpad; de parser (Microsoft, z.d.-b) haalt uit elk script waar het logt. Kortlopende scripts, zoals cronjobs, worden alleen gevolgd als ze via de wrapper starten.
- **Parallel:** over servers (servercontrole, discovery en records ophalen; resultaten verschijnen zodra ze binnenkomen), over scripts op één server (een runspace per script) en bij het parsen. Instelbare limiet, standaard 32 servers; een trage of falende server houdt de rest niet op.
- **Crashrapport:** JSON op de beheermachine, één bestand per crash in een map per server; tracepoints als JSON Lines. `SecureString` en `PSCredential` komen er nooit in.
- **Wegvallende verbinding,** naar write-ahead logging in PostgreSQL (PostgreSQL Global Development Group, z.d.-a, z.d.-c): elk record wordt eerst op de server gelogd, met een oplopende offset, en pas dan doorgestuurd. Na een onderbreking verbindt de beheermachine opnieuw (wachttijd verdubbelt per poging, tot een instelbaar maximum) en leest verder vanaf de laatst bevestigde offset: wat gelogd is, gaat niet verloren en komt niet dubbel. Crashrapporten worden meteen geschreven; tracepoints via een writer op de achtergrond, zoals bij asynchronous commit (PostgreSQL Global Development Group, z.d.-b), met hetzelfde risico dat ongeschreven records verloren gaan als het doelproces crasht. Een **lease** verwijdert tracepoints die een instelbare tijd niets van de debugger horen. Het log heeft een instelbare maximale grootte (vol: zie W5).
- **Cmdlets** met voorvoegsel `Trace`, help en objecten in een pipeline: `Import-TraceServer fleet.yml | Find-TraceScript | Connect-TraceScript`.
- **Pester en CI:** elk onderdeel heeft Pester-tests die bij elke push draaien (zie Testen).

| Niveau | Hoe | Grijpt in? |
|---|---|---|
| 0: logs | Parser vindt waar het script logt (`Start-Transcript`, `Out-File`); ophalen via SSH | Nee |
| 1: wrapper | Script start via een wrapper met `$ErrorActionPreference = 'Break'`: crashrapport | Bij een fout |
| 2: tracepoints | Breakpoint met een actie zonder `break`: verloop van een variabele, script loopt door | Ja, zonder te stoppen |
| 3: attach | Aanhaken aan een al draaiend proces, daar niveau 1 en 2 | Ja |

Niveau 1 tot 3 alleen op servers met `trace_debug: true`.

**Mijlpalen.** De volgorde van bouwen; elke mijlpaal levert iets werkends op, alle vier samen vormen het MVP.

| Mijlpaal | Inhoud | Af als |
|---|---|---|
| **M1:** de vloot zien | Serverlijst, `Test-TraceServer`, discovery, parallel | `Find-TraceScript` toont op 5 servers tegelijk alle `pwsh`-scripts met PID, gebruiker en pad; een ongeldige of onbereikbare server geeft een fout met zijn naam en houdt de rest niet op |
| **M2:** logs | Niveau 0 | `Get-TraceLog` haalt het log op van een script dat `Start-Transcript` gebruikt |
| **M3:** crashrapport | Niveau 1, write-ahead log, opnieuw verbinden | Een script dat via de wrapper crasht, geeft een rapport met regel, variabelen, callstack en `$Error`, zonder `PSCredential`; verbinding verbreken en herstellen verliest geen records en dubbelt er geen |
| **M4:** live meekijken | Niveau 2 en 3, lease | Een tracepoint op een al draaiend script toont het verloop van een variabele, met gemeten vertraging; na een wegvallende verbinding is de tracepoint binnen de lease-duur weg |

Het MVP is af als alle vier mijlpalen werken op de 5 testservers; de demo toont dat, de Pester-tests bewaken het. Lukt een crashrapport via attach niet, dan wordt alleen dat deel een extra.

**Demo:** de 5 testservers, één bewust onbereikbaar. Op de ene volgt een tracepoint `$teller` zonder het script te stoppen; op de andere crasht een script op regel 12 en toont het rapport regel 12, `$teller = 5` en de fout. De onbereikbare server geeft een fout, maar stopt de run niet.

**Performance** (geïnspireerd door de RAD Debugger; Fleury, z.d.): één SSH-sessie per server; toestand vastleggen bij een fout, niet continu; tracepoints schrijven alleen naar het geheugen, de vertraging wordt gemeten; variabelen gaan maar tot een instelbare diepte over het netwerk.

## Testen

Spec-driven: eerst de spec ("gegeven X, verwacht Y"), dan de code; elke spec wordt een Pester-test. Een eigen CI-runner draait de tests bij elke push, op Linux. Voorbeeld van een spec: script met `$teller = 5` faalt op regel 12 → rapport met regel 12, `$teller = 5` en de fout, zonder `PSCredential`.

| Binnen het MVP | Wat het aantoont | Hoe |
|---|---|---|
| Unittests | Elk onderdeel volgt zijn spec: serverlijst, discovery, logpaden, crashrapport, maskeren, toestemming (`trace_debug`, `-WhatIf`), write-ahead log, lease | Pester met `Mock` (Pester, z.d.) voor remoting, processen en tijd |
| Veerkrachttests | Een onbereikbare server, een wegvallende verbinding (geen records verloren, geen tracepoints achtergebleven), een trage server die de rest niet ophoudt | QEMU-VM's, verbindingen bewust verbreken |
| Performancetests | De vertraging door een tracepoint (met en zonder), en dat de totale tijd over 5 servers kleiner is dan de som per server | `Measure-Command` |

**Later**, bij de bijhorende extra's: fuzzing en metamorfe tests van de AST-analyse, mutatietesten, schaaltests (20 servers, 100 scripts) en tests op Windows-servers.

## SWOT

**Sterktes (intern)**

- **S1. Legt vast *waarom* een script faalde, niet alleen *dat*.** Monitoring ziet een exitcode; Trace geeft regel, variabelen, callstack en `$Error`.
- **S2. Attacht aan een draaiend script op een andere machine, zonder daar iets te installeren.** Aangetoond in de proof of concept.
- **S3. Parallel over de hele vloot.** Eén sessie per server, tot aan de limiet alle servers tegelijk: de totale tijd is kleiner dan de som per server.
- **S4. Licht voor productie.** Tracepoints stoppen het script nooit en schrijven alleen naar het geheugen; de vertraging wordt gemeten.

**Zwaktes (intern)**

- **W1. Ziet alleen draaiende scripts.** Een cronjob van twee seconden valt tussen twee scans. → Kortlopende scripts starten via de wrapper (niveau 1).
- **W2. Attachen vraagt dezelfde gebruiker als het script, of root,** want de pipe naar het proces is een socket van die gebruiker. → Bestaande SSH-gebruikers; `Test-TraceServer` meldt vooraf waar rechten ontbreken.
- **W3. Een weggevallen SSH-sessie is weg:** over SSH kun je niet loskoppelen en later hervatten. → Write-ahead log op de server, opnieuw verbinden vanaf de laatste offset.
- **W4. Tracepoints kunnen achterblijven** na een wegvallende verbinding en het script blijven vertragen. → Lease: zonder teken van de debugger verwijderen ze zichzelf.
- **W5. Wat er gebeurt als het write-ahead log vol is, ligt nog niet vast.** Blijft de beheermachine lang weg, dan bereikt het log zijn maximum. → Nog uit te werken; een mogelijke richting: oudste tracepoint-records laten vallen en het gat melden, crashrapporten nooit weggooien.

**Kansen (extern)**

- **O1. PowerShell 7 groeit op Linux, ook in de cloud, maar de debugtooling blijft achter.** Trace richt zich op die leemte.
- **O2. Ansible is wijdverspreid.** De serverlijst *is* een Ansible-inventaris: bestaande vloten zijn meteen bruikbaar.
- **O3. OpenSSH zit standaard in Linux en Windows Server.** De verbinding ligt er al; op de servers hoeft niets geïnstalleerd te worden.
- **O4. CI/CD wordt de norm voor scripts.** Scripts die in een pipeline falen, onderzoek je met dezelfde crashrapporten en tracepoints.

**Bedreigingen (extern)**

- **T1. Ingrijpen op productie** kan schade doen. → Alleen op servers met `trace_debug: true`, en de gebruiker bevestigt.
- **T2. Strenge SSH-instellingen:** geen `powershell`-subsystem of een afgeschermde `/tmp` laat attachen mislukken. → `Test-TraceServer` detecteert dit vooraf en zegt per server wat ontbreekt.
- **T3. Belasting van productieservers:** wachtrijen en het log nemen geheugen en schijf in op servers die al druk zijn. → Instelbare maximale grootte, de lease, en bevestigde records worden meteen opgeruimd.
- **T4. Privacy (AVG/GDPR):** variabelen in een crashrapport kunnen persoonsgegevens bevatten, en maskeren op type vangt alleen `SecureString` en `PSCredential`. → Rapporten blijven op de beheermachine, met beperkte bestandsrechten en een instelbare bewaartermijn.

## Rubriek

- **Analyse:** concreet schaaldoel (20 servers, 100 scripts); elke zwakte en bedreiging in de SWOT heeft een antwoord in het MVP.
- **Design:** drie keuzes met afgewogen alternatieven; de riskantste uitgetest in een proof of concept die een alternatief verwierp en een werkende weg vond. Origineel: attachen aan een draaiend script op afstand, zonder iets te installeren.
- **Kennisverwerving:** PowerShell is nieuw voor mij (runspaces, debugger-API, SSH-remoting, named pipes, het PowerShell-AST, Pester). Ik breng C/C++, Go, Linux, SSH, parsers, debuggers en QEMU mee, en bouwde eerder agents die via SSH uitgerold worden (paradigm-ehb, 2026a, 2026b).
- **Usability:** voor wie de vloot opvolgt en wie een script debugt: help met voorbeelden per cmdlet, een `about_Trace`-helptopic, een voorbeeldserverlijst, een leesbaar crashrapport; een bestaande Ansible-inventaris werkt meteen.
- **Robust:** twee sloten per ingreep (`trace_debug` en `-Confirm`/`-WhatIf`); een wegvallende verbinding verliest geen gelogde records en laat geen tracepoints achter; een onbereikbare server stopt de run niet; serverlijst gevalideerd, geheimen gemaskeerd.
- **Uitbreidbaarheid:** cmdlets in een pipeline; een discoverybron of uitvoerformaat is één functie; de agent kan SSH vervangen zonder de cmdlets te veranderen.
- **Best practices:** goedgekeurde werkwoorden met één voorvoegsel, modulestructuur, PSScriptAnalyzer op de eigen code, gemeten performancekeuzes.
- **Testing:** duidelijke scope: unit-, veerkracht- en performancetests in het MVP (spec-driven Pester, `Mock`, CI); fuzzing, mutatie-, schaal- en platformtests als uitbreiding.

## Extra

- **Agent via SSH:** een `pwsh`-agent per server, zonder eigen poort, die crashes bewaart en meldt ook als de beheermachine niet verbonden is. Voortbouwend op mijn eerdere agents.
- **GUI:** een dunne laag bovenop de cmdlets (Pode.Web, Avalonia of Terminal.Gui, na een korte proof of concept), geïnspireerd door de RAD Debugger.
- **Monitoring op schaal:** honderden scripts, events in plaats van polling, parse-cache op hash.
- **Discovery** via bestanden, cron en systemd; **kwaliteit** van scripts (PSScriptAnalyzer, drift).
- **Meer formaten:** volledige Ansible-inventarissen (INI, `group_vars`), binaire rapporten.
- **Naar de bron springen:** de callstack als `bestand:regel:kolom: melding`, zodat Vim, Emacs en VS Code elke regel klikbaar maken, met een kopie van het script bij de crash zodat de regel blijft kloppen.
- **Windows-servers:** via OpenSSH en het `powershell`-subsystem (Microsoft, 2025); verschillen in rechten, paden en het opvragen van de opdrachtregel. Testmachines staan klaar: twee Windows-machines en een Windows Server.
- **Uitgebreidere tests:** een eigen mutatietester (een mutatiescore zegt meer dan coverage; Wang et al., 2026; naar het voorbeeld van Stryker Mutator, z.d.), fuzzing en metamorfe tests van de AST-analyse, schaaltests, tests op Windows-servers.

## Bronnen

Geraadpleegd op 28 en 29 oktober 2026, behalve Ansible (z.d.), Microsoft (z.d.-a), paradigm-ehb (2026a, 2026b), PostgreSQL Global Development Group (z.d.-a, z.d.-b, z.d.-c), PowerShell (z.d.), Samfira en Pilotti (2025) en YAML Language Development Team (2021), die op 17 november 2026 geraadpleegd werden.

- Ansible. (z.d.). *How to build your inventory*. Ansible Documentation. https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html
- Anthropic. (2026). *Claude* [AI-model]. https://claude.ai (gebruikt voor brainstorm, feedback op dit voorstel en een eerste proof of concept)
- Fleury, R. (z.d.). *RAD Debugger* [Broncode]. GitHub. https://github.com/EpicGames/raddebugger (inspiratie)
- Microsoft. (z.d.-a). *Debug Adapter Protocol*. https://microsoft.github.io/debug-adapter-protocol/overview
- Microsoft. (z.d.-b). *Parser.ParseFile method*. Microsoft Learn. https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.parser.parsefile
- Microsoft. (2022). *Enter-PSHostProcess*. Microsoft Learn. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/enter-pshostprocess
- Microsoft. (2023a). *about_Debuggers*. Microsoft Learn. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_debuggers
- Microsoft. (2023b). *Debug-Runspace*. Microsoft Learn. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/debug-runspace
- Microsoft. (2025). *PowerShell remoting over SSH*. Microsoft Learn. https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/ssh-remoting-in-powershell
- Microsoft. (2026). *Set-PSBreakpoint*. Microsoft Learn. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/set-psbreakpoint
- paradigm-ehb. (2026a). *agent* [Broncode]. GitHub. https://github.com/paradigm-ehb/agent (eigen eerder werk; Go, gRPC)
- paradigm-ehb. (2026b). *agent-c* [Broncode]. GitHub. https://github.com/paradigm-ehb/agent-c (eigen eerder werk; opvolger in C/C++)
- Pester. (z.d.). *Mocking with Pester*. https://pester.dev/docs/usage/mocking
- PostgreSQL Global Development Group. (z.d.-a). *28.3. Write-Ahead Logging (WAL)*. PostgreSQL 18 Documentation. https://www.postgresql.org/docs/current/wal-intro.html
- PostgreSQL Global Development Group. (z.d.-b). *28.4. Asynchronous Commit*. PostgreSQL 18 Documentation. https://www.postgresql.org/docs/current/wal-async-commit.html
- PostgreSQL Global Development Group. (z.d.-c). *28.6. WAL Internals*. PostgreSQL 18 Documentation. https://www.postgresql.org/docs/current/wal-internals.html
- PowerShell. (z.d.). *PowerShell Editor Services* [Broncode]. GitHub. https://github.com/PowerShell/PowerShellEditorServices
- Samfira, G. A., & Pilotti, A. (2025). *powershell-yaml* (Versie 0.4.12) [PowerShell-module]. PowerShell Gallery. https://www.powershellgallery.com/packages/powershell-yaml
- Stryker Mutator. (z.d.). *Documentation*. https://stryker-mutator.io/docs/
- Wang, G., Xu, Q., Briand, L., & Liu, K. (2026). *Mutation-guided unit test generation with a large language model* (arXiv:2506.02954v8) [Preprint]. arXiv. https://arxiv.org/html/2506.02954v8
- YAML Language Development Team. (2021). *YAML Ain't Markup Language (YAML™) version 1.2, revision 1.2.2*. https://yaml.org/spec/1.2.2/

## Wijzigingen tegenover de vorige versie

- SWOT uitgebreid en inhoudelijk uitgewerkt: vier tot vijf punten per kwadrant, elk met uitleg, en bij elke zwakte en bedreiging wat het project eraan doet.
- Wegvallende verbindingen opgenomen in het MVP: een write-ahead log op de server naar het voorbeeld van PostgreSQL, opnieuw verbinden vanaf de laatst bevestigde offset, en een lease die achtergebleven tracepoints opruimt.
- Robust en Analyse in de rubriek aangepast aan het nieuwe ontwerp voor wegvallende verbindingen.
- Parallel opnieuw opgenomen in het MVP: over servers, over scripts op één server, bij het ophalen van records en bij het parsen, met een instelbare limiet; als keuze in de ontwerptabel en met een test.
- Teststrategie: tests ingedeeld in categorieën, met een duidelijke scheiding tussen wat binnen het MVP valt (unit-, veerkracht- en performancetests) en wat naar uitbreidingen gaat (fuzzing, mutatie-, schaal- en platformtests).
- MVP concreter gemaakt: vier mijlpalen die elk iets werkends opleveren en samen het MVP vormen, met per mijlpaal een toetsbaar criterium voor wanneer ze af is.
- Platformen expliciet gemaakt: Linux voor servers en beheermachine; Windows-servers als uitbreiding, met testmachines beschikbaar.
- Uitbreiding toegevoegd: de callstack van een crashrapport in het formaat `bestand:regel:kolom: melding`, zodat editors rechtstreeks naar de regel springen, met een kopie van het script bij de crash.
- Zwakte toegevoegd: wat er gebeurt als het write-ahead log vol is, ligt nog niet vast.
- Bedreigingen toegevoegd: belasting van productieservers door wachtrijen en het write-ahead log (maximale grootte, lease, opruimen), en privacy van gegevens in crashrapporten (rapporten lokaal, beperkte rechten, instelbare bewaartermijn).
- Minimale PowerShell-versie 7.4 (LTS), getest met 7.6.5; 7.2 wordt niet meer ondersteund en de functie die 7.2 vereiste, wordt niet gebruikt.
- "Af" voor het MVP gedefinieerd als werkende functionaliteit op de testservers, niet als slagende tests.
- Voorstel eenduidiger gemaakt: geen benaderende getallen meer, waarden die nog niet gemeten zijn (lease-duur, maximale loggrootte, wachttijd bij opnieuw verbinden, serialisatiediepte) zijn instelbaar, de garanties van het write-ahead log zijn precies omschreven, en demo en tests gebruiken dezelfde 5 testservers.
- Voorstel ingekort zonder inhoud te verliezen; het probleem is technisch geformuleerd: een draaiend PowerShell-script is van buitenaf niet te debuggen.
- Bronnen toegevoegd: de documentatie van PostgreSQL over write-ahead logging. De verouderde bron over servers per beheerder (2011) is verwijderd; het schaaldoel van 20 servers is nu een ontwerpkeuze.
