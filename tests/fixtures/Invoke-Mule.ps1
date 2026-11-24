#!/usr/bin/env pwsh
# Mule: doelwit om aan te attachen: loopt eindeloos, voorspelbaar, met een functie (callstack),
# verschillende soorten variabelen en vaste regelnummers voor breakpoints. Stoppen: Ctrl-C.
#
#   regel 28  $teller++                 elke ronde, in het script
#   regel 20  $even = ...               in de functie Get-Status (callstack: Get-Status <- script)
#   variabele $teller (int), $status (object), $history (lijst), $config (hashtable)
#
# De unittest bewaakt deze regelnummers: pas ze hier mee aan als je regels toevoegt.
param(
  [int]$Iterations = 0,          # 0 = blijven lopen
  [double]$IntervalSeconds = 1
)
$Sandbox = if ($env:TRACE_SANDBOX) { $env:TRACE_SANDBOX } else { Join-Path $PSScriptRoot '../sandbox' }
$heartbeat = Join-Path $Sandbox 'heartbeat.txt'
$null = New-Item -ItemType Directory -Force $Sandbox
$config = @{ Naam = 'mule'; Interval = $IntervalSeconds; Pid = $PID }
$history = [System.Collections.Generic.List[int]]::new()
function Get-Status([int]$Ronde) {
  $even = $Ronde % 2 -eq 0
  [pscustomobject]@{ Ronde = $Ronde; Even = $even; Tijd = (Get-Date).ToString('HH:mm:ss') }
}

"PID ${PID}: attach met  Enter-PSHostProcess -Id $PID"
$teller = 0
while ($Iterations -eq 0 -or $teller -lt $Iterations) {
  $status = $null
  $teller++
  $status = Get-Status -Ronde $teller
  $history.Add($teller)
  if ($history.Count -gt 10) { $history.RemoveAt(0) }
  "$($status.Tijd) ronde $($status.Ronde) even=$($status.Even)"
  "$($status.Tijd) $teller" | Set-Content $heartbeat
  Start-Sleep -Seconds $IntervalSeconds
}
