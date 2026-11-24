#!/usr/bin/env pwsh
# Stopt de fixtures die Start-Fixtures.ps1 startte, en niets anders: een PID wordt alleen
# gestopt als de opdrachtregel van dat proces nog naar dezelfde fixture wijst.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$Sandbox = if ($env:TRACE_SANDBOX) { $env:TRACE_SANDBOX } else { Join-Path $PSScriptRoot 'sandbox' }
$pidFile = Join-Path $Sandbox 'pids.json'

if (-not (Test-Path $pidFile)) {
  "geen ${pidFile}: er draait niets"
  return
}

foreach ($entry in Get-Content $pidFile -Raw | ConvertFrom-Json) {
  $p = Get-Process -Id $entry.Id -ErrorAction Ignore
  if ($p -and $p.CommandLine -like "*$($entry.Path)*") {
    Stop-Process -Id $entry.Id
    "gestopt: $($entry.Name) ($($entry.Id))"
  } else {
    "al weg: $($entry.Name) ($($entry.Id))"
  }
}
Remove-Item $pidFile
