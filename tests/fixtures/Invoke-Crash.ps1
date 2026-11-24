# Gezondheidscontrole die in de 5de ronde crasht: doelwit voor het crashrapport (M3).
# De demo en de tests rekenen op regel 12 en $teller = 5: verander die regels niet.
param([double]$IntervalSeconds = 1)
$ErrorActionPreference = 'Stop'
$Sandbox = if ($env:TRACE_SANDBOX) { $env:TRACE_SANDBOX } else { Join-Path $PSScriptRoot '../sandbox' }
$statusFile = Join-Path $Sandbox 'health/status.json'
$null = New-Item -ItemType Directory -Force (Split-Path $statusFile)
$teller = 0
while ($true) {
  $teller++
  if ($teller -eq 5) { Remove-Item $statusFile -ErrorAction Ignore } else { @{ teller = $teller; tijd = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content $statusFile }
  $status = Get-Content $statusFile -Raw | ConvertFrom-Json
  "ronde $($status.teller): gezond"
  Start-Sleep -Seconds $IntervalSeconds
}
